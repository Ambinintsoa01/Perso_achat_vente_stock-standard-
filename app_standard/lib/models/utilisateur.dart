class Utilisateur {
  final int id;
  final int idProfil;
  final String? profilCode;
  final String? profilLibelle;
  final String nom;
  final String? prenom;
  final String? email;
  final String? telephone;
  final String nomUtilisateur;
  final String motDePasseHash;
  final bool actif;
  final String? createdAt;

  const Utilisateur({
    required this.id,
    required this.idProfil,
    this.profilCode,
    this.profilLibelle,
    required this.nom,
    this.prenom,
    this.email,
    this.telephone,
    required this.nomUtilisateur,
    required this.motDePasseHash,
    this.actif = true,
    this.createdAt,
  });

  String get nomComplet {
    if (prenom != null && prenom!.trim().isNotEmpty) {
      return '${prenom!.trim()} ${nom.trim()}';
    }
    return nom.trim();
  }

  String get initiales {
    final p = prenom != null && prenom!.isNotEmpty ? prenom![0].toUpperCase() : '';
    final n = nom.isNotEmpty ? nom[0].toUpperCase() : 'U';
    return '$p$n'.trim();
  }

  bool get isAdmin => profilCode?.toUpperCase() == 'ADMIN';
  bool get isCaissier => profilCode?.toUpperCase() == 'CAISSIER';
  bool get isMagasinier => profilCode?.toUpperCase() == 'MAGASINIER';
  bool get isGerant => profilCode?.toUpperCase() == 'GERANT';

  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      id: map['id'] as int,
      idProfil: map['id_profil'] as int,
      profilCode: map['profil_code'] as String?,
      profilLibelle: map['profil_libelle'] as String?,
      nom: map['nom'] as String,
      prenom: map['prenom'] as String?,
      email: map['email'] as String?,
      telephone: map['telephone'] as String?,
      nomUtilisateur: map['nom_utilisateur'] as String,
      motDePasseHash: map['mot_de_passe_hash'] as String? ?? '',
      actif: (map['actif'] as int? ?? 1) == 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_profil': idProfil,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'nom_utilisateur': nomUtilisateur,
      'mot_de_passe_hash': motDePasseHash,
      'actif': actif ? 1 : 0,
    };
  }
}
