class Fournisseur {
  final int id;
  final String code;
  final String raisonSociale;
  final String? nomContact;
  final String? telephone;
  final String? email;
  final int delaiPaiementJours;
  final bool actif;

  Fournisseur({
    required this.id,
    required this.code,
    required this.raisonSociale,
    this.nomContact,
    this.telephone,
    this.email,
    this.delaiPaiementJours = 30,
    this.actif = true,
  });

  factory Fournisseur.fromMap(Map<String, dynamic> map) {
    return Fournisseur(
      id: map['id'] as int,
      code: map['code'] as String,
      raisonSociale: map['raison_sociale'] as String,
      nomContact: map['nom_contact'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      delaiPaiementJours: (map['delai_paiement_jours'] as int?) ?? 30,
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'code': code,
      'raison_sociale': raisonSociale,
      'nom_contact': nomContact,
      'telephone': telephone,
      'email': email,
      'delai_paiement_jours': delaiPaiementJours,
      'actif': actif ? 1 : 0,
    };
  }
}
