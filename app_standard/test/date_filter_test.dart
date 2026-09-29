import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/services/achat_service.dart';
import 'package:app_standard/services/caisse_service.dart';
import 'package:app_standard/services/stock_service.dart';
import 'package:app_standard/widgets/date_filter_bar.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DateFilterBar Widget Tests', () {
    testWidgets('Rendu des boutons raccourcis et interaction Aujourd\'hui', (WidgetTester tester) async {
      DateTime? receivedStart;
      DateTime? receivedEnd;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateFilterBar(
              onDateRangeChanged: (start, end) {
                receivedStart = start;
                receivedEnd = end;
              },
            ),
          ),
        ),
      );

      // Vérifie la présence des raccourcis
      expect(find.text('Toutes dates'), findsOneWidget);
      expect(find.text('Aujourd\'hui'), findsOneWidget);
      expect(find.text('7 jours'), findsOneWidget);
      expect(find.text('Ce mois'), findsOneWidget);
      expect(find.text('Période'), findsOneWidget);

      // Cliquer sur "Aujourd'hui"
      await tester.tap(find.text('Aujourd\'hui'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final expectedToday = DateTime(now.year, now.month, now.day);
      expect(receivedStart, equals(expectedToday));
      expect(receivedEnd, equals(expectedToday));

      // Vérifier que le badge de période active apparaît
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

      // Cliquer sur le bouton de réinitialisation (icône croix)
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pumpAndSettle();

      expect(receivedStart, isNull);
      expect(receivedEnd, isNull);
    });

    testWidgets('Sélection 7 jours et Ce mois', (WidgetTester tester) async {
      DateTime? receivedStart;
      DateTime? receivedEnd;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateFilterBar(
              onDateRangeChanged: (start, end) {
                receivedStart = start;
                receivedEnd = end;
              },
            ),
          ),
        ),
      );

      // Cliquer sur "7 jours"
      await tester.tap(find.text('7 jours'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final expected7Days = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      expect(receivedStart, equals(expected7Days));

      // Cliquer sur "Ce mois"
      await tester.tap(find.text('Ce mois'));
      await tester.pumpAndSettle();

      final expectedMonthStart = DateTime(now.year, now.month, 1);
      expect(receivedStart, equals(expectedMonthStart));
      expect(receivedEnd, isNotNull);
    });
  });

  group('Service Date Filtering Integration Tests', () {
    late Database db;
    late AchatService achatService;
    late CaisseService caisseService;
    late StockService stockService;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      DbHelper.setDatabaseForTesting(db);
      await DbHelper.instance.populateTestDb(db);

      achatService = AchatService();
      caisseService = CaisseService();
      stockService = StockService();
    });

    tearDown(() async {
      await db.close();
      DbHelper.setDatabaseForTesting(null);
    });

    test('CaisseService: filtrage par date', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pastDate1 = DateTime(2020, 1, 1);
      final pastDate2 = DateTime(2020, 1, 2);

      // Enregistrer une opération aujourd'hui
      await caisseService.enregistrerMouvement(
        idCaisse: 1,
        idTypeMouvement: 1, // ENCAISSEMENT
        montant: 50000.0,
        description: 'Versement de test',
        idModePaiement: 1,
      );

      // 1. Filtrer pour aujourd'hui -> doit trouver le mouvement
      final mouvementsToday = await caisseService.getMouvements(
        dateDebut: today,
        dateFin: today,
      );
      expect(mouvementsToday.any((m) => m.description == 'Versement de test'), isTrue);

      // 2. Filtrer pour une période passée sans opérations -> doit être vide
      final mouvementsPast = await caisseService.getMouvements(
        dateDebut: pastDate1,
        dateFin: pastDate2,
      );
      expect(mouvementsPast.isEmpty, isTrue);
    });

    test('StockService: filtrage par date des mouvements de stock', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pastDate1 = DateTime(2020, 1, 1);
      final pastDate2 = DateTime(2020, 1, 2);

      final catId = await stockService.ajouterCategorie(code: 'TEST', nom: 'Catégorie Test');
      await stockService.ajouterArticle(
        reference: 'ART-FILTRE',
        designation: 'Article Pour Filtre',
        idCategorie: catId,
        prixAchat: 1000.0,
        prixVente: 1500.0,
        stockInitial: 50.0,
      );

      // 1. Filtrer pour aujourd'hui -> mouvements de stock trouvés (stock initial créé aujourd'hui)
      final mvtsToday = await stockService.getMouvementsStock(
        dateDebut: today,
        dateFin: today,
      );
      expect(mvtsToday.any((m) => m.articleReference == 'ART-FILTRE'), isTrue);

      // 2. Filtrer pour une période passée -> aucun mouvement
      final mvtsPast = await stockService.getMouvementsStock(
        dateDebut: pastDate1,
        dateFin: pastDate2,
      );
      expect(mvtsPast.isEmpty, isTrue);
    });

    test('AchatService: filtrage par date des commandes d\'achat', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final pastDate1 = DateTime(2020, 1, 1);
      final pastDate2 = DateTime(2020, 1, 2);

      final catId = await stockService.ajouterCategorie(code: 'ACH', nom: 'Achat Cat');
      final articleId = await stockService.ajouterArticle(
        reference: 'ART-ACHAT',
        designation: 'Produit Achat',
        idCategorie: catId,
        prixAchat: 2000.0,
        prixVente: 2500.0,
        stockInitial: 10.0,
      );

      // Créer une commande d'achat aujourd'hui
      await achatService.enregistrerAchat(
        idFournisseur: 1,
        articlesAchetes: [
          LigneAchatInput(
            idArticle: articleId,
            designation: 'Produit Achat',
            quantite: 5,
            prixUnitaire: 2000.0,
          ),
        ],
        payeImmediatement: false,
      );

      // 1. Filtrer pour aujourd'hui -> commande trouvée
      final cmdsToday = await achatService.getCommandesAchat(
        dateDebut: today,
        dateFin: today,
      );
      expect(cmdsToday.isNotEmpty, isTrue);

      // 2. Filtrer pour une date passée -> aucun résultat
      final cmdsPast = await achatService.getCommandesAchat(
        dateDebut: pastDate1,
        dateFin: pastDate2,
      );
      expect(cmdsPast.isEmpty, isTrue);
    });
  });
}
