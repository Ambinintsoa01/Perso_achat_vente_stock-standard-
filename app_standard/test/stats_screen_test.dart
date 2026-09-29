import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/main.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DbHelper.setDatabaseForTesting(db);
    await DbHelper.instance.populateTestDb(db);
  });

  tearDown(() async {
    await db.close();
    DbHelper.setDatabaseForTesting(null);
  });

  testWidgets('Navigation vers Stats et affichage des indicateurs et graphiques requis', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const AchatVenteStockApp(startAuthenticated: true));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // 1. Vérifier la présence de l'onglet Stats dans la barre de navigation
    final statsTabFinder = find.text('Stats');
    expect(statsTabFinder, findsOneWidget);

    // 2. Cliquer sur l'onglet Stats
    await tester.runAsync(() async {
      await tester.tap(statsTabFinder);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // 3. Vérifier le titre de l'écran Stats
    expect(find.text('STATISTIQUES & ANALYSES'), findsOneWidget);

    // 4. Vérifier les 3 indicateurs clés demandés
    // - Valeur de stock
    expect(find.text('VALEUR TOTALE DE STOCK (CUMP)'), findsOneWidget);
    // - Valeur total d'entrée
    expect(find.text('TOTAL ENTRÉES'), findsOneWidget);
    // - Valeur totale de sortie
    expect(find.text('TOTAL SORTIES'), findsOneWidget);

    // 5. Vérifier le graphe d'évolution des ventes et ses filtres
    expect(find.text('ÉVOLUTION DES VENTES'), findsOneWidget);
    expect(find.text('Catégorie'), findsOneWidget);
    expect(find.text('Produit'), findsOneWidget);

    // 6. Vérifier le graphe de visualisation des dépenses (achats + décaissements divers)
    expect(find.text('VISUALISATION DES DÉPENSES'), findsOneWidget);
    expect(find.text('Achats + Décaissements'), findsOneWidget);

    // 7. Vérifier la présence du filtre de date obligatoire
    expect(find.text('Ce mois'), findsOneWidget);
  });
}
