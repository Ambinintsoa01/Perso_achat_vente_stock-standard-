import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/stats_data.dart';

class StatsService {
  final DbHelper _dbHelper = DbHelper.instance;
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  // 1. Synthèse globale des KPIs : Valeur de stock, Entrées, Sorties, Dépenses et Flux
  Future<StatsKpiSummary> getKpiSummary({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final db = await _dbHelper.database;

    // A. Valeur actuelle du stock (au CUMP / prix d'achat)
    final resStock = await db.rawQuery('''
      SELECT 
        COUNT(DISTINCT a.id) as total_articles,
        COALESCE(SUM(sd.quantite_reelle), 0.0) as total_quantite,
        COALESCE(SUM(sd.quantite_reelle * (CASE WHEN a.cout_moyen_unitaire > 0 THEN a.cout_moyen_unitaire ELSE a.prix_achat_estime END)), 0.0) as valeur_stock
      FROM stock_depot sd
      JOIN article a ON sd.id_article = a.id
      WHERE a.actif = 1
    ''');

    final totalArticles = (resStock.first['total_articles'] as num?)?.toInt() ?? 0;
    final totalQteStock = (resStock.first['total_quantite'] as num?)?.toDouble() ?? 0.0;
    final valeurStock = (resStock.first['valeur_stock'] as num?)?.toDouble() ?? 0.0;

    // Clauses de date pour les mouvements temporels
    String stockDateWhere = '';
    String caisseDateWhere = '';
    String venteDateWhere = '';
    List<dynamic> dateArgs = [];

    if (dateDebut != null) {
      final s = _dateFormatter.format(dateDebut);
      stockDateWhere += ' AND DATE(ms.date_mouvement) >= ?';
      caisseDateWhere += ' AND DATE(mc.date_mouvement) >= ?';
      venteDateWhere += ' AND DATE(cv.date_commande) >= ?';
      dateArgs.add(s);
    }
    if (dateFin != null) {
      final e = _dateFormatter.format(dateFin);
      stockDateWhere += ' AND DATE(ms.date_mouvement) <= ?';
      caisseDateWhere += ' AND DATE(mc.date_mouvement) <= ?';
      venteDateWhere += ' AND DATE(cv.date_commande) <= ?';
      dateArgs.add(e);
    }

    // B. Valeur totale d'entrée et valeur totale de sortie (Stock)
    final resMvtStock = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN tms.sens = 1 THEN ms.quantite * (CASE WHEN ms.prix_unitaire > 0 THEN ms.prix_unitaire WHEN a.cout_moyen_unitaire > 0 THEN a.cout_moyen_unitaire ELSE a.prix_achat_estime END) ELSE 0 END), 0.0) as total_entrees,
        COALESCE(SUM(CASE WHEN tms.sens = -1 THEN ms.quantite * (CASE WHEN ms.prix_unitaire > 0 THEN ms.prix_unitaire WHEN a.prix_vente_standard > 0 THEN a.prix_vente_standard ELSE a.cout_moyen_unitaire END) ELSE 0 END), 0.0) as total_sorties
      FROM mouvement_stock ms
      JOIN type_mouvement_stock tms ON ms.id_type_mouvement = tms.id
      JOIN article a ON ms.id_article = a.id
      WHERE 1=1 $stockDateWhere
    ''', dateArgs);

    final valeurEntrees = (resMvtStock.first['total_entrees'] as num?)?.toDouble() ?? 0.0;
    final valeurSorties = (resMvtStock.first['total_sorties'] as num?)?.toDouble() ?? 0.0;

    // C. Dépenses et Trésorerie (Caisse)
    final resCaisse = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN tm.sens = 1 THEN mc.montant ELSE 0 END), 0.0) as total_encaissements,
        COALESCE(SUM(CASE WHEN tm.sens = -1 THEN mc.montant ELSE 0 END), 0.0) as total_decaissements,
        COALESCE(SUM(CASE WHEN tm.code = 'DECAISSEMENT_ACHAT' THEN mc.montant ELSE 0 END), 0.0) as total_achats,
        COALESCE(SUM(CASE WHEN tm.sens = -1 AND tm.code != 'DECAISSEMENT_ACHAT' AND tm.code != 'TRANSFERT_INTERNE_DEBIT' THEN mc.montant ELSE 0 END), 0.0) as total_depenses_diverses
      FROM mouvement_caisse mc
      JOIN type_mouvement_caisse tm ON mc.id_type_mouvement = tm.id
      WHERE 1=1 $caisseDateWhere
    ''', dateArgs);

    final totalEncaissements = (resCaisse.first['total_encaissements'] as num?)?.toDouble() ?? 0.0;
    final totalDecaissements = (resCaisse.first['total_decaissements'] as num?)?.toDouble() ?? 0.0;
    final totalAchats = (resCaisse.first['total_achats'] as num?)?.toDouble() ?? 0.0;
    final totalDepensesDiverses = (resCaisse.first['total_depenses_diverses'] as num?)?.toDouble() ?? 0.0;

    // D. Chiffre d'affaires Ventes sur la période
    final resVentes = await db.rawQuery('''
      SELECT COALESCE(SUM(montant_ttc), 0.0) as total_ventes
      FROM commande_vente cv
      WHERE 1=1 $venteDateWhere
    ''', dateArgs);

    final totalVentes = (resVentes.first['total_ventes'] as num?)?.toDouble() ?? 0.0;

    return StatsKpiSummary(
      valeurStockActuel: valeurStock,
      valeurTotaleEntrees: valeurEntrees,
      valeurTotaleSorties: valeurSorties,
      totalEncaissements: totalEncaissements,
      totalDecaissements: totalDecaissements,
      totalAchats: totalAchats,
      totalDepensesDiverses: totalDepensesDiverses,
      totalVentes: totalVentes,
      totalArticles: totalArticles,
      totalQuantiteEnStock: totalQteStock,
    );
  }

  // 2. Évolution des ventes (filtrable par date, catégorie et article)
  Future<List<VenteEvolutionPoint>> getEvolutionVentes({
    DateTime? dateDebut,
    DateTime? dateFin,
    int? idCategorie,
    int? idArticle,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = 'WHERE 1=1';
    List<dynamic> args = [];

    if (dateDebut != null) {
      whereClause += ' AND DATE(cv.date_commande) >= ?';
      args.add(_dateFormatter.format(dateDebut));
    }
    if (dateFin != null) {
      whereClause += ' AND DATE(cv.date_commande) <= ?';
      args.add(_dateFormatter.format(dateFin));
    }

    if (idCategorie != null && idCategorie > 0) {
      whereClause += ' AND a.id_categorie = ?';
      args.add(idCategorie);
    }

    if (idArticle != null && idArticle > 0) {
      whereClause += ' AND a.id = ?';
      args.add(idArticle);
    }

    final query = '''
      SELECT 
        DATE(cv.date_commande) as date_jour,
        COALESCE(SUM(cvl.montant_ttc), 0.0) as total_montant,
        COALESCE(SUM(cvl.quantite), 0.0) as total_quantite,
        COUNT(DISTINCT cv.id) as nb_commandes
      FROM commande_vente cv
      JOIN commande_vente_ligne cvl ON cv.id = cvl.id_commande_vente
      JOIN article a ON cvl.id_article = a.id
      $whereClause
      GROUP BY DATE(cv.date_commande)
      ORDER BY DATE(cv.date_commande) ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps.map((m) => VenteEvolutionPoint.fromMap(m)).toList();
  }

  // 3. Évolution des dépenses (Achat fournisseur + Décaissements divers)
  Future<List<DepenseEvolutionPoint>> getEvolutionDepenses({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = "WHERE tm.sens = -1 AND tm.code != 'TRANSFERT_INTERNE_DEBIT'";
    List<dynamic> args = [];

    if (dateDebut != null) {
      whereClause += ' AND DATE(mc.date_mouvement) >= ?';
      args.add(_dateFormatter.format(dateDebut));
    }
    if (dateFin != null) {
      whereClause += ' AND DATE(mc.date_mouvement) <= ?';
      args.add(_dateFormatter.format(dateFin));
    }

    final query = '''
      SELECT 
        DATE(mc.date_mouvement) as date_jour,
        COALESCE(SUM(CASE WHEN tm.code = 'DECAISSEMENT_ACHAT' THEN mc.montant ELSE 0.0 END), 0.0) as montant_achats,
        COALESCE(SUM(CASE WHEN tm.code != 'DECAISSEMENT_ACHAT' THEN mc.montant ELSE 0.0 END), 0.0) as montant_depenses_diverses
      FROM mouvement_caisse mc
      JOIN type_mouvement_caisse tm ON mc.id_type_mouvement = tm.id
      $whereClause
      GROUP BY DATE(mc.date_mouvement)
      ORDER BY DATE(mc.date_mouvement) ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps.map((m) {
      return DepenseEvolutionPoint(
        date: m['date_jour'] as String? ?? '',
        montantAchats: (m['montant_achats'] as num?)?.toDouble() ?? 0.0,
        montantDepensesDiverses: (m['montant_depenses_diverses'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  // 4. Répartition des dépenses (Achats vs Dépenses diverses)
  Future<List<DepenseRepartitionItem>> getRepartitionDepenses({
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = "WHERE tm.sens = -1 AND tm.code != 'TRANSFERT_INTERNE_DEBIT'";
    List<dynamic> args = [];

    if (dateDebut != null) {
      whereClause += ' AND DATE(mc.date_mouvement) >= ?';
      args.add(_dateFormatter.format(dateDebut));
    }
    if (dateFin != null) {
      whereClause += ' AND DATE(mc.date_mouvement) <= ?';
      args.add(_dateFormatter.format(dateFin));
    }

    final query = '''
      SELECT 
        CASE 
          WHEN tm.code = 'DECAISSEMENT_ACHAT' THEN 'DECAISSEMENT_ACHAT'
          ELSE 'DEPENSE_DIVERSE'
        END as group_code,
        CASE 
          WHEN tm.code = 'DECAISSEMENT_ACHAT' THEN 'Achats Fournisseurs'
          ELSE 'Dépenses Diverses & Charges'
        END as group_libelle,
        COALESCE(SUM(mc.montant), 0.0) as total_montant
      FROM mouvement_caisse mc
      JOIN type_mouvement_caisse tm ON mc.id_type_mouvement = tm.id
      $whereClause
      GROUP BY group_code
      ORDER BY total_montant DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    final totalGlobal = maps.fold<double>(
      0.0,
      (sum, m) => sum + ((m['total_montant'] as num?)?.toDouble() ?? 0.0),
    );

    return maps.map((m) {
      final montant = (m['total_montant'] as num?)?.toDouble() ?? 0.0;
      final pct = totalGlobal > 0 ? (montant / totalGlobal) * 100 : 0.0;
      return DepenseRepartitionItem(
        typeCode: m['group_code'] as String,
        libelle: m['group_libelle'] as String,
        montant: montant,
        pourcentage: pct,
      );
    }).toList();
  }

  // 4. Tableau de bord du patron (access_controle.md : Résumé en 4 cartes)
  Future<DashboardPatronSummary> getDashboardPatron() async {
    final db = await _dbHelper.database;

    // A. Caisse du jour (Total encaissé, Espèces, Mobile Money)
    final resCaisse = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN tmc.sens = 1 THEN mc.montant ELSE 0 END), 0.0) as caisse_total,
        COALESCE(SUM(CASE WHEN tmc.sens = 1 AND (c.code LIKE '%CSH%' OR c.id_type_caisse = 1) THEN mc.montant ELSE 0 END), 0.0) as caisse_cash,
        COALESCE(SUM(CASE WHEN tmc.sens = 1 AND c.id_type_caisse = 3 THEN mc.montant ELSE 0 END), 0.0) as caisse_mobile
      FROM mouvement_caisse mc
      JOIN type_mouvement_caisse tmc ON mc.id_type_mouvement = tmc.id
      JOIN caisse c ON mc.id_caisse = c.id
      WHERE DATE(mc.date_mouvement) = DATE('now', 'localtime')
    ''');
    final caisseTotal = (resCaisse.first['caisse_total'] as num?)?.toDouble() ?? 0.0;
    final caisseCash = (resCaisse.first['caisse_cash'] as num?)?.toDouble() ?? 0.0;
    final caisseMobile = (resCaisse.first['caisse_mobile'] as num?)?.toDouble() ?? 0.0;

    // B. Bénéfice du jour (Marge brute du jour)
    final resMarge = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(montant_ttc), 0.0) as total_ventes,
        COALESCE(SUM(marge_brute), 0.0) as total_marge
      FROM commande_vente
      WHERE DATE(date_commande) = DATE('now', 'localtime')
    ''');
    final ventesJour = (resMarge.first['total_ventes'] as num?)?.toDouble() ?? 0.0;
    final beneficeJour = (resMarge.first['total_marge'] as num?)?.toDouble() ?? 0.0;

    // C. Dettes clients à récupérer (Carnet de dettes actives via factures impayées)
    final resDettes = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(montant_ttc - montant_paye), 0.0) as total_dettes,
        COUNT(DISTINCT id_client) as nb_clients
      FROM facture_client
      WHERE montant_ttc > montant_paye
    ''');
    final totalDettes = (resDettes.first['total_dettes'] as num?)?.toDouble() ?? 0.0;
    final nbClients = (resDettes.first['nb_clients'] as num?)?.toInt() ?? 0;

    // D. Alertes Stock (Références critiques proches de 0 ou seuil alerte)
    final resStock = await db.rawQuery('''
      SELECT COUNT(DISTINCT a.id) as nb_alertes
      FROM article a
      LEFT JOIN stock_depot sd ON a.id = sd.id_article
      WHERE a.actif = 1
      GROUP BY a.id, a.seuil_alerte_stock
      HAVING COALESCE(SUM(sd.quantite_reelle), 0) <= COALESCE(a.seuil_alerte_stock, 5.0)
    ''');
    final nbAlertes = resStock.length;

    return DashboardPatronSummary(
      caisseJourTotal: caisseTotal,
      caisseJourEspeces: caisseCash,
      caisseJourMobile: caisseMobile,
      beneficeJourMarge: beneficeJour,
      ventesJourTotal: ventesJour,
      dettesClientsTotal: totalDettes,
      nbClientsEnRetard: nbClients,
      alertesStockRupture: nbAlertes,
    );
  }
}
