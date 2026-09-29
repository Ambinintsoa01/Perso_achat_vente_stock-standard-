import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_standard/models/caisse.dart';
import 'package:app_standard/models/mode_paiement.dart';
import 'package:app_standard/screens/caisse/widgets/nouveau_mouvement_dialog.dart';

void main() {
  testWidgets('NouveauMouvementDialog renders without overflow on a small viewport', (WidgetTester tester) async {
    // Émuler un petit écran mobile (360x580) comme celui de la capture utilisateur
    tester.view.physicalSize = const Size(360, 580);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testCaisses = [
      Caisse(
        id: 1,
        code: 'CSH-01',
        nom: 'Tiroir-Caisse Espèces',
        idTypeCaisse: 1,
        soldeInitial: 250000.0,
        soldeActuel: 250000.0,
        idDevise: 1,
      ),
    ];

    final testModes = [
      ModePaiement(id: 1, numero: 1, code: 'CASH', libelle: 'Espèces / Cash'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => NouveauMouvementDialog(
                      caisses: testCaisses,
                      modesPaiement: testModes,
                      onSuccess: () {},
                    ),
                  );
                },
                child: const Text('Ouvrir'),
              );
            },
          ),
        ),
      ),
    );

    // Ouvrir le dialog
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // Vérifier que le titre est visible
    expect(find.text('Opération de Caisse'), findsOneWidget);

    // Vérifier que le texte de la caisse avec son solde formaté est présent sans overflow
    expect(find.textContaining('Tiroir-Caisse Espèces'), findsOneWidget);

    // Vérifier que le bouton de validation est présent
    expect(find.text('Valider l\'Encaissement'), findsOneWidget);

    // Vérifier qu'on peut défiler si nécessaire
    final scrollFinder = find.byType(Scrollable);
    expect(scrollFinder, findsWidgets);

    // Vérifier qu'aucune exception d'overflow Flutter n'a été levée
    expect(tester.takeException(), isNull);
  });
}
