import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/main.dart';
import 'package:app_standard/services/auth_service.dart';
import 'package:app_standard/widgets/user_avatar_button.dart';

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

  test('AuthService: profils SQL et connexion par profil', () async {
    // 1. Vérification des profils SQL dans la base
    final profils = await authService.getProfils();
    expect(profils.isNotEmpty, isTrue);
    expect(profils.any((p) => p.code == 'ADMIN'), isTrue);
    expect(profils.any((p) => p.code == 'CAISSIER'), isTrue);

    // 2. Connexion réussie avec compte admin
    final adminUser = await authService.login(
      nomUtilisateur: 'admin',
      motDePasse: 'admin123',
    );
    expect(adminUser.nomUtilisateur, equals('admin'));
    expect(adminUser.isAdmin, isTrue);
    expect(authService.isAuthenticated, isTrue);

    // 3. Déconnexion
    authService.logout();
    expect(authService.isAuthenticated, isFalse);
    expect(authService.currentUser, isNull);

    // 4. Échec avec mot de passe incorrect
    expect(
      () async => await authService.login(
        nomUtilisateur: 'admin',
        motDePasse: 'mauvais_mdp',
      ),
      throwsA(isA<Exception>()),
    );

    // 5. Échec avec utilisateur inexistant
    expect(
      () async => await authService.login(
        nomUtilisateur: 'inconnu',
        motDePasse: '123456',
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('AuthService: création d\'utilisateur et changement de mot de passe', () async {
    final profils = await authService.getProfils();
    final profilCaissier = profils.firstWhere((p) => p.code == 'CAISSIER');

    // 1. Créer un nouvel utilisateur
    final idNouveau = await authService.creerUtilisateur(
      idProfil: profilCaissier.id,
      nom: 'Rabe',
      prenom: 'Soa',
      nomUtilisateur: 'soarabe',
      motDePasse: 'secret123',
    );
    expect(idNouveau, isPositive);

    // 2. Connexion avec le nouvel utilisateur
    final user = await authService.login(
      nomUtilisateur: 'soarabe',
      motDePasse: 'secret123',
    );
    expect(user.isCaissier, isTrue);
    expect(user.nomComplet, equals('Soa Rabe'));

    // 3. Changement de mot de passe
    await authService.changerMotDePasse(
      idUtilisateur: user.id,
      ancienMdp: 'secret123',
      nouveauMdp: 'nouveau456',
    );

    authService.logout();

    // 4. Reconnexion avec le nouveau mot de passe
    final userReconnected = await authService.login(
      nomUtilisateur: 'soarabe',
      motDePasse: 'nouveau456',
    );
    expect(userReconnected.id, equals(user.id));
  });

  testWidgets('Interface UI: LoginScreen, connexion et UserAvatarButton', (WidgetTester tester) async {
    // 1. Lancement de l'application (non authentifié) -> LoginScreen affiché
    await tester.runAsync(() async {
      await tester.pumpWidget(const AchatVenteStockApp(startAuthenticated: false));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(find.text('GESTION COMMERCIALE'), findsOneWidget);
    expect(find.text('Connexion Utilisateur'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);

    // 2. Taper sur "Se connecter" (pré-rempli avec admin / admin123)
    await tester.runAsync(() async {
      await tester.tap(find.text('Se connecter'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 3. Après connexion -> Redirigé vers MainShell avec bouton avatar utilisateur
    expect(find.byType(UserAvatarButton), findsWidgets);
    expect(find.text('VENTES & FACTURATION'), findsOneWidget);

    // 4. Cliquer sur le badge utilisateur pour ouvrir le dialogue profil
    await tester.runAsync(() async {
      await tester.tap(find.byType(UserAvatarButton).first, warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Administrateur'), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);

    // 5. Cliquer sur "Se déconnecter" -> Retour au LoginScreen
    await tester.runAsync(() async {
      await tester.tap(find.text('Se déconnecter'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(find.text('Connexion Utilisateur'), findsOneWidget);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(seconds: 12));
  });
}
