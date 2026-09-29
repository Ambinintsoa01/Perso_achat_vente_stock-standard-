class MouvementStock {
  final int id;
  final int idDepot;
  final String? depotNom;
  final int idArticle;
  final String? articleReference;
  final String? articleDesignation;
  final String? uniteCode;
  final int idTypeMouvement;
  final String? typeCode;
  final String? typeLibelle;
  final int sens; // +1: Entrée, -1: Sortie
  final int? idUtilisateur;
  final String? utilisateurNom;
  final double quantite;
  final double prixUnitaire;
  final double stockAvant;
  final double stockApres;
  final String? referenceDocument;
  final String dateMouvement;
  final String? remarque;

  MouvementStock({
    required this.id,
    required this.idDepot,
    this.depotNom,
    required this.idArticle,
    this.articleReference,
    this.articleDesignation,
    this.uniteCode,
    required this.idTypeMouvement,
    this.typeCode,
    this.typeLibelle,
    this.sens = 1,
    this.idUtilisateur,
    this.utilisateurNom,
    required this.quantite,
    this.prixUnitaire = 0.0,
    required this.stockAvant,
    required this.stockApres,
    this.referenceDocument,
    required this.dateMouvement,
    this.remarque,
  });

  bool get isEntree => sens == 1;
  bool get isSortie => sens == -1;

  factory MouvementStock.fromMap(Map<String, dynamic> map) {
    return MouvementStock(
      id: map['id'] as int,
      idDepot: map['id_depot'] as int,
      depotNom: map['depot_nom'] as String?,
      idArticle: map['id_article'] as int,
      articleReference: map['article_reference'] as String?,
      articleDesignation: map['article_designation'] as String?,
      uniteCode: map['unite_code'] as String?,
      idTypeMouvement: map['id_type_mouvement'] as int,
      typeCode: map['type_code'] as String?,
      typeLibelle: map['type_libelle'] as String?,
      sens: map['sens'] as int? ?? 1,
      idUtilisateur: map['id_utilisateur'] as int?,
      utilisateurNom: map['utilisateur_nom'] as String?,
      quantite: (map['quantite'] as num).toDouble(),
      prixUnitaire: (map['prix_unitaire'] as num?)?.toDouble() ?? 0.0,
      stockAvant: (map['stock_avant'] as num).toDouble(),
      stockApres: (map['stock_apres'] as num).toDouble(),
      referenceDocument: map['reference_document'] as String?,
      dateMouvement: map['date_mouvement'] as String? ?? '',
      remarque: map['remarque'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'id_depot': idDepot,
      'id_article': idArticle,
      'id_type_mouvement': idTypeMouvement,
      'id_utilisateur': idUtilisateur,
      'quantite': quantite,
      'prix_unitaire': prixUnitaire,
      'stock_avant': stockAvant,
      'stock_apres': stockApres,
      'reference_document': referenceDocument,
      'date_mouvement': dateMouvement,
      'remarque': remarque,
    };
  }
}
