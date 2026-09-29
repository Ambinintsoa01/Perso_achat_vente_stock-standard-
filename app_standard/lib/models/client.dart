class Client {
  final int id;
  final String code;
  final String nomComplet;
  final int idTypeClient;
  final String? telephone;
  final String? email;
  final String? adresse;
  final String? ville;
  final String? nif;
  final String? stat;
  final double soldeCreditMax;
  final bool actif;

  Client({
    required this.id,
    required this.code,
    required this.nomComplet,
    this.idTypeClient = 1,
    this.telephone,
    this.email,
    this.adresse,
    this.ville,
    this.nif,
    this.stat,
    this.soldeCreditMax = 0.0,
    this.actif = true,
  });

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int,
      code: map['code'] as String,
      nomComplet: map['nom_complet'] as String,
      idTypeClient: (map['id_type_client'] as int?) ?? 1,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      adresse: map['adresse'] as String?,
      ville: map['ville'] as String?,
      nif: map['nif'] as String?,
      stat: map['stat'] as String?,
      soldeCreditMax: (map['solde_credit_max'] as num?)?.toDouble() ?? 0.0,
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'code': code,
      'nom_complet': nomComplet,
      'id_type_client': idTypeClient,
      'telephone': telephone,
      'email': email,
      'adresse': adresse,
      'ville': ville,
      'nif': nif,
      'stat': stat,
      'solde_credit_max': soldeCreditMax,
      'actif': actif ? 1 : 0,
    };
  }
}
