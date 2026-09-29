import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../models/caisse.dart';
import '../models/mode_paiement.dart';
import '../models/mouvement_caisse.dart';

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

      // 4. Insérer le mouvement
      await txn.insert('mouvement_caisse', {
        'id_caisse': idCaisse,
        'id_type_mouvement': idTypeMouvement,
        'id_mode_paiement': idModePaiement,
        'id_utilisateur': idUtilisateur ?? 1,
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

      // 5. Enregistrer les deux mouvements comptables correspondants
      // Débit source (Transfert Sortant = id 3)
      await txn.insert('mouvement_caisse', {
        'id_caisse': idCaisseSource,
        'id_type_mouvement': 3, // TRANSFERT_INTERNE_DEBIT
        'id_mode_paiement': 1, // Espèces/Standard
        'id_utilisateur': idUtilisateur ?? 1,
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
}
