class Profil {
  final int id;
  final int numero;
  final String code;
  final String libelle;
  final String? description;
  final bool actif;

  const Profil({
    required this.id,
    required this.numero,
    required this.code,
    required this.libelle,
    this.description,
    this.actif = true,
  });

  bool get isAdmin => code.toUpperCase() == 'ADMIN';
  bool get isCaissier => code.toUpperCase() == 'CAISSIER';
  bool get isMagasinier => code.toUpperCase() == 'MAGASINIER';
  bool get isGerant => code.toUpperCase() == 'GERANT';

  // Permissions de base selon le rôle
  bool get canAccessStats => isAdmin || isGerant;
  bool get canAccessAchat => isAdmin || isGerant || isMagasinier;
  bool get canAccessStock => isAdmin || isGerant || isMagasinier || isCaissier;
  bool get canAccessVente => isAdmin || isGerant || isCaissier;
  bool get canAccessCaisse => isAdmin || isGerant || isCaissier;

  factory Profil.fromMap(Map<String, dynamic> map) {
    return Profil(
      id: map['id'] as int,
      numero: map['numero'] as int? ?? 1,
      code: map['code'] as String,
      libelle: map['libelle'] as String,
      description: map['description'] as String?,
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'code': code,
      'libelle': libelle,
      'description': description,
      'actif': actif ? 1 : 0,
    };
  }
}
