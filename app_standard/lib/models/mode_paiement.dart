class ModePaiement {
  final int id;
  final int numero;
  final String code;
  final String libelle;
  final bool actif;

  ModePaiement({
    required this.id,
    required this.numero,
    required this.code,
    required this.libelle,
    this.actif = true,
  });

  factory ModePaiement.fromMap(Map<String, dynamic> map) {
    return ModePaiement(
      id: map['id'] as int,
      numero: map['numero'] as int,
      code: map['code'] as String,
      libelle: map['libelle'] as String,
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }
}
