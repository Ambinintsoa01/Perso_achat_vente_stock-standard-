class JournalCaisseLigne {
  final int id;
  final int idJournalCaisse;
  final int idCaisse;
  final String? caisseNom;
  final String? caisseCode;
  final String? typeCaisseLibelle;
  final double soldeOuverture;
  final double totalEntrees;
  final double totalSorties;
  final double soldeTheorique;
  final double? soldeReel;
  final double ecart;
  final String? notes;

  JournalCaisseLigne({
    required this.id,
    required this.idJournalCaisse,
    required this.idCaisse,
    this.caisseNom,
    this.caisseCode,
    this.typeCaisseLibelle,
    required this.soldeOuverture,
    this.totalEntrees = 0.0,
    this.totalSorties = 0.0,
    required this.soldeTheorique,
    this.soldeReel,
    this.ecart = 0.0,
    this.notes,
  });

  factory JournalCaisseLigne.fromMap(Map<String, dynamic> map) {
    return JournalCaisseLigne(
      id: map['id'] as int,
      idJournalCaisse: map['id_journal_caisse'] as int,
      idCaisse: map['id_caisse'] as int,
      caisseNom: map['caisse_nom'] as String?,
      caisseCode: map['caisse_code'] as String?,
      typeCaisseLibelle: map['type_caisse_libelle'] as String?,
      soldeOuverture: (map['solde_ouverture'] as num?)?.toDouble() ?? 0.0,
      totalEntrees: (map['total_entrees'] as num?)?.toDouble() ?? 0.0,
      totalSorties: (map['total_sorties'] as num?)?.toDouble() ?? 0.0,
      soldeTheorique: (map['solde_theorique'] as num?)?.toDouble() ?? 0.0,
      soldeReel: map['solde_reel'] != null ? (map['solde_reel'] as num).toDouble() : null,
      ecart: (map['ecart'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'id_journal_caisse': idJournalCaisse,
      'id_caisse': idCaisse,
      'solde_ouverture': soldeOuverture,
      'total_entrees': totalEntrees,
      'total_sorties': totalSorties,
      'solde_theorique': soldeTheorique,
      'solde_reel': soldeReel,
      'ecart': ecart,
      'notes': notes,
    };
  }

  bool get hasEcart => ecart.abs() > 0.01;
}

class JournalCaisse {
  final int id;
  final String numeroJournal;
  final String dateJournal;
  final String dateOuverture;
  final String? dateFermeture;
  final int idUtilisateurOuverture;
  final String? nomUtilisateurOuverture;
  final int? idUtilisateurFermeture;
  final String? nomUtilisateurFermeture;
  final double soldeOuvertureTotal;
  final double totalEntrees;
  final double totalSorties;
  final double soldeTheoriqueTotal;
  final double soldeReelTotal;
  final double ecartTotal;
  final String statut; // 'OUVERT' ou 'CLOTURE'
  final String? notesOuverture;
  final String? notesFermeture;
  final String? createdAt;
  final String? updatedAt;
  final List<JournalCaisseLigne> lignes;

  JournalCaisse({
    required this.id,
    required this.numeroJournal,
    required this.dateJournal,
    required this.dateOuverture,
    this.dateFermeture,
    required this.idUtilisateurOuverture,
    this.nomUtilisateurOuverture,
    this.idUtilisateurFermeture,
    this.nomUtilisateurFermeture,
    required this.soldeOuvertureTotal,
    this.totalEntrees = 0.0,
    this.totalSorties = 0.0,
    required this.soldeTheoriqueTotal,
    this.soldeReelTotal = 0.0,
    this.ecartTotal = 0.0,
    this.statut = 'OUVERT',
    this.notesOuverture,
    this.notesFermeture,
    this.createdAt,
    this.updatedAt,
    this.lignes = const [],
  });

  factory JournalCaisse.fromMap(Map<String, dynamic> map, {List<JournalCaisseLigne> lignes = const []}) {
    return JournalCaisse(
      id: map['id'] as int,
      numeroJournal: map['numero_journal'] as String,
      dateJournal: map['date_journal'] as String,
      dateOuverture: map['date_ouverture'] as String,
      dateFermeture: map['date_fermeture'] as String?,
      idUtilisateurOuverture: map['id_utilisateur_ouverture'] as int,
      nomUtilisateurOuverture: map['nom_utilisateur_ouverture'] as String?,
      idUtilisateurFermeture: map['id_utilisateur_fermeture'] as int?,
      nomUtilisateurFermeture: map['nom_utilisateur_fermeture'] as String?,
      soldeOuvertureTotal: (map['solde_ouverture_total'] as num?)?.toDouble() ?? 0.0,
      totalEntrees: (map['total_entrees'] as num?)?.toDouble() ?? 0.0,
      totalSorties: (map['total_sorties'] as num?)?.toDouble() ?? 0.0,
      soldeTheoriqueTotal: (map['solde_theorique_total'] as num?)?.toDouble() ?? 0.0,
      soldeReelTotal: (map['solde_reel_total'] as num?)?.toDouble() ?? 0.0,
      ecartTotal: (map['ecart_total'] as num?)?.toDouble() ?? 0.0,
      statut: map['statut'] as String? ?? 'OUVERT',
      notesOuverture: map['notes_ouverture'] as String?,
      notesFermeture: map['notes_fermeture'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
      lignes: lignes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id > 0) 'id': id,
      'numero_journal': numeroJournal,
      'date_journal': dateJournal,
      'date_ouverture': dateOuverture,
      'date_fermeture': dateFermeture,
      'id_utilisateur_ouverture': idUtilisateurOuverture,
      'id_utilisateur_fermeture': idUtilisateurFermeture,
      'solde_ouverture_total': soldeOuvertureTotal,
      'total_entrees': totalEntrees,
      'total_sorties': totalSorties,
      'solde_theorique_total': soldeTheoriqueTotal,
      'solde_reel_total': soldeReelTotal,
      'ecart_total': ecartTotal,
      'statut': statut,
      'notes_ouverture': notesOuverture,
      'notes_fermeture': notesFermeture,
    };
  }

  bool get isOuvert => statut == 'OUVERT';
  bool get isCloture => statut == 'CLOTURE';
  bool get hasEcart => ecartTotal.abs() > 0.01;

  JournalCaisse copyWith({
    List<JournalCaisseLigne>? lignes,
    String? statut,
    double? totalEntrees,
    double? totalSorties,
    double? soldeTheoriqueTotal,
    double? soldeReelTotal,
    double? ecartTotal,
    String? dateFermeture,
    int? idUtilisateurFermeture,
    String? nomUtilisateurFermeture,
    String? notesFermeture,
  }) {
    return JournalCaisse(
      id: id,
      numeroJournal: numeroJournal,
      dateJournal: dateJournal,
      dateOuverture: dateOuverture,
      dateFermeture: dateFermeture ?? this.dateFermeture,
      idUtilisateurOuverture: idUtilisateurOuverture,
      nomUtilisateurOuverture: nomUtilisateurOuverture,
      idUtilisateurFermeture: idUtilisateurFermeture ?? this.idUtilisateurFermeture,
      nomUtilisateurFermeture: nomUtilisateurFermeture ?? this.nomUtilisateurFermeture,
      soldeOuvertureTotal: soldeOuvertureTotal,
      totalEntrees: totalEntrees ?? this.totalEntrees,
      totalSorties: totalSorties ?? this.totalSorties,
      soldeTheoriqueTotal: soldeTheoriqueTotal ?? this.soldeTheoriqueTotal,
      soldeReelTotal: soldeReelTotal ?? this.soldeReelTotal,
      ecartTotal: ecartTotal ?? this.ecartTotal,
      statut: statut ?? this.statut,
      notesOuverture: notesOuverture,
      notesFermeture: notesFermeture ?? this.notesFermeture,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lignes: lignes ?? this.lignes,
    );
  }
}
