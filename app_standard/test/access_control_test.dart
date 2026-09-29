import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/main.dart';
import 'package:app_standard/screens/caisse/caisse_screen.dart';
import 'package:app_standard/screens/stats/stats_screen.dart';
import 'package:app_standard/screens/stats/widgets/patron_summary_cards.dart';
import 'package:app_standard/services/auth_service.dart';
import 'package:app_standard/services/stats_service.dart';
import 'package:app_standard/widgets/access_denied_screen.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late AuthService authService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DbHelper.setDatabaseForTesting(db);
    await DbHelper.instance.populateTestDb(db);

    authService = AuthService.instance;
    authService.logout();
  });

  tearDown(() async {
    authService.logout();
    await db.close();
    DbHelper.setDatabaseForTesting(null);
  });

  test('Permissions des profils selon access_controle.md', () async {
    // 1. Profil CAISSIER
    final caissierUser = await authService.login(
      nomUtilisateur: 'caissier',
      motDePasse: 'caissier123',
    );
    expect(caissierUser.isCaissier, isTrue);
    expect(caissierUser.canAccessVente, isTrue);
    expect(caissierUser.canAccessCaisse, isTrue);
    expect(caissierUser.canAccessStock, isFalse);
    expect(caissierUser.canAccessAchat, isFalse);
    expect(caissierUser.canAccessStats, isFalse);
    expect(caissierUser.canFaireTransfertCaisse, isFalse);
    expect(caissierUser.canReglerDettesFournisseurs, isFalse);
    expect(caissierUser.canVoirTableauBordPatron, isFalse);
    expect(caissierUser.canEffectuerCommande, isTrue);
    expect(caissierUser.canGenererFacture, isTrue);
    expect(caissierUser.canValiderLivraison, isTrue);
    expect(caissierUser.canValiderPaiement, isTrue);

    authService.logout();

    // 2. Profil MAGASINIER
    final magasinierUser = await authService.login(
      nomUtilisateur: 'magasinier',
      motDePasse: 'magasinier123',
    );
    expect(magasinierUser.isMagasinier, isTrue);
    expect(magasinierUser.canAccessStock, isTrue);
    expect(magasinierUser.canAccessAchat, isTrue);
    expect(magasinierUser.canAccessVente, isFalse);
    expect(magasinierUser.canAccessCaisse, isFalse);
    expect(magasinierUser.canAccessStats, isFalse);
    expect(magasinierUser.canGererCatalogueProduits, isFalse);
    expect(magasinierUser.canGererMouvementsStock, isTrue);
    expect(magasinierUser.canGererInventaire, isTrue);

    authService.logout();

    // 3. Profil ADMIN (Patron)
    final adminUser = await authService.login(
      nomUtilisateur: 'admin',
      motDePasse: 'admin123',
    );
    expect(adminUser.isAdmin, isTrue);
    expect(adminUser.canAccessVente, isTrue);
    expect(adminUser.canAccessStock, isTrue);
    expect(adminUser.canAccessAchat, isTrue);
    expect(adminUser.canAccessCaisse, isTrue);
    expect(adminUser.canAccessStats, isTrue);
    expect(adminUser.canFaireTransfertCaisse, isTrue);
    expect(adminUser.canGererCatalogueProduits, isTrue);
    expect(adminUser.canReglerDettesFournisseurs, isTrue);
    expect(adminUser.canVoirTableauBordPatron, isTrue);
  });

  test('StatsService: Tableau de bord Patron en 4 cartes (access_controle.md)', () async {
    final statsService = StatsService();
    final patronDashboard = await statsService.getDashboardPatron();

    expect(patronDashboard.caisseJourTotal, isNotNull);
    expect(patronDashboard.caisseJourEspeces, isNotNull);
    expect(patronDashboard.caisseJourMobile, isNotNull);
    expect(patronDashboard.beneficeJourMarge, isNotNull);
    expect(patronDashboard.dettesClientsTotal, isNotNull);
    expect(patronDashboard.alertesStockRupture, isNotNull);
  });

  testWidgets('Restrictions Navigation: Caissier ne voit que Ventes et Caisse', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await authService.login(nomUtilisateur: 'caissier', motDePasse: 'caissier123');
      await tester.pumpWidget(const AchatVenteStockApp(startAuthenticated: false));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Onglets autorisés pour le caissier
    expect(find.text('Ventes'), findsOneWidget);
    expect(find.text('Caisse'), findsOneWidget);

    // Onglets interdits pour le caissier
    expect(find.text('Stocks'), findsNothing);
    expect(find.text('Achats'), findsNothing);
    expect(find.text('Stats'), findsNothing);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('Restrictions Navigation: Magasinier ne voit que Stocks et Achats', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await authService.login(nomUtilisateur: 'magasinier', motDePasse: 'magasinier123');
      await tester.pumpWidget(const AchatVenteStockApp(startAuthenticated: false));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Onglets autorisés pour le magasinier
    expect(find.text('Stocks'), findsOneWidget);
    expect(find.text('Achats'), findsOneWidget);

    // Onglets interdits pour le magasinier
    expect(find.text('Ventes'), findsNothing);
    expect(find.text('Caisse'), findsNothing);
    expect(find.text('Stats'), findsNothing);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('Écran Guard: AccessDeniedScreen affiché si Caissier tente d\'accéder à Stats', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await authService.login(nomUtilisateur: 'caissier', motDePasse: 'caissier123');
      await tester.pumpWidget(
        const MaterialApp(
          home: StatsScreen(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.byType(AccessDeniedScreen), findsOneWidget);
    expect(find.text('Accès Restreint'), findsOneWidget);
    expect(find.textContaining('Statistiques & Analyses'), findsWidgets);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('Écran Guard: AccessDeniedScreen affiché si Magasinier tente d\'accéder à Caisse', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await authService.login(nomUtilisateur: 'magasinier', motDePasse: 'magasinier123');
      await tester.pumpWidget(
        const MaterialApp(
          home: CaisseScreen(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.byType(AccessDeniedScreen), findsOneWidget);
    expect(find.text('Accès Restreint'), findsOneWidget);
    expect(find.textContaining('Caisse & Trésorerie'), findsWidgets);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('Admin: Accès complet et affichage du Tableau de bord Patron (4 cartes)', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await authService.login(nomUtilisateur: 'admin', motDePasse: 'admin123');
      await tester.pumpWidget(const AchatVenteStockApp(startAuthenticated: false));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Tous les 5 onglets sont visibles
    expect(find.text('Ventes'), findsOneWidget);
    expect(find.text('Stocks'), findsOneWidget);
    expect(find.text('Achats'), findsOneWidget);
    expect(find.text('Caisse'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);

    // Clic sur l'onglet Stats
    await tester.runAsync(() async {
      await tester.tap(find.text('Stats'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Le tableau de bord patron en 4 cartes est visible
    expect(find.byType(PatronSummaryCards), findsOneWidget);
    expect(find.text('TABLEAU DE BORD PATRON (4 CARTES CLÉS)'), findsOneWidget);
    expect(find.text('CAISSE DU JOUR'), findsOneWidget);
    expect(find.text('BÉNÉFICE DU JOUR'), findsOneWidget);
    expect(find.text('DETTES CLIENTS'), findsOneWidget);
    expect(find.text('ALERTES STOCK'), findsOneWidget);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 12));
  });
}
