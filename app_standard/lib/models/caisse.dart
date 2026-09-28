class Caisse {
  final int id;
  final String code;
  final String nom;
  final int idTypeCaisse;
  final String? typeCode;
  final String? typeLibelle;
  final String? numeroCompte;
  final double soldeInitial;
  final double soldeActuel;
  final int idDevise;
  final String deviseCode;
  final String deviseSymbole;
  final bool actif;

  Caisse({
    required this.id,
    required this.code,
    required this.nom,
    required this.idTypeCaisse,
    this.typeCode,
    this.typeLibelle,
    this.numeroCompte,
    required this.soldeInitial,
    required this.soldeActuel,
    required this.idDevise,
    this.deviseCode = 'MGA',
    this.deviseSymbole = 'Ar',
    this.actif = true,
  });

  factory Caisse.fromMap(Map<String, dynamic> map) {
    return Caisse(
      id: map['id'] as int,
      code: map['code'] as String,
      nom: map['nom'] as String,
      idTypeCaisse: map['id_type_caisse'] as int,
      typeCode: map['type_code'] as String?,
      typeLibelle: map['type_libelle'] as String?,
      numeroCompte: map['numero_compte'] as String?,
      soldeInitial: (map['solde_initial'] as num?)?.toDouble() ?? 0.0,
      soldeActuel: (map['solde_actuel'] as num?)?.toDouble() ?? 0.0,
      idDevise: map['id_devise'] as int,
      deviseCode: map['devise_code'] as String? ?? 'MGA',
      deviseSymbole: map['devise_symbole'] as String? ?? 'Ar',
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'code': code,
      'nom': nom,
      'id_type_caisse': idTypeCaisse,
      'numero_compte': numeroCompte,
      'solde_initial': soldeInitial,
      'solde_actuel': soldeActuel,
      'id_devise': idDevise,
      'actif': actif ? 1 : 0,
    };
  }
}
