import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/client.dart';
import '../models/commande_vente.dart';

class LigneVenteInput {
  final int idArticle;
  final String designation;
  final double quantite;
  final double prixUnitaire;
  final double tauxRemise;

  LigneVenteInput({
    required this.idArticle,
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
    this.tauxRemise = 0.0,
  });

  double get montantTotal => quantite * prixUnitaire * (1.0 - (tauxRemise / 100.0));
}

class VenteSummary {
  final double totalVentesMois;
  final int nombreVentes;
  final double totalCreancesClients;
  final double totalMargeBrute;

  VenteSummary({
    required this.totalVentesMois,
    required this.nombreVentes,
    required this.totalCreancesClients,
    required this.totalMargeBrute,
  });
}

class VenteService {
  final DbHelper _dbHelper = DbHelper.instance;

  // Liste des clients
  Future<List<Client>> getClients() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'client',
      where: 'actif = 1',
      orderBy: 'nom_complet ASC',
    );
    return maps.map((m) => Client.fromMap(m)).toList();
  }

  // Ajouter un nouveau client
  Future<int> ajouterClient({
    required String nomComplet,
    String? telephone,
    String? email,
    String? adresse,
    String? ville,
    int idTypeClient = 1,
    double soldeCreditMax = 0.0,
  }) async {
    final db = await _dbHelper.database;
    final code = 'CLI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    return await db.insert('client', {
      'code': code,
      'nom_complet': nomComplet.trim(),
      'id_type_client': idTypeClient,
      'telephone': telephone?.trim(),
      'email': email?.trim(),
      'adresse': adresse?.trim(),
      'ville': ville?.trim(),
      'solde_credit_max': soldeCreditMax,
      'actif': 1,
    });
  }

  // Liste des commandes de vente avec filtre obligatoire de date
  Future<List<CommandeVente>> getCommandesVente({
    bool? onlyUnpaid,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final db = await _dbHelper.database;
    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    String whereClause = '';
    List<dynamic> args = [];

    if (dateDebut != null) {
      whereClause += ' WHERE DATE(cv.date_commande) >= ?';
      args.add(formatter.format(dateDebut));
    }
    if (dateFin != null) {
      if (whereClause.isEmpty) {
        whereClause += ' WHERE DATE(cv.date_commande) <= ?';
      } else {
        whereClause += ' AND DATE(cv.date_commande) <= ?';
      }
      args.add(formatter.format(dateFin));
    }

    final query = '''
      SELECT 
        cv.*,
        c.nom_complet as client_nom,
        s.numero as statut_numero,
        s.code as statut_code,
        s.libelle as statut_libelle,
        COUNT(cvl.id) as lignes_count,
        COALESCE(fc.montant_paye, 0.0) as montant_paye,
        fc.id as id_facture,
        fc.numero_facture as numero_facture
      FROM commande_vente cv
      JOIN client c ON cv.id_client = c.id
      JOIN statut s ON cv.id_statut = s.id
      LEFT JOIN commande_vente_ligne cvl ON cv.id = cvl.id_commande_vente
      LEFT JOIN facture_client fc ON cv.id = fc.id_commande_vente
      $whereClause
      GROUP BY cv.id
      ORDER BY cv.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    final list = maps.map((m) => CommandeVente.fromMap(m)).toList();

    if (onlyUnpaid == true) {
      return list.where((c) => !c.estPaye).toList();
    }
    return list;
  }

  // Détails des lignes d'une commande de vente
  Future<List<CommandeVenteLigne>> getLignesCommande(int idCommandeVente) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        cvl.*,
        a.reference as article_reference,
        a.designation as article_designation,
        u.code as unite_code
      FROM commande_vente_ligne cvl
      JOIN article a ON cvl.id_article = a.id
      LEFT JOIN unite_mesure u ON a.id_unite = u.id
      WHERE cvl.id_commande_vente = ?
      ORDER BY cvl.id ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [idCommandeVente]);
    return maps.map((m) => CommandeVenteLigne.fromMap(m)).toList();
  }

  // Synthèse financière des ventes (KPIs)
  Future<VenteSummary> getVenteSummary() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final firstDayOfMonth = DateFormat('yyyy-MM-01').format(now);
    final lastDayOfMonth = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));

    // Ventes et marges du mois en cours
    final resMois = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(montant_ttc), 0.0) as total_ventes,
        COALESCE(SUM(marge_brute), 0.0) as total_marge,
        COUNT(id) as nb_ventes
      FROM commande_vente
      WHERE DATE(date_commande) >= ? AND DATE(date_commande) <= ?
    ''', [firstDayOfMonth, lastDayOfMonth]);

    final totalVentes = (resMois.first['total_ventes'] as num?)?.toDouble() ?? 0.0;
    final totalMarge = (resMois.first['total_marge'] as num?)?.toDouble() ?? 0.0;
    final nbVentes = (resMois.first['nb_ventes'] as num?)?.toInt() ?? 0;

    // Créances clients globales en cours (factures non soldées)
    final resCreances = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(montant_ttc - montant_paye), 0.0) as total_creances
      FROM facture_client
      WHERE montant_ttc > montant_paye
    ''');

    final totalCreances = (resCreances.first['total_creances'] as num?)?.toDouble() ?? 0.0;

    return VenteSummary(
      totalVentesMois: totalVentes,
      nombreVentes: nbVentes,
      totalCreancesClients: totalCreances,
      totalMargeBrute: totalMarge,
    );
  }

  // Enregistrer une vente complète (transaction atomique : vente, lignes, décrément stock, CUMP/marge, caisse si comptant)
  Future<int> enregistrerVente({
    required int idClient,
    required List<LigneVenteInput> articlesVendus,
    required bool payeImmediatement,
    int? idCaisse,
    int? idModePaiement,
    String? notes,
    int? idUtilisateur,
    int idDepot = 1,
  }) async {
    if (articlesVendus.isEmpty) {
      throw Exception('Veuillez ajouter au moins un article au panier de vente');
    }

    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. Vérification de disponibilité des stocks pour chaque article
      double margeBruteTotale = 0.0;
      double totalHt = 0.0;

      for (var item in articlesVendus) {
        final stockRows = await txn.query(
          'stock_depot',
          where: 'id_depot = ? AND id_article = ?',
          whereArgs: [idDepot, item.idArticle],
        );

        final stockActuel = stockRows.isNotEmpty
            ? (stockRows.first['quantite_reelle'] as num).toDouble()
            : 0.0;

        if (stockActuel < item.quantite) {
          throw Exception(
            'Stock insuffisant pour "${item.designation}". Disponible: ${stockActuel.toStringAsFixed(0)}, Requis: ${item.quantite.toStringAsFixed(0)}',
          );
        }

        // Lecture du CUMP actuel pour le calcul de la marge brute
        final articleRows = await txn.query('article', where: 'id = ?', whereArgs: [item.idArticle]);
        final cump = articleRows.isNotEmpty
            ? (articleRows.first['cout_moyen_unitaire'] as num?)?.toDouble() ?? 0.0
            : 0.0;

        final itemTotal = item.montantTotal;
        totalHt += itemTotal;
        margeBruteTotale += (itemTotal - (item.quantite * cump));
      }

      final totalTtc = totalHt;
      final numCommande = 'BCV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      // Statut 5: SOLDE (si payé immédiatement) ou 2: VALIDE (si paiement à crédit / différé)
      final statutId = payeImmediatement ? 5 : 2;

      // 2. Insertion de la commande de vente
      final idCommande = await txn.insert('commande_vente', {
        'numero_commande': numCommande,
        'id_client': idClient,
        'id_depot_source': idDepot,
        'id_statut': statutId,
        'id_utilisateur': idUtilisateur ?? 1,
        'date_commande': DateTime.now().toIso8601String().substring(0, 10),
        'montant_ht': totalHt,
        'montant_tva': 0.0,
        'montant_ttc': totalTtc,
        'marge_brute': margeBruteTotale,
        'notes': notes,
      });

      // 3. Traitement de chaque ligne :
      // -> Insertion commande_vente_ligne
      // -> Décrémentation STOCK (stock_depot)
      // -> Enregistrement MOUVEMENT STOCK (SORTIE_VENTE)
      for (var item in articlesVendus) {
        await txn.insert('commande_vente_ligne', {
          'id_commande_vente': idCommande,
          'id_article': item.idArticle,
          'quantite': item.quantite,
          'prix_unitaire': item.prixUnitaire,
          'taux_remise': item.tauxRemise,
          'montant_ht': item.montantTotal,
          'montant_ttc': item.montantTotal,
        });

        // Lecture stock avant
        final stockRows = await txn.query(
          'stock_depot',
          where: 'id_depot = ? AND id_article = ?',
          whereArgs: [idDepot, item.idArticle],
        );

        final stockAvant = (stockRows.first['quantite_reelle'] as num).toDouble();
        final stockApres = stockAvant - item.quantite;

        // Mise à jour stock
        await txn.update(
          'stock_depot',
          {'quantite_reelle': stockApres, 'derniere_mise_a_jour': DateTime.now().toIso8601String()},
          where: 'id_depot = ? AND id_article = ?',
          whereArgs: [idDepot, item.idArticle],
        );

        // Enregistrement MOUVEMENT STOCK (SORTIE_VENTE = id 2)
        await txn.insert('mouvement_stock', {
          'id_depot': idDepot,
          'id_article': item.idArticle,
          'id_type_mouvement': 2, // SORTIE_VENTE
          'id_utilisateur': idUtilisateur ?? 1,
          'quantite': item.quantite,
          'prix_unitaire': item.prixUnitaire,
          'stock_avant': stockAvant,
          'stock_apres': stockApres,
          'reference_document': numCommande,
          'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
          'remarque': 'Vente client $numCommande',
        });
      }

      // 4. Traitement financier :
      final numFacture = 'FC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      if (payeImmediatement) {
        if (idCaisse == null) {
          throw Exception('Veuillez sélectionner un compte ou tiroir-caisse pour l\'encaissement');
        }

        // Lecture du solde de la caisse
        final caisseRows = await txn.query('caisse', where: 'id = ?', whereArgs: [idCaisse]);
        if (caisseRows.isEmpty) throw Exception('Caisse introuvable');
        final soldeAvant = (caisseRows.first['solde_actuel'] as num).toDouble();
        final soldeApres = soldeAvant + totalTtc;

        // Mise à jour du solde de caisse (Crédit)
        await txn.update('caisse', {'solde_actuel': soldeApres}, where: 'id = ?', whereArgs: [idCaisse]);

        final openJc = await txn.query('journal_caisse', columns: ['id'], where: "statut = 'OUVERT'", limit: 1);
        final idJournal = openJc.isNotEmpty ? openJc.first['id'] as int : null;

        // Enregistrement MOUVEMENT DE CAISSE (ENCAISSEMENT_VENTE = id 1)
        await txn.insert('mouvement_caisse', {
          'id_caisse': idCaisse,
          'id_type_mouvement': 1, // ENCAISSEMENT_VENTE
          'id_mode_paiement': idModePaiement ?? 1,
          'id_utilisateur': idUtilisateur ?? 1,
          'id_journal_caisse': idJournal,
          'montant': totalTtc,
          'solde_avant': soldeAvant,
          'solde_apres': soldeApres,
          'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
          'reference_piece': numCommande,
          'description': 'Vente comptant $numCommande',
        });

        // Facture client acquittée (SOLDE = id 5)
        final idFacture = await txn.insert('facture_client', {
          'numero_facture': numFacture,
          'id_client': idClient,
          'id_commande_vente': idCommande,
          'id_statut': 5, // SOLDE
          'date_facture': DateTime.now().toIso8601String().substring(0, 10),
          'montant_ht': totalHt,
          'montant_tva': 0.0,
          'montant_ttc': totalTtc,
          'montant_paye': totalTtc,
        });

        // Paiement vente
        await txn.insert('paiement_vente', {
          'numero_paiement': 'PV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'id_facture_client': idFacture,
          'id_caisse': idCaisse,
          'id_mode_paiement': idModePaiement ?? 1,
          'id_utilisateur': idUtilisateur ?? 1,
          'date_paiement': DateTime.now().toIso8601String().substring(0, 10),
          'montant': totalTtc,
          'reference_transaction': numCommande,
          'notes': 'Règlement au comptant vente $numCommande',
        });
      } else {
        // Vente à crédit / paiement différé : création facture en attente (VALIDE = id 2)
        await txn.insert('facture_client', {
          'numero_facture': numFacture,
          'id_client': idClient,
          'id_commande_vente': idCommande,
          'id_statut': 2, // VALIDE (en cours / non soldée)
          'date_facture': DateTime.now().toIso8601String().substring(0, 10),
          'montant_ht': totalHt,
          'montant_tva': 0.0,
          'montant_ttc': totalTtc,
          'montant_paye': 0.0,
        });
      }

      return idCommande;
    });
  }

  // Règlement d'une créance client (encaissement différé)
  Future<void> reglerCreanceClient({
    required int idFactureClient,
    required int idCaisse,
    required int idModePaiement,
    required double montantRegle,
    String? notes,
    int? idUtilisateur,
  }) async {
    if (montantRegle <= 0) {
      throw Exception('Le montant réglé doit être supérieur à zéro');
    }

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Lire la facture client
      final factureRows = await txn.query(
        'facture_client',
        where: 'id = ?',
        whereArgs: [idFactureClient],
      );
      if (factureRows.isEmpty) throw Exception('Facture client introuvable');

      final facture = factureRows.first;
      final montantTtc = (facture['montant_ttc'] as num).toDouble();
      final montantDejaPaye = (facture['montant_paye'] as num).toDouble();
      final resteAPayer = montantTtc - montantDejaPaye;

      if (montantRegle > resteAPayer) {
        throw Exception(
          'Le montant (${montantRegle.toStringAsFixed(0)} Ar) dépasse le reste dû (${resteAPayer.toStringAsFixed(0)} Ar)',
        );
      }

      final nouveauMontantPaye = montantDejaPaye + montantRegle;
      final estTotalementSolde = nouveauMontantPaye >= montantTtc;

      // 2. Mettre à jour la facture client
      await txn.update(
        'facture_client',
        {
          'montant_paye': nouveauMontantPaye,
          'id_statut': estTotalementSolde ? 5 : 2, // 5 = SOLDE, 2 = VALIDE
        },
        where: 'id = ?',
        whereArgs: [idFactureClient],
      );

      // Si la commande de vente est liée, mettre à jour son statut si soldée
      final idCommande = facture['id_commande_vente'] as int?;
      if (idCommande != null && estTotalementSolde) {
        await txn.update(
          'commande_vente',
          {'id_statut': 5},
          where: 'id = ?',
          whereArgs: [idCommande],
        );
      }

      // 3. Mettre à jour le solde de la caisse (Crédit)
      final caisseRows = await txn.query('caisse', where: 'id = ?', whereArgs: [idCaisse]);
      if (caisseRows.isEmpty) throw Exception('Caisse introuvable');
      final soldeAvant = (caisseRows.first['solde_actuel'] as num).toDouble();
      final soldeApres = soldeAvant + montantRegle;

      await txn.update('caisse', {'solde_actuel': soldeApres}, where: 'id = ?', whereArgs: [idCaisse]);

      final numFacture = facture['numero_facture'] as String;

      final openJc = await txn.query('journal_caisse', columns: ['id'], where: "statut = 'OUVERT'", limit: 1);
      final idJournal = openJc.isNotEmpty ? openJc.first['id'] as int : null;

      // 4. Enregistrement MOUVEMENT DE CAISSE (ENCAISSEMENT_VENTE = id 1)
      await txn.insert('mouvement_caisse', {
        'id_caisse': idCaisse,
        'id_type_mouvement': 1, // ENCAISSEMENT_VENTE
        'id_mode_paiement': idModePaiement,
        'id_utilisateur': idUtilisateur ?? 1,
        'id_journal_caisse': idJournal,
        'montant': montantRegle,
        'solde_avant': soldeAvant,
        'solde_apres': soldeApres,
        'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        'reference_piece': numFacture,
        'description': 'Règlement créance client $numFacture',
      });

      // 5. Enregistrement paiement_vente
      await txn.insert('paiement_vente', {
        'numero_paiement': 'PV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'id_facture_client': idFactureClient,
        'id_caisse': idCaisse,
        'id_mode_paiement': idModePaiement,
        'id_utilisateur': idUtilisateur ?? 1,
        'date_paiement': DateTime.now().toIso8601String().substring(0, 10),
        'montant': montantRegle,
        'reference_transaction': numFacture,
        'notes': notes ?? 'Règlement créance client',
      });
    });
  }
}
