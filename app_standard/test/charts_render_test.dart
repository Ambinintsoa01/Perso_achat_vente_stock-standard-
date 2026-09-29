import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_standard/screens/stats/widgets/vente_evolution_chart.dart';
import 'package:app_standard/screens/stats/widgets/depenses_visualisation_chart.dart';
import 'package:app_standard/models/stats_data.dart';
import 'package:intl/intl.dart';

void main() {
  testWidgets('Test VenteEvolutionChart and DepensesVisualisationChart render cleanly with data', (WidgetTester tester) async {
    final venteData = [
      const VenteEvolutionPoint(date: '2026-09-29', montant: 50000, quantite: 5, nombreCommandes: 1),
      const VenteEvolutionPoint(date: '2026-09-30', montant: 80000, quantite: 8, nombreCommandes: 2),
    ];

    final depenseData = [
      const DepenseEvolutionPoint(date: '2026-09-29', montantAchats: 40000, montantDepensesDiverses: 10000),
      const DepenseEvolutionPoint(date: '2026-09-30', montantAchats: 20000, montantDepensesDiverses: 5000),
    ];

    final repartition = [
      const DepenseRepartitionItem(typeCode: 'DECAISSEMENT_ACHAT', libelle: 'Achats Fournisseurs', montant: 60000, pourcentage: 80),
      const DepenseRepartitionItem(typeCode: 'DEPENSE_DIVERSE', libelle: 'Dépenses Diverses', montant: 15000, pourcentage: 20),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              VenteEvolutionChart(
                data: venteData,
                categories: const [],
                articles: const [],
                onCategorieChanged: (_) {},
                onArticleChanged: (_) {},
                currencyFormatter: NumberFormat.currency(symbol: 'Ar'),
              ),
              DepensesVisualisationChart(
                evolutionData: depenseData,
                repartitionData: repartition,
                currencyFormatter: NumberFormat.currency(symbol: 'Ar'),
              ),
            ],
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('ÉVOLUTION DES VENTES'), findsOneWidget);
    expect(find.text('VISUALISATION DES DÉPENSES'), findsOneWidget);
  });
}
