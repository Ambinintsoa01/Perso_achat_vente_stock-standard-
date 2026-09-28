class CommandeAchat {
  final int id;
  final String numeroCommande;
  final int idFournisseur;
  final String? fournisseurNom;
  final int idDepotDestination;
  final int idStatut;
  final String? statutLibelle;
  final String? statutCode;
  final int? idUtilisateur;
  final String dateCommande;
  final String? dateLivraisonPrevue;
  final double montantHt;
  final double montantTva;
  final double montantTtc;
  final String? remarques;
  final int lignesCount;
  final bool estPaye;
  final double montantPaye;
  final double resteAPayer;

  CommandeAchat({
    required this.id,
    required this.numeroCommande,
    required this.idFournisseur,
    this.fournisseurNom,
    this.idDepotDestination = 1,
    required this.idStatut,
    this.statutLibelle,
    this.statutCode,
    this.idUtilisateur,
    required this.dateCommande,
    this.dateLivraisonPrevue,
    required this.montantHt,
    required this.montantTva,
    required this.montantTtc,
    this.remarques,
    this.lignesCount = 0,
    this.estPaye = false,
    this.montantPaye = 0.0,
    this.resteAPayer = 0.0,
  });

  factory CommandeAchat.fromMap(Map<String, dynamic> map) {
    final montantTotal = (map['montant_ttc'] as num?)?.toDouble() ?? 0.0;
    final paye = (map['montant_paye'] as num?)?.toDouble() ?? 0.0;
    final statutNum = map['statut_numero'] as int? ?? 1;

    return CommandeAchat(
      id: map['id'] as int,
      numeroCommande: map['numero_commande'] as String,
      idFournisseur: map['id_fournisseur'] as int,
      fournisseurNom: map['fournisseur_nom'] as String?,
      idDepotDestination: (map['id_depot_destination'] as int?) ?? 1,
      idStatut: map['id_statut'] as int,
      statutLibelle: map['statut_libelle'] as String?,
      statutCode: map['statut_code'] as String?,
      idUtilisateur: map['id_utilisateur'] as int?,
      dateCommande: map['date_commande'] as String? ?? '',
      dateLivraisonPrevue: map['date_livraison_prevue'] as String?,
      montantHt: (map['montant_ht'] as num?)?.toDouble() ?? 0.0,
      montantTva: (map['montant_tva'] as num?)?.toDouble() ?? 0.0,
      montantTtc: montantTotal,
      remarques: map['remarques'] as String?,
      lignesCount: (map['lignes_count'] as int?) ?? 0,
      estPaye: paye >= montantTotal && montantTotal > 0 || statutNum == 41,
      montantPaye: paye,
      resteAPayer: (montantTotal - paye) > 0 ? (montantTotal - paye) : 0.0,
    );
  }
}

class CommandeAchatLigne {
  final int id;
  final int idCommandeAchat;
  final int idArticle;
  final String? articleReference;
  final String? articleDesignation;
  final String? uniteCode;
  final double quantiteCommandee;
  final double quantiteRecue;
  final double prixUnitaireHt;
  final double montantHt;
  final double montantTtc;

  CommandeAchatLigne({
    required this.id,
    required this.idCommandeAchat,
    required this.idArticle,
    this.articleReference,
    this.articleDesignation,
    this.uniteCode,
    required this.quantiteCommandee,
    this.quantiteRecue = 0.0,
    required this.prixUnitaireHt,
    required this.montantHt,
    required this.montantTtc,
  });

  factory CommandeAchatLigne.fromMap(Map<String, dynamic> map) {
    return CommandeAchatLigne(
      id: map['id'] as int,
      idCommandeAchat: map['id_commande_achat'] as int,
      idArticle: map['id_article'] as int,
      articleReference: map['article_reference'] as String?,
      articleDesignation: map['article_designation'] as String?,
      uniteCode: map['unite_code'] as String?,
      quantiteCommandee: (map['quantite_commandee'] as num).toDouble(),
      quantiteRecue: (map['quantite_recue'] as num?)?.toDouble() ?? 0.0,
      prixUnitaireHt: (map['prix_unitaire_ht'] as num).toDouble(),
      montantHt: (map['montant_ht'] as num).toDouble(),
      montantTtc: (map['montant_ttc'] as num).toDouble(),
    );
  }
}
