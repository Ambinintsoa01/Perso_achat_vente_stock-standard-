class CommandeVente {
  final int id;
  final String numeroCommande;
  final int idClient;
  final String? clientNom;
  final int idDepotSource;
  final int idStatut;
  final String? statutLibelle;
  final String? statutCode;
  final int? idUtilisateur;
  final String dateCommande;
  final String? dateLivraisonSouhaitee;
  final double montantHt;
  final double montantTva;
  final double montantTtc;
  final double margeBrute;
  final String? notes;
  final int lignesCount;
  final bool estPaye;
  final double montantPaye;
  final double resteAPayer;
  final int? idFacture;
  final String? numeroFacture;

  CommandeVente({
    required this.id,
    required this.numeroCommande,
    required this.idClient,
    this.clientNom,
    this.idDepotSource = 1,
    required this.idStatut,
    this.statutLibelle,
    this.statutCode,
    this.idUtilisateur,
    required this.dateCommande,
    this.dateLivraisonSouhaitee,
    required this.montantHt,
    required this.montantTva,
    required this.montantTtc,
    this.margeBrute = 0.0,
    this.notes,
    this.lignesCount = 0,
    this.estPaye = false,
    this.montantPaye = 0.0,
    this.resteAPayer = 0.0,
    this.idFacture,
    this.numeroFacture,
  });

  factory CommandeVente.fromMap(Map<String, dynamic> map) {
    final montantTotal = (map['montant_ttc'] as num?)?.toDouble() ?? 0.0;
    final paye = (map['montant_paye'] as num?)?.toDouble() ?? 0.0;
    final statutNum = map['statut_numero'] as int? ?? 1;

    return CommandeVente(
      id: map['id'] as int,
      numeroCommande: map['numero_commande'] as String,
      idClient: map['id_client'] as int,
      clientNom: map['client_nom'] as String?,
      idDepotSource: (map['id_depot_source'] as int?) ?? 1,
      idStatut: map['id_statut'] as int,
      statutLibelle: map['statut_libelle'] as String?,
      statutCode: map['statut_code'] as String?,
      idUtilisateur: map['id_utilisateur'] as int?,
      dateCommande: map['date_commande'] as String? ?? '',
      dateLivraisonSouhaitee: map['date_livraison_souhaitee'] as String?,
      montantHt: (map['montant_ht'] as num?)?.toDouble() ?? 0.0,
      montantTva: (map['montant_tva'] as num?)?.toDouble() ?? 0.0,
      montantTtc: montantTotal,
      margeBrute: (map['marge_brute'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      lignesCount: (map['lignes_count'] as int?) ?? 0,
      estPaye: paye >= montantTotal && montantTotal > 0 || statutNum == 41,
      montantPaye: paye,
      resteAPayer: (montantTotal - paye) > 0 ? (montantTotal - paye) : 0.0,
      idFacture: map['id_facture'] as int?,
      numeroFacture: map['numero_facture'] as String?,
    );
  }
}

class CommandeVenteLigne {
  final int id;
  final int idCommandeVente;
  final int idArticle;
  final String? articleReference;
  final String? articleDesignation;
  final String? uniteCode;
  final double quantite;
  final double prixUnitaire;
  final double tauxRemise;
  final double montantHt;
  final double montantTtc;

  CommandeVenteLigne({
    required this.id,
    required this.idCommandeVente,
    required this.idArticle,
    this.articleReference,
    this.articleDesignation,
    this.uniteCode,
    required this.quantite,
    required this.prixUnitaire,
    this.tauxRemise = 0.0,
    required this.montantHt,
    required this.montantTtc,
  });

  factory CommandeVenteLigne.fromMap(Map<String, dynamic> map) {
    return CommandeVenteLigne(
      id: map['id'] as int,
      idCommandeVente: map['id_commande_vente'] as int,
      idArticle: map['id_article'] as int,
      articleReference: map['article_reference'] as String?,
      articleDesignation: map['article_designation'] as String?,
      uniteCode: map['unite_code'] as String?,
      quantite: (map['quantite'] as num).toDouble(),
      prixUnitaire: (map['prix_unitaire'] as num).toDouble(),
      tauxRemise: (map['taux_remise'] as num?)?.toDouble() ?? 0.0,
      montantHt: (map['montant_ht'] as num).toDouble(),
      montantTtc: (map['montant_ttc'] as num).toDouble(),
    );
  }
}
