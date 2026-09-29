class Profil {
  final int id;
  final int numero;
  final String code;
  final String libelle;
  final String? description;
  final bool actif;

  const Profil({
    required this.id,
    required this.numero,
    required this.code,
    required this.libelle,
    this.description,
    this.actif = true,
  });

  bool get isAdmin => code.toUpperCase() == 'ADMIN';
  bool get isCaissier => code.toUpperCase() == 'CAISSIER';
  bool get isMagasinier => code.toUpperCase() == 'MAGASINIER';
  bool get isGerant => code.toUpperCase() == 'GERANT';

  // Accès aux modules principaux (access_controle.md)
  bool get canAccessVente => isAdmin || isGerant || isCaissier;
  bool get canAccessStock => isAdmin || isGerant || isMagasinier;
  bool get canAccessAchat => isAdmin || isGerant || isMagasinier;
  bool get canAccessCaisse => isAdmin || isGerant || isCaissier;
  bool get canAccessStats => isAdmin || isGerant;

  // Actions spécifiques au sein des modules (access_controle.md)
  bool get canFaireTransfertCaisse => isAdmin || isGerant;
  bool get canGererCatalogueProduits => isAdmin || isGerant;
  bool get canReglerDettesFournisseurs => isAdmin || isGerant;
  bool get canVoirTableauBordPatron => isAdmin || isGerant;
  bool get canEffectuerCommande => isAdmin || isGerant || isCaissier;
  bool get canGenererFacture => isAdmin || isGerant || isCaissier;
  bool get canValiderLivraison => isAdmin || isGerant || isCaissier;
  bool get canValiderPaiement => isAdmin || isGerant || isCaissier;
  bool get canGererMouvementsStock => isAdmin || isGerant || isMagasinier;
  bool get canGererInventaire => isAdmin || isGerant || isMagasinier;
  // Actions de synchronisation Cloud Supabase
  bool get canSyncPush => true; // Tous les profils peuvent envoyer leurs données
  bool get canSyncPull => !isCaissier; // Le caissier ne peut que push (pas de téléchargement)
  bool get canSyncBidirectional => !isCaissier;

  factory Profil.fromMap(Map<String, dynamic> map) {
    return Profil(
      id: map['id'] as int,
      numero: map['numero'] as int? ?? 1,
      code: map['code'] as String,
      libelle: map['libelle'] as String,
      description: map['description'] as String?,
      actif: (map['actif'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'code': code,
      'libelle': libelle,
      'description': description,
      'actif': actif ? 1 : 0,
    };
  }
}
