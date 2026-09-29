import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/screens/caisse/caisse_screen.dart';

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

  testWidgets('Sélection de caisse met à jour le montant et le titre en haut', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: CaisseScreen()));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // 1. Initialement : Aucun compte sélectionné -> DISPONIBLE TOTAL
    expect(find.text('DISPONIBLE TOTAL'), findsOneWidget);

    // 2. Sélectionner la carte "Tiroir-Caisse Espèces"
    final caisseEspeceFinder = find.text('Tiroir-Caisse Espèces');
    expect(caisseEspeceFinder, findsWidgets);

    // Cliquer sur la première carte de caisse et attendre le rechargement SQLite
    await tester.runAsync(() async {
      await tester.tap(caisseEspeceFinder.first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // 3. Le montant et le titre en haut doivent refléter le compte sélectionné
    expect(find.text('SOLDE : TIROIR-CAISSE ESPÈCES'), findsOneWidget);
    expect(find.text('Voir global'), findsOneWidget);

    // 4. Cliquer sur "Voir global" pour réinitialiser l'affichage
    await tester.runAsync(() async {
      await tester.tap(find.text('Voir global'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // 5. On doit revenir au DISPONIBLE TOTAL
    expect(find.text('DISPONIBLE TOTAL'), findsOneWidget);
  });
}
