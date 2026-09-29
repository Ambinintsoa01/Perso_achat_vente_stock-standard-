import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/commande_achat.dart';
import '../models/fournisseur.dart';

class LigneAchatInput {
  final int idArticle;
  final String designation;
  final double quantite;
  final double prixUnitaire;

  LigneAchatInput({
    required this.idArticle,
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
  });

  double get montantTotal => quantite * prixUnitaire;
}

class AchatSummary {
  final double totalAchatsMois;
  final int nombreCommandes;
  final double totalDettesFournisseurs;

  AchatSummary({
    required this.totalAchatsMois,
    required this.nombreCommandes,
    required this.totalDettesFournisseurs,
  });
}

class AchatService {
  final DbHelper _dbHelper = DbHelper.instance;

  // Liste des fournisseurs
  Future<List<Fournisseur>> getFournisseurs() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'fournisseur',
      where: 'actif = 1',
      orderBy: 'raison_sociale ASC',
    );
    return maps.map((m) => Fournisseur.fromMap(m)).toList();
  }

  // Ajouter un fournisseur
  Future<int> ajouterFournisseur({
    required String raisonSociale,
    String? nomContact,
    String? telephone,
    String? email,
    int delaiPaiement = 30,
  }) async {
    final db = await _dbHelper.database;
    final code = 'F-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    return await db.insert('fournisseur', {
      'code': code,
      'raison_sociale': raisonSociale.trim(),
      'nom_contact': nomContact?.trim(),
      'telephone': telephone?.trim(),
      'email': email?.trim(),
      'delai_paiement_jours': delaiPaiement,
      'actif': 1,
    });
  }

  // Liste des commandes d'achat avec informations jointes et filtre de date
  Future<List<CommandeAchat>> getCommandesAchat({
    bool? onlyUnpaid,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final db = await _dbHelper.database;
    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    String whereClause = '';
    List<dynamic> args = [];

    if (dateDebut != null) {
      whereClause += ' WHERE DATE(ca.date_commande) >= ?';
      args.add(formatter.format(dateDebut));
    }
    if (dateFin != null) {
      if (whereClause.isEmpty) {
        whereClause += ' WHERE DATE(ca.date_commande) <= ?';
      } else {
        whereClause += ' AND DATE(ca.date_commande) <= ?';
      }
      args.add(formatter.format(dateFin));
    }

    final query = '''
      SELECT 
        ca.*,
        f.raison_sociale as fournisseur_nom,
        s.numero as statut_numero,
        s.code as statut_code,
        s.libelle as statut_libelle,
        COUNT(cal.id) as lignes_count,
        COALESCE(ff.montant_paye, 0.0) as montant_paye
      FROM commande_achat ca
      JOIN fournisseur f ON ca.id_fournisseur = f.id
      JOIN statut s ON ca.id_statut = s.id
      LEFT JOIN commande_achat_ligne cal ON ca.id = cal.id_commande_achat
      LEFT JOIN facture_fournisseur ff ON ca.id = ff.id_commande_achat
      $whereClause
      GROUP BY ca.id
      ORDER BY ca.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    final list = maps.map((m) => CommandeAchat.fromMap(m)).toList();

    if (onlyUnpaid == true) {
      return list.where((c) => !c.estPaye).toList();
    }
    return list;
  }

  // Détails des lignes d'une commande d'achat
  Future<List<CommandeAchatLigne>> getLignesCommande(int idCommandeAchat) async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        cal.*,
        a.reference as article_reference,
        a.designation as article_designation,
        u.code as unite_code
      FROM commande_achat_ligne cal
      JOIN article a ON cal.id_article = a.id
      LEFT JOIN unite_mesure u ON a.id_unite = u.id
      WHERE cal.id_commande_achat = ?
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [idCommandeAchat]);
    return maps.map((m) => CommandeAchatLigne.fromMap(m)).toList();
  }

  // ENREGISTRER UN ACHAT COMPLET AVEC IMPACT STOCK ET CAISSE
  Future<int> enregistrerAchat({
    required int idFournisseur,
    required List<LigneAchatInput> articlesAchetes,
    required bool payeImmediatement,
    int? idCaisse,
    int? idModePaiement,
    String? dateEcheance,
    String? remarques,
    int? idUtilisateur,
    int idDepot = 1,
  }) async {
    if (articlesAchetes.isEmpty) {
      throw Exception('Veuillez ajouter au moins un article à la commande');
    }

    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. Calcul du montant total
      double totalHt = 0.0;
      for (var item in articlesAchetes) {
        totalHt += item.montantTotal;
      }
      final totalTtc = totalHt; // TVA incluse ou standard
      final numCommande = 'BCA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // Statut 5: SOLDE (si payé immédiatement) ou 2: VALIDE (si paiement différé)
      final statutId = payeImmediatement ? 5 : 2;

      // 2. Insertion de la commande d'achat
      final idCommande = await txn.insert('commande_achat', {
        'numero_commande': numCommande,
        'id_fournisseur': idFournisseur,
        'id_depot_destination': idDepot,
        'id_statut': statutId,
        'id_utilisateur': idUtilisateur ?? 1,
        'date_commande': DateTime.now().toIso8601String().substring(0, 10),
        'montant_ht': totalHt,
        'montant_tva': 0.0,
        'montant_ttc': totalTtc,
        'remarques': remarques,
      });

      // 3. Traitement de chaque ligne d'article :
      // -> Insertion commande_achat_ligne
      // -> Impact STOCK (stock_depot)
      // -> Traçabilité MOUVEMENT DE STOCK (mouvement_stock)
      // -> Recalcul automatique du CUMP (Coût Moyen Unitaire Pondéré)
      for (var item in articlesAchetes) {
        // Insertion ligne
        await txn.insert('commande_achat_ligne', {
          'id_commande_achat': idCommande,
          'id_article': item.idArticle,
          'quantite_commandee': item.quantite,
          'quantite_recue': item.quantite,
          'prix_unitaire_ht': item.prixUnitaire,
          'taux_remise': 0.0,
          'taux_tva': 20.0,
          'montant_ht': item.montantTotal,
          'montant_ttc': item.montantTotal,
        });

        // Lecture du stock actuel
        final stockRows = await txn.query(
          'stock_depot',
          where: 'id_depot = ? AND id_article = ?',
          whereArgs: [idDepot, item.idArticle],
        );

        double stockAvant = 0.0;
        if (stockRows.isNotEmpty) {
          stockAvant = (stockRows.first['quantite_reelle'] as num).toDouble();
        }
        final stockApres = stockAvant + item.quantite;

        // Mise à jour ou insertion stock_depot
        if (stockRows.isNotEmpty) {
          await txn.update(
            'stock_depot',
            {'quantite_reelle': stockApres, 'derniere_mise_a_jour': DateTime.now().toIso8601String()},
            where: 'id_depot = ? AND id_article = ?',
            whereArgs: [idDepot, item.idArticle],
          );
        } else {
          await txn.insert('stock_depot', {
            'id_depot': idDepot,
            'id_article': item.idArticle,
            'quantite_reelle': stockApres,
            'quantite_reservee': 0.0,
            'quantite_en_commande': 0.0,
          });
        }

        // Enregistrement MOUVEMENT STOCK (ENTREE_ACHAT = id 1)
        await txn.insert('mouvement_stock', {
          'id_depot': idDepot,
          'id_article': item.idArticle,
          'id_type_mouvement': 1, // ENTREE_ACHAT
          'id_utilisateur': idUtilisateur ?? 1,
          'quantite': item.quantite,
          'prix_unitaire': item.prixUnitaire,
          'stock_avant': stockAvant,
          'stock_apres': stockApres,
          'reference_document': numCommande,
          'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
          'remarque': 'Achat fournisseur $numCommande',
        });

        // Recalcul du CUMP (Coût Moyen Unitaire Pondéré)
        final articleRows = await txn.query('article', where: 'id = ?', whereArgs: [item.idArticle]);
        if (articleRows.isNotEmpty) {
          final ancCump = (articleRows.first['cout_moyen_unitaire'] as num?)?.toDouble() ?? 0.0;
          double nouveauCump = item.prixUnitaire;
          if (stockAvant > 0 && ancCump > 0) {
            nouveauCump = ((stockAvant * ancCump) + (item.quantite * item.prixUnitaire)) / stockApres;
          }
          await txn.update(
            'article',
            {
              'cout_moyen_unitaire': nouveauCump,
              'prix_achat_estime': item.prixUnitaire,
            },
            where: 'id = ?',
            whereArgs: [item.idArticle],
          );
        }
      }

      // 4. Traitement financier :
      // Si paiement immédiat :
      // -> Débit de la caisse choisie
      // -> Enregistrement MOUVEMENT DE CAISSE (mouvement_caisse)
      // -> Création facture fournisseur acquittée et paiement_achat
      final numFacture = 'FA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      if (payeImmediatement) {
        if (idCaisse == null) {
          throw Exception('Veuillez sélectionner un compte ou tiroir-caisse pour le règlement');
        }

        // Lecture du solde de la caisse
        final caisseRows = await txn.query('caisse', where: 'id = ?', whereArgs: [idCaisse]);
        if (caisseRows.isEmpty) throw Exception('Caisse introuvable');
        final soldeAvant = (caisseRows.first['solde_actuel'] as num).toDouble();

        if (soldeAvant < totalTtc) {
          throw Exception('Solde insuffisant dans la caisse (${soldeAvant.toStringAsFixed(0)} Ar disponible vs ${totalTtc.toStringAsFixed(0)} Ar requis)');
        }

        final soldeApres = soldeAvant - totalTtc;

        // Mise à jour de la caisse
        await txn.update('caisse', {'solde_actuel': soldeApres}, where: 'id = ?', whereArgs: [idCaisse]);

        final openJc = await txn.query('journal_caisse', columns: ['id'], where: "statut = 'OUVERT'", limit: 1);
        final idJournal = openJc.isNotEmpty ? openJc.first['id'] as int : null;

        // Enregistrement MOUVEMENT DE CAISSE (DECAISSEMENT_ACHAT = id 2)
        await txn.insert('mouvement_caisse', {
          'id_caisse': idCaisse,
          'id_type_mouvement': 2, // DECAISSEMENT_ACHAT
          'id_mode_paiement': idModePaiement ?? 1,
          'id_utilisateur': idUtilisateur ?? 1,
          'id_journal_caisse': idJournal,
          'montant': totalTtc,
          'solde_avant': soldeAvant,
          'solde_apres': soldeApres,
          'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
          'reference_piece': numCommande,
          'description': 'Achat comptant $numCommande',
        });

        // Facture acquittée
        final idFacture = await txn.insert('facture_fournisseur', {
          'numero_facture': numFacture,
          'id_fournisseur': idFournisseur,
          'id_commande_achat': idCommande,
          'id_statut': 5, // SOLDE
          'date_facture': DateTime.now().toIso8601String().substring(0, 10),
          'montant_ht': totalHt,
          'montant_tva': 0.0,
          'montant_ttc': totalTtc,
          'montant_paye': totalTtc,
        });

        // Paiement achat
        await txn.insert('paiement_achat', {
          'numero_paiement': 'PA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          'id_facture_fournisseur': idFacture,
          'id_caisse': idCaisse,
          'id_mode_paiement': idModePaiement ?? 1,
          'id_utilisateur': idUtilisateur ?? 1,
          'date_paiement': DateTime.now().toIso8601String().substring(0, 10),
          'montant': totalTtc,
          'notes': 'Paiement immédiat à la commande',
        });
      } else {
        // Enregistrement comme dette fournisseur
        await txn.insert('facture_fournisseur', {
          'numero_facture': numFacture,
          'id_fournisseur': idFournisseur,
          'id_commande_achat': idCommande,
          'id_statut': 2, // VALIDE / NON PAYÉ
          'date_facture': DateTime.now().toIso8601String().substring(0, 10),
          'date_echeance': dateEcheance,
          'montant_ht': totalHt,
          'montant_tva': 0.0,
          'montant_ttc': totalTtc,
          'montant_paye': 0.0,
        });
      }

      return idCommande;
    });
  }

  // Règlement différé d'une dette fournisseur (Règle la facture et impacte la caisse)
  Future<void> reglerDetteFournisseur({
    required int idCommandeAchat,
    required int idCaisse,
    required int idModePaiement,
    required double montant,
    int? idUtilisateur,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Lire la facture associée
      final factureRows = await txn.query(
        'facture_fournisseur',
        where: 'id_commande_achat = ?',
        whereArgs: [idCommandeAchat],
      );
      if (factureRows.isEmpty) throw Exception('Facture fournisseur introuvable');

      final facture = factureRows.first;
      final idFacture = facture['id'] as int;
      final montantTtc = (facture['montant_ttc'] as num).toDouble();
      final dejaPaye = (facture['montant_paye'] as num).toDouble();
      final resteAPayer = montantTtc - dejaPaye;

      if (montant > resteAPayer) {
        throw Exception('Le montant dépasse le reste à payer ($resteAPayer Ar)');
      }

      // 2. Débit de la caisse
      final caisseRows = await txn.query('caisse', where: 'id = ?', whereArgs: [idCaisse]);
      if (caisseRows.isEmpty) throw Exception('Caisse introuvable');
      final soldeAvant = (caisseRows.first['solde_actuel'] as num).toDouble();

      if (soldeAvant < montant) {
        throw Exception('Solde insuffisant dans la caisse ($soldeAvant Ar disponible)');
      }

      final soldeApres = soldeAvant - montant;
      await txn.update('caisse', {'solde_actuel': soldeApres}, where: 'id = ?', whereArgs: [idCaisse]);

      final openJc = await txn.query('journal_caisse', columns: ['id'], where: "statut = 'OUVERT'", limit: 1);
      final idJournal = openJc.isNotEmpty ? openJc.first['id'] as int : null;

      // 3. Mouvement de caisse
      await txn.insert('mouvement_caisse', {
        'id_caisse': idCaisse,
        'id_type_mouvement': 2, // DECAISSEMENT_ACHAT
        'id_mode_paiement': idModePaiement,
        'id_utilisateur': idUtilisateur ?? 1,
        'id_journal_caisse': idJournal,
        'montant': montant,
        'solde_avant': soldeAvant,
        'solde_apres': soldeApres,
        'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        'reference_piece': facture['numero_facture'],
        'description': 'Règlement dette fournisseur',
      });

      // 4. Mettre à jour la facture
      final nouveauPaye = dejaPaye + montant;
      final estSolde = nouveauPaye >= montantTtc;
      await txn.update(
        'facture_fournisseur',
        {
          'montant_paye': nouveauPaye,
          'id_statut': estSolde ? 5 : 4, // 5: SOLDE, 4: PARTIEL
        },
        where: 'id = ?',
        whereArgs: [idFacture],
      );

      // Si soldé, mettre à jour la commande
      if (estSolde) {
        await txn.update(
          'commande_achat',
          {'id_statut': 5},
          where: 'id = ?',
          whereArgs: [idCommandeAchat],
        );
      }

      // 5. Enregistrer le paiement
      await txn.insert('paiement_achat', {
        'numero_paiement': 'PA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'id_facture_fournisseur': idFacture,
        'id_caisse': idCaisse,
        'id_mode_paiement': idModePaiement,
        'id_utilisateur': idUtilisateur ?? 1,
        'date_paiement': DateTime.now().toIso8601String().substring(0, 10),
        'montant': montant,
        'notes': 'Règlement de dette fournisseur',
      });
    });
  }

  // Résumé global des achats (Dépenses d'achat + Dettes fournisseurs en cours)
  Future<AchatSummary> getAchatSummary() async {
    final db = await _dbHelper.database;

    // Total achats
    final achatsResult = await db.rawQuery('SELECT SUM(montant_ttc) as total, COUNT(*) as count FROM commande_achat');
    double totalAchats = 0.0;
    int count = 0;
    if (achatsResult.isNotEmpty) {
      totalAchats = (achatsResult.first['total'] as num?)?.toDouble() ?? 0.0;
      count = (achatsResult.first['count'] as int?) ?? 0;
    }

    // Dettes fournisseurs (Total TTC - Montant payé)
    final dettesResult = await db.rawQuery('''
      SELECT SUM(montant_ttc - montant_paye) as total_dettes
      FROM facture_fournisseur
      WHERE montant_ttc > montant_paye
    ''');
    double totalDettes = 0.0;
    if (dettesResult.isNotEmpty && dettesResult.first['total_dettes'] != null) {
      totalDettes = (dettesResult.first['total_dettes'] as num).toDouble();
    }

    return AchatSummary(
      totalAchatsMois: totalAchats,
      nombreCommandes: count,
      totalDettesFournisseurs: totalDettes,
    );
  }
}
