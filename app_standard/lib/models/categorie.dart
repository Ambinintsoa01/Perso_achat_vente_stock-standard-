class Categorie {
  final int id;
  final String code;
  final String nom;
  final String? description;
  final int? idParent;
  final bool actif;
  final int nombreArticles;

  Categorie({
    required this.id,
    required this.code,
    required this.nom,
    this.description,
    this.idParent,
    this.actif = true,
    this.nombreArticles = 0,
  });

  factory Categorie.fromMap(Map<String, dynamic> map) {
    return Categorie(
      id: map['id'] as int,
      code: map['code'] as String,
      nom: map['nom'] as String,
      description: map['description'] as String?,
      idParent: map['id_parent'] as int?,
      actif: (map['actif'] as int? ?? 1) == 1,
      nombreArticles: (map['nombre_articles'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'code': code,
      'nom': nom,
      'description': description,
      'id_parent': idParent,
      'actif': actif ? 1 : 0,
    };
  }
}
