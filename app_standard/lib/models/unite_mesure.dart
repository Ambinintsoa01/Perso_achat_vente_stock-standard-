class UniteMesure {
  final int id;
  final String code;
  final String nom;
  final bool actif;

  UniteMesure({
    required this.id,
    required this.code,
    required this.nom,
    this.actif = true,
  });

  factory UniteMesure.fromMap(Map<String, dynamic> map) {
    return UniteMesure(
      id: map['id'] as int,
      code: map['code'] as String,
      nom: map['nom'] as String,
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }
}
