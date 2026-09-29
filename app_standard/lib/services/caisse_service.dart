import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/caisse.dart';
import '../models/mode_paiement.dart';
import '../models/mouvement_caisse.dart';
import '../models/journal_caisse.dart';

class CaisseService {
  final DbHelper _dbHelper = DbHelper.instance;

  // Récupérer toutes les caisses actives
  Future<List<Caisse>> getCaisses() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        c.*, 
        tc.code as type_code, 
        tc.libelle as type_libelle,
        d.code as devise_code,
        d.symbole as devise_symbole
      FROM caisse c
      JOIN type_caisse tc ON c.id_type_caisse = tc.id
      JOIN devise d ON c.id_devise = d.id
      WHERE c.actif = 1
      ORDER BY c.id ASC
    ''');
    return maps.map((m) => Caisse.fromMap(m)).toList();
  }

  // Calcul du solde global de la boutique (Toutes caisses confondues)
  Future<double> getTotalTresorerie() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT SUM(solde_actuel) as total FROM caisse WHERE actif = 1');
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Liste des mouvements avec filtres de caisse, dates et jointures
  Future<List<MouvementCaisse>> getMouvements({
    int? idCaisse,
    DateTime? dateDebut,
    DateTime? dateFin,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = 'WHERE 1=1';
    List<dynamic> args = [];

    if (idCaisse != null && idCaisse > 0) {
      whereClause += ' AND m.id_caisse = ?';
      args.add(idCaisse);
    }

    if (dateDebut != null) {
      final strDebut = DateFormat('yyyy-MM-dd').format(dateDebut);
      whereClause += ' AND DATE(m.date_mouvement) >= ?';
      args.add(strDebut);
    }

    if (dateFin != null) {
      final strFin = DateFormat('yyyy-MM-dd').format(dateFin);
      whereClause += ' AND DATE(m.date_mouvement) <= ?';
      args.add(strFin);
    }

    final query = '''
      SELECT 
        m.*,
        c.nom as caisse_nom,
        tm.code as type_code,
        tm.libelle as type_libelle,
        tm.sens as sens,
        mp.libelle as mode_paiement_libelle,
        u.nom_utilisateur as utilisateur_nom
      FROM mouvement_caisse m
      JOIN caisse c ON m.id_caisse = c.id
      JOIN type_mouvement_caisse tm ON m.id_type_mouvement = tm.id
      JOIN mode_paiement mp ON m.id_mode_paiement = mp.id
      LEFT JOIN utilisateur u ON m.id_utilisateur = u.id
      $whereClause
      ORDER BY m.id DESC
      LIMIT $limit
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps.map((m) => MouvementCaisse.fromMap(m)).toList();
  }

  // Liste des modes de paiement disponibles
  Future<List<ModePaiement>> getModesPaiement() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'mode_paiement',
      where: 'actif = 1',
      orderBy: 'numero ASC',
    );
    return maps.map((m) => ModePaiement.fromMap(m)).toList();
  }

  // Effectuer un mouvement (Encaissement ou Décaissement)
  Future<void> enregistrerMouvement({
    required int idCaisse,
    required int idTypeMouvement,
    required int idModePaiement,
    required double montant,
    int? idUtilisateur,
    String? referencePiece,
    String? description,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Lire la caisse
      final caisseRows = await txn.query('caisse', where: 'id = ?', whereArgs: [idCaisse]);
      if (caisseRows.isEmpty) throw Exception('Caisse introuvable');
      final soldeAvant = (caisseRows.first['solde_actuel'] as num).toDouble();

      // 2. Déterminer le sens du mouvement
      final typeRows = await txn.query('type_mouvement_caisse', where: 'id = ?', whereArgs: [idTypeMouvement]);
      if (typeRows.isEmpty) throw Exception('Type de mouvement introuvable');
      final sens = typeRows.first['sens'] as int;

      // Vérifier le solde si décaissement
      if (sens < 0 && soldeAvant < montant) {
        throw Exception('Solde insuffisant dans la caisse (${soldeAvant.toStringAsFixed(0)} Ar disponible)');
      }

      final soldeApres = soldeAvant + (sens * montant);

      // 3. Mettre à jour le solde de la caisse
      await txn.update(
        'caisse',
        {'solde_actuel': soldeApres},
        where: 'id = ?',
        whereArgs: [idCaisse],
      );

      // 4. Déterminer si un journal est ouvert pour y rattacher le mouvement
      final openJournalRows = await txn.query('journal_caisse', columns: ['id'], where: "statut = 'OUVERT'", limit: 1);
      final idJournal = openJournalRows.isNotEmpty ? openJournalRows.first['id'] as int : null;

      // 5. Insérer le mouvement
      await txn.insert('mouvement_caisse', {
        'id_caisse': idCaisse,
        'id_type_mouvement': idTypeMouvement,
        'id_mode_paiement': idModePaiement,
        'id_utilisateur': idUtilisateur ?? 1,
        'id_journal_caisse': idJournal,
        'montant': montant,
        'solde_avant': soldeAvant,
        'solde_apres': soldeApres,
        'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        'reference_piece': referencePiece,
        'description': description,
      });
    });
  }

  // Effectuer un transfert inter-comptes (ex: Retrait MVola vers Cash, ou Cash vers Banque)
  Future<void> transfertInterne({
    required int idCaisseSource,
    required int idCaisseDestination,
    required double montant,
    double frais = 0.0,
    int? idUtilisateur,
    String? motif,
  }) async {
    if (idCaisseSource == idCaisseDestination) {
      throw Exception('Les caisses source et destination doivent être différentes');
    }

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Vérifier la caisse source
      final srcRows = await txn.query('caisse', where: 'id = ?', whereArgs: [idCaisseSource]);
      if (srcRows.isEmpty) throw Exception('Caisse source introuvable');
      final soldeSrcAvant = (srcRows.first['solde_actuel'] as num).toDouble();
      final totalDebit = montant + frais;

      if (soldeSrcAvant < totalDebit) {
        throw Exception('Solde source insuffisant ($soldeSrcAvant Ar vs $totalDebit Ar requis)');
      }

      // 2. Vérifier la caisse destination
      final destRows = await txn.query('caisse', where: 'id = ?', whereArgs: [idCaisseDestination]);
      if (destRows.isEmpty) throw Exception('Caisse destination introuvable');
      final soldeDestAvant = (destRows.first['solde_actuel'] as num).toDouble();

      final soldeSrcApres = soldeSrcAvant - totalDebit;
      final soldeDestApres = soldeDestAvant + montant;

      // 3. Mettre à jour les deux caisses
      await txn.update('caisse', {'solde_actuel': soldeSrcApres}, where: 'id = ?', whereArgs: [idCaisseSource]);
      await txn.update('caisse', {'solde_actuel': soldeDestApres}, where: 'id = ?', whereArgs: [idCaisseDestination]);

      final ref = 'TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // 4. Enregistrer dans transfert_caisse
      await txn.insert('transfert_caisse', {
        'numero_transfert': ref,
        'id_caisse_source': idCaisseSource,
        'id_caisse_destination': idCaisseDestination,
        'montant': montant,
        'frais_transfert': frais,
        'id_statut': 2, // Validé
        'id_utilisateur': idUtilisateur ?? 1,
        'date_transfert': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        'motif': motif,
      });

      // Journal ouvert
      final openJournalRows = await txn.query('journal_caisse', columns: ['id'], where: "statut = 'OUVERT'", limit: 1);
      final idJournal = openJournalRows.isNotEmpty ? openJournalRows.first['id'] as int : null;

      // 5. Enregistrer les deux mouvements comptables correspondants
      // Débit source (Transfert Sortant = id 3)
      await txn.insert('mouvement_caisse', {
        'id_caisse': idCaisseSource,
        'id_type_mouvement': 3, // TRANSFERT_INTERNE_DEBIT
        'id_mode_paiement': 1, // Espèces/Standard
        'id_utilisateur': idUtilisateur ?? 1,
        'id_journal_caisse': idJournal,
        'montant': totalDebit,
        'solde_avant': soldeSrcAvant,
        'solde_apres': soldeSrcApres,
        'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        'reference_piece': ref,
        'description': 'Transfert vers ${destRows.first['nom']}${frais > 0 ? " (dont $frais Ar frais)" : ""}',
      });

      // Crédit destination (Transfert Entrant = id 4)
      await txn.insert('mouvement_caisse', {
        'id_caisse': idCaisseDestination,
        'id_type_mouvement': 4, // TRANSFERT_INTERNE_CREDIT
        'id_mode_paiement': 1,
        'id_utilisateur': idUtilisateur ?? 1,
        'id_journal_caisse': idJournal,
        'montant': montant,
        'solde_avant': soldeDestAvant,
        'solde_apres': soldeDestApres,
        'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
        'reference_piece': ref,
        'description': 'Transfert reçu de ${srcRows.first['nom']}',
      });
    });
  }

  // Création d'une nouvelle caisse
  Future<void> ajouterCaisse({
    required String code,
    required String nom,
    required int idTypeCaisse,
    String? numeroCompte,
    double soldeInitial = 0.0,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final id = await txn.insert('caisse', {
        'code': code,
        'nom': nom,
        'id_type_caisse': idTypeCaisse,
        'numero_compte': numeroCompte,
        'solde_initial': soldeInitial,
        'solde_actuel': soldeInitial,
        'id_devise': 1, // MGA par défaut
        'actif': 1,
      });

      if (soldeInitial > 0) {
        await txn.insert('mouvement_caisse', {
          'id_caisse': id,
          'id_type_mouvement': 6, // APPORT_FONDS
          'id_mode_paiement': 1,
          'id_utilisateur': 1,
          'montant': soldeInitial,
          'solde_avant': 0.0,
          'solde_apres': soldeInitial,
          'date_mouvement': DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' '),
          'reference_piece': 'INIT-$code',
          'description': 'Solde initial d\'ouverture',
        });
      }
    });
  }

  // ===========================================================================
  // JOURNAL DE CAISSE (Ouverture matin, Clôture soir, Report des soldes)
  // ===========================================================================

  // 1. Récupérer le journal actuellement ouvert (s'il existe)
  Future<JournalCaisse?> getJournalOuvert() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        jc.*,
        u_ouv.nom_utilisateur as nom_utilisateur_ouverture,
        u_fer.nom_utilisateur as nom_utilisateur_fermeture
      FROM journal_caisse jc
      LEFT JOIN utilisateur u_ouv ON jc.id_utilisateur_ouverture = u_ouv.id
      LEFT JOIN utilisateur u_fer ON jc.id_utilisateur_fermeture = u_fer.id
      WHERE jc.statut = 'OUVERT'
      ORDER BY jc.id DESC
      LIMIT 1
    ''');

    if (maps.isEmpty) return null;

    final headerMap = maps.first;
    final journalId = headerMap['id'] as int;
    final lignes = await getLignesJournalAvecTotaux(journalId);

    return JournalCaisse.fromMap(headerMap, lignes: lignes);
  }

  // 2. Calculer / Suggérer les soldes d'ouverture pour chaque compte de caisse
  // RÈGLE : Le reste d'argent d'aujourd'hui (clôture) sera le solde de demain (ouverture)
  Future<Map<int, double>> getSoldesOuvertureSuggeres() async {
    final db = await _dbHelper.database;
    final caisses = await getCaisses();
    final Map<int, double> result = {};

    for (final caisse in caisses) {
      // Trouver la dernière clôture enregistrée pour cette caisse
      final List<Map<String, dynamic>> lastClosure = await db.rawQuery('''
        SELECT jcl.solde_reel, jcl.solde_theorique
        FROM journal_caisse_ligne jcl
        JOIN journal_caisse jc ON jcl.id_journal_caisse = jc.id
        WHERE jcl.id_caisse = ? AND jc.statut = 'CLOTURE'
        ORDER BY jc.date_journal DESC, jc.id DESC
        LIMIT 1
      ''', [caisse.id]);

      if (lastClosure.isNotEmpty) {
        final row = lastClosure.first;
        final solde = (row['solde_reel'] as num?)?.toDouble() ??
            (row['solde_theorique'] as num?)?.toDouble() ??
            caisse.soldeActuel;
        result[caisse.id] = solde;
      } else {
        // Fallback si tout premier journal : solde actuel du compte
        result[caisse.id] = caisse.soldeActuel;
      }
    }

    return result;
  }

  // 3. Ouvrir la caisse le matin avec les soldes initiaux
  Future<JournalCaisse> ouvrirJournal({
    required int idUtilisateur,
    required Map<int, double> soldesOuvertureParCaisse,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final dateJournal = DateFormat('yyyy-MM-dd').format(now);
    final nowStr = now.toIso8601String().substring(0, 19).replaceAll('T', ' ');

    return await db.transaction((txn) async {
      // Vérifier si un journal est déjà actif
      final openJournals = await txn.query(
        'journal_caisse',
        where: "statut = 'OUVERT'",
        limit: 1,
      );
      if (openJournals.isNotEmpty) {
        throw Exception('Une session de caisse est déjà ouverte (N° ${openJournals.first['numero_journal']}). Clôturez-la avant d\'en ouvrir une nouvelle.');
      }

      // Total d'ouverture
      double totalOuverture = 0.0;
      soldesOuvertureParCaisse.forEach((_, val) => totalOuverture += val);

      // Générer référence : JRN-YYYYMMDD-01
      final countTodayRes = await txn.rawQuery(
        'SELECT COUNT(*) as cnt FROM journal_caisse WHERE date_journal = ?',
        [dateJournal],
      );
      final countToday = ((countTodayRes.first['cnt'] as num?)?.toInt() ?? 0) + 1;
      final refJournal = 'JRN-${DateFormat('yyyyMMdd').format(now)}-${countToday.toString().padLeft(2, '0')}';

      final journalId = await txn.insert('journal_caisse', {
        'numero_journal': refJournal,
        'date_journal': dateJournal,
        'date_ouverture': nowStr,
        'id_utilisateur_ouverture': idUtilisateur,
        'solde_ouverture_total': totalOuverture,
        'total_entrees': 0.0,
        'total_sorties': 0.0,
        'solde_theorique_total': totalOuverture,
        'solde_reel_total': 0.0,
        'ecart_total': 0.0,
        'statut': 'OUVERT',
        'notes_ouverture': notes,
      });

      // Créer les lignes pour chaque compte de caisse
      for (final entry in soldesOuvertureParCaisse.entries) {
        final idCaisse = entry.key;
        final soldeOuv = entry.value;

        await txn.insert('journal_caisse_ligne', {
          'id_journal_caisse': journalId,
          'id_caisse': idCaisse,
          'solde_ouverture': soldeOuv,
          'total_entrees': 0.0,
          'total_sorties': 0.0,
          'solde_theorique': soldeOuv,
          'solde_reel': null,
          'ecart': 0.0,
        });

        // Synchroniser le solde actuel de la caisse avec le solde d'ouverture
        await txn.update(
          'caisse',
          {'solde_actuel': soldeOuv},
          where: 'id = ?',
          whereArgs: [idCaisse],
        );
      }

      // Renvoyer l'instance complète
      final List<Map<String, dynamic>> resMaps = await txn.rawQuery('''
        SELECT 
          jc.*,
          u_ouv.nom_utilisateur as nom_utilisateur_ouverture,
          u_fer.nom_utilisateur as nom_utilisateur_fermeture
        FROM journal_caisse jc
        LEFT JOIN utilisateur u_ouv ON jc.id_utilisateur_ouverture = u_ouv.id
        LEFT JOIN utilisateur u_fer ON jc.id_utilisateur_fermeture = u_fer.id
        WHERE jc.id = ?
      ''', [journalId]);

      final rawLignes = await txn.rawQuery('''
        SELECT 
          jcl.*,
          c.nom as caisse_nom,
          c.code as caisse_code,
          tc.libelle as type_caisse_libelle
        FROM journal_caisse_ligne jcl
        JOIN caisse c ON jcl.id_caisse = c.id
        JOIN type_caisse tc ON c.id_type_caisse = tc.id
        WHERE jcl.id_journal_caisse = ?
        ORDER BY c.id ASC
      ''', [journalId]);

      final lignes = rawLignes.map((m) => JournalCaisseLigne.fromMap(m)).toList();
      return JournalCaisse.fromMap(resMaps.first, lignes: lignes);
    });
  }

  // 4. Calcul en direct des lignes et flux d'un journal (entrées, sorties, solde théorique)
  Future<List<JournalCaisseLigne>> getLignesJournalAvecTotaux(int idJournal) async {
    final db = await _dbHelper.database;
    final jcRows = await db.query('journal_caisse', where: 'id = ?', whereArgs: [idJournal]);
    if (jcRows.isEmpty) return [];

    final journal = jcRows.first;
    final isOuvert = journal['statut'] == 'OUVERT';

    final List<Map<String, dynamic>> rawLignes = await db.rawQuery('''
      SELECT 
        jcl.*,
        c.nom as caisse_nom,
        c.code as caisse_code,
        tc.libelle as type_caisse_libelle
      FROM journal_caisse_ligne jcl
      JOIN caisse c ON jcl.id_caisse = c.id
      JOIN type_caisse tc ON c.id_type_caisse = tc.id
      WHERE jcl.id_journal_caisse = ?
      ORDER BY c.id ASC
    ''', [idJournal]);

    final List<JournalCaisseLigne> lignes = [];

    for (final raw in rawLignes) {
      final idCaisse = raw['id_caisse'] as int;
      final soldeOuverture = (raw['solde_ouverture'] as num).toDouble();

      if (isOuvert) {
        // Somme des flux en direct
        final mvtRes = await db.rawQuery('''
          SELECT 
            COALESCE(SUM(CASE WHEN tm.sens = 1 THEN m.montant ELSE 0 END), 0) as entrees,
            COALESCE(SUM(CASE WHEN tm.sens = -1 THEN m.montant ELSE 0 END), 0) as sorties
          FROM mouvement_caisse m
          JOIN type_mouvement_caisse tm ON m.id_type_mouvement = tm.id
          WHERE m.id_caisse = ?
            AND m.id_journal_caisse = ?
        ''', [idCaisse, idJournal]);

        final entrees = (mvtRes.first['entrees'] as num).toDouble();
        final sorties = (mvtRes.first['sorties'] as num).toDouble();
        final theorique = soldeOuverture + entrees - sorties;

        lignes.add(JournalCaisseLigne(
          id: raw['id'] as int,
          idJournalCaisse: idJournal,
          idCaisse: idCaisse,
          caisseNom: raw['caisse_nom'] as String?,
          caisseCode: raw['caisse_code'] as String?,
          typeCaisseLibelle: raw['type_caisse_libelle'] as String?,
          soldeOuverture: soldeOuverture,
          totalEntrees: entrees,
          totalSorties: sorties,
          soldeTheorique: theorique,
          soldeReel: (raw['solde_reel'] as num?)?.toDouble(),
          ecart: raw['solde_reel'] != null
              ? ((raw['solde_reel'] as num).toDouble() - theorique)
              : 0.0,
          notes: raw['notes'] as String?,
        ));
      } else {
        lignes.add(JournalCaisseLigne.fromMap(raw));
      }
    }

    return lignes;
  }

  // 5. Fermer la caisse le soir (Clôture journalière)
  Future<void> fermerJournal({
    required int idJournal,
    required int idUtilisateurFermeture,
    required Map<int, double> soldesReelsParCaisse,
    String? notesFermeture,
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');

    await db.transaction((txn) async {
      final jcRows = await txn.query('journal_caisse', where: 'id = ?', whereArgs: [idJournal]);
      if (jcRows.isEmpty) throw Exception('Journal introuvable');
      final jc = jcRows.first;
      if (jc['statut'] != 'OUVERT') throw Exception('Ce journal est déjà clôturé');

      final dateOuverture = jc['date_ouverture'] as String;

      final lignesRows = await txn.query(
        'journal_caisse_ligne',
        where: 'id_journal_caisse = ?',
        whereArgs: [idJournal],
      );

      double sumEntrees = 0.0;
      double sumSorties = 0.0;
      double sumTheorique = 0.0;
      double sumReel = 0.0;
      double sumEcart = 0.0;

      for (final line in lignesRows) {
        final lineId = line['id'] as int;
        final idCaisse = line['id_caisse'] as int;
        final soldeOuv = (line['solde_ouverture'] as num).toDouble();

        // Calculer les entrées/sorties réelles de la journée
        final mvtRes = await txn.rawQuery('''
          SELECT 
            COALESCE(SUM(CASE WHEN tm.sens = 1 THEN m.montant ELSE 0 END), 0) as entrees,
            COALESCE(SUM(CASE WHEN tm.sens = -1 THEN m.montant ELSE 0 END), 0) as sorties
          FROM mouvement_caisse m
          JOIN type_mouvement_caisse tm ON m.id_type_mouvement = tm.id
          WHERE m.id_caisse = ?
            AND m.id_journal_caisse = ?
        ''', [idCaisse, idJournal]);

        final entrees = (mvtRes.first['entrees'] as num).toDouble();
        final sorties = (mvtRes.first['sorties'] as num).toDouble();
        final theorique = soldeOuv + entrees - sorties;
        final reel = soldesReelsParCaisse[idCaisse] ?? theorique;
        final ecart = reel - theorique;

        sumEntrees += entrees;
        sumSorties += sorties;
        sumTheorique += theorique;
        sumReel += reel;
        sumEcart += ecart;

        // Rattacher les mouvements orphelins à cette session
        await txn.rawUpdate('''
          UPDATE mouvement_caisse 
          SET id_journal_caisse = ?
          WHERE id_caisse = ? AND id_journal_caisse IS NULL AND date_mouvement >= ? AND date_mouvement <= ?
        ''', [idJournal, idCaisse, dateOuverture, nowStr]);

        // Mettre à jour la ligne du journal
        await txn.update(
          'journal_caisse_ligne',
          {
            'total_entrees': entrees,
            'total_sorties': sorties,
            'solde_theorique': theorique,
            'solde_reel': reel,
            'ecart': ecart,
          },
          where: 'id = ?',
          whereArgs: [lineId],
        );

        // Mettre à jour le solde actuel de la caisse avec le solde réel clôturé
        await txn.update(
          'caisse',
          {'solde_actuel': reel},
          where: 'id = ?',
          whereArgs: [idCaisse],
        );
      }

      // Mettre à jour le journal de caisse
      await txn.update(
        'journal_caisse',
        {
          'date_fermeture': nowStr,
          'id_utilisateur_fermeture': idUtilisateurFermeture,
          'total_entrees': sumEntrees,
          'total_sorties': sumSorties,
          'solde_theorique_total': sumTheorique,
          'solde_reel_total': sumReel,
          'ecart_total': sumEcart,
          'statut': 'CLOTURE',
          'notes_fermeture': notesFermeture,
          'updated_at': nowStr,
        },
        where: 'id = ?',
        whereArgs: [idJournal],
      );
    });
  }

  // 6. Historique des journaux de caisse avec filtre de date obligatoire (AGENTS.md)
  Future<List<JournalCaisse>> getJournaux({
    DateTime? dateDebut,
    DateTime? dateFin,
    String? statut,
  }) async {
    final db = await _dbHelper.database;
    String whereClause = 'WHERE 1=1';
    List<dynamic> args = [];

    if (dateDebut != null) {
      whereClause += ' AND DATE(jc.date_journal) >= ?';
      args.add(DateFormat('yyyy-MM-dd').format(dateDebut));
    }

    if (dateFin != null) {
      whereClause += ' AND DATE(jc.date_journal) <= ?';
      args.add(DateFormat('yyyy-MM-dd').format(dateFin));
    }

    if (statut != null && statut.isNotEmpty) {
      whereClause += ' AND jc.statut = ?';
      args.add(statut);
    }

    final query = '''
      SELECT 
        jc.*,
        u_ouv.nom_utilisateur as nom_utilisateur_ouverture,
        u_fer.nom_utilisateur as nom_utilisateur_fermeture
      FROM journal_caisse jc
      LEFT JOIN utilisateur u_ouv ON jc.id_utilisateur_ouverture = u_ouv.id
      LEFT JOIN utilisateur u_fer ON jc.id_utilisateur_fermeture = u_fer.id
      $whereClause
      ORDER BY jc.date_journal DESC, jc.id DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    return maps.map((m) => JournalCaisse.fromMap(m)).toList();
  }

  // 7. Obtenir le détail complet d'un journal avec toutes ses lignes
  Future<JournalCaisse?> getJournalDetails(int idJournal) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        jc.*,
        u_ouv.nom_utilisateur as nom_utilisateur_ouverture,
        u_fer.nom_utilisateur as nom_utilisateur_fermeture
      FROM journal_caisse jc
      LEFT JOIN utilisateur u_ouv ON jc.id_utilisateur_ouverture = u_ouv.id
      LEFT JOIN utilisateur u_fer ON jc.id_utilisateur_fermeture = u_fer.id
      WHERE jc.id = ?
    ''', [idJournal]);

    if (maps.isEmpty) return null;

    final lignes = await getLignesJournalAvecTotaux(idJournal);
    return JournalCaisse.fromMap(maps.first, lignes: lignes);
  }
}
