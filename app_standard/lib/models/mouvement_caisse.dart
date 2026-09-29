class MouvementCaisse {
  final int id;
  final int idCaisse;
  final String? caisseNom;
  final int idTypeMouvement;
  final String? typeCode;
  final String? typeLibelle;
  final int sens; // +1 pour entrée, -1 pour sortie
  final int idModePaiement;
  final String? modePaiementLibelle;
  final int? idUtilisateur;
  final String? utilisateurNom;
  final int? idJournalCaisse;
  final double montant;
  final double soldeAvant;
  final double soldeApres;
  final String dateMouvement;
  final String? referencePiece;
  final String? description;

  MouvementCaisse({
    required this.id,
    required this.idCaisse,
    this.caisseNom,
    required this.idTypeMouvement,
    this.typeCode,
    this.typeLibelle,
    this.sens = 1,
    required this.idModePaiement,
    this.modePaiementLibelle,
    this.idUtilisateur,
    this.utilisateurNom,
    this.idJournalCaisse,
    required this.montant,
    required this.soldeAvant,
    required this.soldeApres,
    required this.dateMouvement,
    this.referencePiece,
    this.description,
  });

  factory MouvementCaisse.fromMap(Map<String, dynamic> map) {
    return MouvementCaisse(
      id: map['id'] as int,
      idCaisse: map['id_caisse'] as int,
      caisseNom: map['caisse_nom'] as String?,
      idTypeMouvement: map['id_type_mouvement'] as int,
      typeCode: map['type_code'] as String?,
      typeLibelle: map['type_libelle'] as String?,
      sens: map['sens'] as int? ?? 1,
      idModePaiement: map['id_mode_paiement'] as int,
      modePaiementLibelle: map['mode_paiement_libelle'] as String?,
      idUtilisateur: map['id_utilisateur'] as int?,
      utilisateurNom: map['utilisateur_nom'] as String?,
      idJournalCaisse: map['id_journal_caisse'] as int?,
      montant: (map['montant'] as num).toDouble(),
      soldeAvant: (map['solde_avant'] as num).toDouble(),
      soldeApres: (map['solde_apres'] as num).toDouble(),
      dateMouvement: map['date_mouvement'] as String? ?? '',
      referencePiece: map['reference_piece'] as String?,
      description: map['description'] as String?,
    );
  }

  bool get isCredit => sens > 0;
}
