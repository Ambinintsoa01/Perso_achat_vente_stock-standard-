class StatsKpiSummary {
  final double valeurStockActuel;
  final double valeurTotaleEntrees;
  final double valeurTotaleSorties;
  final double totalEncaissements;
  final double totalDecaissements;
  final double totalAchats;
  final double totalDepensesDiverses;
  final double totalVentes;
  final int totalArticles;
  final double totalQuantiteEnStock;

  const StatsKpiSummary({
    required this.valeurStockActuel,
    required this.valeurTotaleEntrees,
    required this.valeurTotaleSorties,
    required this.totalEncaissements,
    required this.totalDecaissements,
    required this.totalAchats,
    required this.totalDepensesDiverses,
    required this.totalVentes,
    required this.totalArticles,
    required this.totalQuantiteEnStock,
  });

  double get totalDepenses => totalAchats + totalDepensesDiverses;
  double get soldeFluxTresorerie => totalEncaissements - totalDecaissements;
}

class VenteEvolutionPoint {
  final String date;
  final double montant;
  final double quantite;
  final int nombreCommandes;

  const VenteEvolutionPoint({
    required this.date,
    required this.montant,
    required this.quantite,
    required this.nombreCommandes,
  });

  factory VenteEvolutionPoint.fromMap(Map<String, dynamic> map) {
    return VenteEvolutionPoint(
      date: map['date_jour'] as String? ?? '',
      montant: (map['total_montant'] as num?)?.toDouble() ?? 0.0,
      quantite: (map['total_quantite'] as num?)?.toDouble() ?? 0.0,
      nombreCommandes: (map['nb_commandes'] as num?)?.toInt() ?? 0,
    );
  }
}

class DepenseEvolutionPoint {
  final String date;
  final double montantAchats;
  final double montantDepensesDiverses;

  const DepenseEvolutionPoint({
    required this.date,
    required this.montantAchats,
    required this.montantDepensesDiverses,
  });

  double get total => montantAchats + montantDepensesDiverses;
}

class DepenseRepartitionItem {
  final String typeCode;
  final String libelle;
  final double montant;
  final double pourcentage;

  const DepenseRepartitionItem({
    required this.typeCode,
    required this.libelle,
    required this.montant,
    required this.pourcentage,
  });
}

class DashboardPatronSummary {
  final double caisseJourTotal;
  final double caisseJourEspeces;
  final double caisseJourMobile;
  final double beneficeJourMarge;
  final double ventesJourTotal;
  final double dettesClientsTotal;
  final int nbClientsEnRetard;
  final int alertesStockRupture;

  const DashboardPatronSummary({
    required this.caisseJourTotal,
    required this.caisseJourEspeces,
    required this.caisseJourMobile,
    required this.beneficeJourMarge,
    required this.ventesJourTotal,
    required this.dettesClientsTotal,
    required this.nbClientsEnRetard,
    required this.alertesStockRupture,
  });
}
