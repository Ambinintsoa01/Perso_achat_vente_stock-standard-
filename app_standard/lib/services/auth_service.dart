import 'package:flutter/foundation.dart';
import '../database/db_helper.dart';
import '../models/profil.dart';
import '../models/utilisateur.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  factory AuthService() => instance;

  final DbHelper _dbHelper = DbHelper.instance;

  Utilisateur? _currentUser;

  Utilisateur? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Connexion utilisateur
  Future<Utilisateur> login({
    required String nomUtilisateur,
    required String motDePasse,
  }) async {
    final cleanUsername = nomUtilisateur.trim();
    final cleanPassword = motDePasse.trim();

    if (cleanUsername.isEmpty) {
      throw Exception('Veuillez saisir votre nom d\'utilisateur');
    }
    if (cleanPassword.isEmpty) {
      throw Exception('Veuillez saisir votre mot de passe');
    }

    final db = await _dbHelper.database;

    final query = '''
      SELECT 
        u.*,
        p.code as profil_code,
        p.libelle as profil_libelle
      FROM utilisateur u
      JOIN profil p ON u.id_profil = p.id
      WHERE LOWER(u.nom_utilisateur) = LOWER(?) AND u.actif = 1
      LIMIT 1
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [cleanUsername]);

    if (maps.isEmpty) {
      throw Exception('Nom d\'utilisateur inconnu ou compte inactif');
    }

    final user = Utilisateur.fromMap(maps.first);

    // Vérification du mot de passe
    if (user.motDePasseHash != cleanPassword) {
      throw Exception('Mot de passe incorrect');
    }

    _currentUser = user;
    notifyListeners();
    return user;
  }

  // Déconnexion
  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // Liste de tous les profils disponibles
  Future<List<Profil>> getProfils() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'profil',
      where: 'actif = 1',
      orderBy: 'numero ASC',
    );
    return maps.map((m) => Profil.fromMap(m)).toList();
  }

  // Liste de tous les utilisateurs avec leur profil
  Future<List<Utilisateur>> getUtilisateurs() async {
    final db = await _dbHelper.database;
    final query = '''
      SELECT 
        u.*,
        p.code as profil_code,
        p.libelle as profil_libelle
      FROM utilisateur u
      JOIN profil p ON u.id_profil = p.id
      WHERE u.actif = 1
      ORDER BY u.nom ASC
    ''';
    final List<Map<String, dynamic>> maps = await db.rawQuery(query);
    return maps.map((m) => Utilisateur.fromMap(m)).toList();
  }

  // Création d'un nouvel utilisateur
  Future<int> creerUtilisateur({
    required int idProfil,
    required String nom,
    String? prenom,
    String? email,
    String? telephone,
    required String nomUtilisateur,
    required String motDePasse,
  }) async {
    final db = await _dbHelper.database;

    // Vérifier si le nom d'utilisateur est déjà pris
    final exists = await db.query(
      'utilisateur',
      where: 'LOWER(nom_utilisateur) = LOWER(?)',
      whereArgs: [nomUtilisateur.trim()],
    );

    if (exists.isNotEmpty) {
      throw Exception('Ce nom d\'utilisateur est déjà utilisé');
    }

    return await db.insert('utilisateur', {
      'id_profil': idProfil,
      'nom': nom.trim(),
      'prenom': prenom?.trim(),
      'email': email?.trim(),
      'telephone': telephone?.trim(),
      'nom_utilisateur': nomUtilisateur.trim(),
      'mot_de_passe_hash': motDePasse.trim(),
      'actif': 1,
    });
  }

  // Changement de mot de passe
  Future<void> changerMotDePasse({
    required int idUtilisateur,
    required String ancienMdp,
    required String nouveauMdp,
  }) async {
    if (nouveauMdp.trim().length < 4) {
      throw Exception('Le nouveau mot de passe doit comporter au moins 4 caractères');
    }

    final db = await _dbHelper.database;

    final users = await db.query('utilisateur', where: 'id = ?', whereArgs: [idUtilisateur]);
    if (users.isEmpty) throw Exception('Utilisateur introuvable');

    final currentMdp = users.first['mot_de_passe_hash'] as String;
    if (currentMdp != ancienMdp.trim()) {
      throw Exception('L\'ancien mot de passe est incorrect');
    }

    await db.update(
      'utilisateur',
      {'mot_de_passe_hash': nouveauMdp.trim()},
      where: 'id = ?',
      whereArgs: [idUtilisateur],
    );

    // Mettre à jour l'utilisateur courant si c'est lui
    if (_currentUser != null && _currentUser!.id == idUtilisateur) {
      _currentUser = Utilisateur(
        id: _currentUser!.id,
        idProfil: _currentUser!.idProfil,
        profilCode: _currentUser!.profilCode,
        profilLibelle: _currentUser!.profilLibelle,
        nom: _currentUser!.nom,
        prenom: _currentUser!.prenom,
        email: _currentUser!.email,
        telephone: _currentUser!.telephone,
        nomUtilisateur: _currentUser!.nomUtilisateur,
        motDePasseHash: nouveauMdp.trim(),
        actif: _currentUser!.actif,
        createdAt: _currentUser!.createdAt,
      );
      notifyListeners();
    }
  }

  @visibleForTesting
  void setCurrentUserForTesting(Utilisateur? user) {
    _currentUser = user;
    notifyListeners();
  }
}
