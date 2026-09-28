class Article {
  final int id;
  final String reference;
  final String? codeBarre;
  final String designation;
  final String? description;
  final String? imageUrl;
  final int? idCategorie;
  final String? categorieNom;
  final int? idUnite;
  final String? uniteCode;
  final double prixAchatEstime;
  final double coutMoyenUnitaire;
  final double prixVenteStandard;
  final double tauxTva;
  final double seuilAlerteStock;
  final double quantiteStock; // Quantité physique réelle disponible
  final bool suiviStock;
  final bool actif;

  Article({
    required this.id,
    required this.reference,
    this.codeBarre,
    required this.designation,
    this.description,
    this.imageUrl,
    this.idCategorie,
    this.categorieNom,
    this.idUnite,
    this.uniteCode,
    this.prixAchatEstime = 0.0,
    this.coutMoyenUnitaire = 0.0,
    this.prixVenteStandard = 0.0,
    this.tauxTva = 20.0,
    this.seuilAlerteStock = 5.0,
    this.quantiteStock = 0.0,
    this.suiviStock = true,
    this.actif = true,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as int,
      reference: map['reference'] as String,
      codeBarre: map['code_barre'] as String?,
      designation: map['designation'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      idCategorie: map['id_categorie'] as int?,
      categorieNom: map['categorie_nom'] as String?,
      idUnite: map['id_unite'] as int?,
      uniteCode: map['unite_code'] as String?,
      prixAchatEstime: (map['prix_achat_estime'] as num?)?.toDouble() ?? 0.0,
      coutMoyenUnitaire: (map['cout_moyen_unitaire'] as num?)?.toDouble() ?? 0.0,
      prixVenteStandard: (map['prix_vente_standard'] as num?)?.toDouble() ?? 0.0,
      tauxTva: (map['taux_tva'] as num?)?.toDouble() ?? 20.0,
      seuilAlerteStock: (map['seuil_alerte_stock'] as num?)?.toDouble() ?? 0.0,
      quantiteStock: (map['quantite_reelle'] as num?)?.toDouble() ?? 0.0,
      suiviStock: (map['suivi_stock'] as int? ?? 1) == 1,
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }

  bool get isAlerteStock => suiviStock && quantiteStock <= seuilAlerteStock;
  bool get isRupture => suiviStock && quantiteStock <= 0;

  double get valeurStockAchat => quantiteStock * (coutMoyenUnitaire > 0 ? coutMoyenUnitaire : prixAchatEstime);
  double get valeurStockVente => quantiteStock * prixVenteStandard;
  double get margeUnitaire => prixVenteStandard - (coutMoyenUnitaire > 0 ? coutMoyenUnitaire : prixAchatEstime);
}
