import 'package:app_standard/models/profil.dart';
import 'package:app_standard/models/utilisateur.dart';
import 'package:app_standard/services/auth_service.dart';
import 'package:app_standard/screens/sync/supabase_config_dialog.dart';
import 'package:app_standard/screens/sync/supabase_sync_dialog.dart';
import 'package:app_standard/services/supabase_sync_service.dart';
import 'package:app_standard/widgets/sync_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SupabaseSyncService Logic & Data Formatting', () {
    test('orderedTables contient les 30 tables SQLite dans le bon ordre de dépendance', () {
      final tables = SupabaseSyncService.orderedTables;
      expect(tables.length, 30);

      // Tables de référence en premier
      expect(tables.indexOf('profil'), lessThan(tables.indexOf('utilisateur')));
      expect(tables.indexOf('statut'), lessThan(tables.indexOf('commande_vente')));
      expect(tables.indexOf('type_client'), lessThan(tables.indexOf('client')));
      expect(tables.indexOf('type_caisse'), lessThan(tables.indexOf('caisse')));
      expect(tables.indexOf('categorie'), lessThan(tables.indexOf('article')));
      expect(tables.indexOf('unite_mesure'), lessThan(tables.indexOf('article')));

      // Situation de stock après article et dépôt
      expect(tables.indexOf('depot'), lessThan(tables.indexOf('stock_depot')));
      expect(tables.indexOf('article'), lessThan(tables.indexOf('stock_depot')));

      // Journal de caisse avant mouvements de caisse
      expect(tables.indexOf('utilisateur'), lessThan(tables.indexOf('journal_caisse')));
      expect(tables.indexOf('journal_caisse'), lessThan(tables.indexOf('journal_caisse_ligne')));
      expect(tables.indexOf('journal_caisse'), lessThan(tables.indexOf('mouvement_caisse')));

      // Documents de vente
      expect(tables.indexOf('client'), lessThan(tables.indexOf('commande_vente')));
      expect(tables.indexOf('commande_vente'), lessThan(tables.indexOf('commande_vente_ligne')));
      expect(tables.indexOf('commande_vente'), lessThan(tables.indexOf('facture_client')));
      expect(tables.indexOf('facture_client'), lessThan(tables.indexOf('paiement_vente')));

      // Documents d'achat
      expect(tables.indexOf('fournisseur'), lessThan(tables.indexOf('commande_achat')));
      expect(tables.indexOf('commande_achat'), lessThan(tables.indexOf('commande_achat_ligne')));
      expect(tables.indexOf('commande_achat'), lessThan(tables.indexOf('facture_fournisseur')));
      expect(tables.indexOf('facture_fournisseur'), lessThan(tables.indexOf('paiement_achat')));
    });

    test('sanitizeRow convertit correctement les booléens SQLite (1/0) en booléens JSON (true/false)', () {
      final service = SupabaseSyncService.instance;

      // Pour un article : actif et suivi_stock doivent devenir de vrais booléens
      final rawArticle = {
        'id': 1,
        'reference': 'ART-001',
        'designation': 'Clavier USB',
        'suivi_stock': 1,
        'actif': 1,
        'prix_vente_standard': 45000.0,
      };

      final sanitizedArticle = service.sanitizeRow('article', rawArticle);
      expect(sanitizedArticle['suivi_stock'], true);
      expect(sanitizedArticle['actif'], true);
      expect(sanitizedArticle['prix_vente_standard'], 45000.0);

      final rawArticleInactif = {
        'id': 2,
        'reference': 'ART-002',
        'suivi_stock': 0,
        'actif': 0,
      };
      final sanitizedArticleInactif = service.sanitizeRow('article', rawArticleInactif);
      expect(sanitizedArticleInactif['suivi_stock'], false);
      expect(sanitizedArticleInactif['actif'], false);

      // Pour le mode de paiement : actif est booléen
      final rawMode = {'id': 1, 'code': 'ESPECES', 'actif': 1};
      final sanitizedMode = service.sanitizeRow('mode_paiement', rawMode);
      expect(sanitizedMode['actif'], true);

      // Pour profil et utilisateur : actif est également converti en booléen
      final rawUser = {'id': 1, 'nom': 'Admin', 'actif': 1};
      final sanitizedUser = service.sanitizeRow('utilisateur', rawUser);
      expect(sanitizedUser['actif'], true);
    });

    test('getTableSelectQuery ordonne correctement la table categorie pour les relations parent-enfant', () {
      final service = SupabaseSyncService.instance;

      final catQuery = service.getTableSelectQuery('categorie');
      expect(catQuery, contains('ORDER BY CASE WHEN id_parent IS NULL THEN 0 ELSE 1 END, id ASC'));

      final artQuery = service.getTableSelectQuery('article');
      expect(artQuery, 'SELECT * FROM article ORDER BY id ASC');
    });

    test('Gestion de la configuration et persistance dans SharedPreferences', () async {
      final service = SupabaseSyncService.instance;

      await service.clearConfig();
      expect(await service.isConfigured(), false);

      await service.saveConfig(
        url: 'https://test-project.supabase.co',
        anonKey: 'sample-anon-key-12345',
      );

      expect(await service.isConfigured(), true);
      expect(await service.getUrl(), 'https://test-project.supabase.co');
      expect(await service.getAnonKey(), 'sample-anon-key-12345');

      await service.clearConfig();
      expect(await service.isConfigured(), false);
    });

    test('SyncResult calcule correctement la durée et le statut de succès', () {
      final start = DateTime(2026, 9, 29, 10, 0, 0);
      final end = DateTime(2026, 9, 29, 10, 0, 15);

      final result = SyncResult(
        isSuccess: true,
        totalRowsSynced: 120,
        rowsPerTable: {'article': 50, 'client': 70},
        errorsPerTable: {},
        startedAt: start,
        completedAt: end,
      );

      expect(result.isSuccess, true);
      expect(result.totalRowsSynced, 120);
      expect(result.duration.inSeconds, 15);
      expect(result.globalError, isNull);
    });
  });

  group('Widgets UI de Synchronisation Supabase', () {
    testWidgets('SyncButton affiche le bouton et ouvre SupabaseSyncDialog au clic', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(56),
              child: SafeArea(
                child: Row(
                  children: [
                    SyncButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(SyncButton), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_sync_outlined), findsOneWidget);

      // Clic sur le bouton de synchronisation
      await tester.tap(find.byType(SyncButton));
      await tester.pumpAndSettle();

      // Vérifier que la boîte de dialogue Supabase s'affiche
      expect(find.byType(SupabaseSyncDialog), findsOneWidget);
      expect(find.text('Synchronisation Supabase'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
    });

    testWidgets('SupabaseConfigDialog valide les champs URL et clé Anon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SupabaseConfigDialog(),
          ),
        ),
      );

      expect(find.text('Configuration Supabase'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Tester la connexion'), findsOneWidget);

      // Vider le champ URL pour tester la validation
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      // Erreur de validation affichée
      expect(find.text('L\'URL Supabase est requise'), findsOneWidget);
    });

    test('Permissions RBAC : Caissier peut seulement PUSH, pas PULL', () {
      const profilCaissier = Profil(
        id: 2,
        numero: 11,
        code: 'CAISSIER',
        libelle: 'Caissier(e)',
      );
      expect(profilCaissier.canSyncPush, isTrue);
      expect(profilCaissier.canSyncPull, isFalse);
      expect(profilCaissier.canSyncBidirectional, isFalse);

      const profilAdmin = Profil(
        id: 1,
        numero: 1,
        code: 'ADMIN',
        libelle: 'Administrateur',
      );
      expect(profilAdmin.canSyncPush, isTrue);
      expect(profilAdmin.canSyncPull, isTrue);
      expect(profilAdmin.canSyncBidirectional, isTrue);

      const profilGerant = Profil(
        id: 4,
        numero: 31,
        code: 'GERANT',
        libelle: 'Gérant',
      );
      expect(profilGerant.canSyncPush, isTrue);
      expect(profilGerant.canSyncPull, isTrue);

      const profilMagasinier = Profil(
        id: 3,
        numero: 21,
        code: 'MAGASINIER',
        libelle: 'Magasinier',
      );
      expect(profilMagasinier.canSyncPush, isTrue);
      expect(profilMagasinier.canSyncPull, isTrue);
    });

    test('SupabaseSyncService: sanitizeRowForSqlite convertit les booléens JSON en 1/0 SQLite', () {
      final service = SupabaseSyncService.instance;
      final raw = {
        'id': 10,
        'nom': 'Produit',
        'actif': true,
        'suivi_stock': false,
        'quantite': 15,
      };

      final sanitized = service.sanitizeRowForSqlite('article', raw);
      expect(sanitized['actif'], 1);
      expect(sanitized['suivi_stock'], 0);
      expect(sanitized['quantite'], 15);
    });

    test('pullAll et syncBidirectional lèvent une exception si l\'utilisateur est Caissier', () async {
      final auth = AuthService.instance;
      // Connecter un caissier
      auth.setCurrentUserForTesting(
        const Utilisateur(
          id: 2,
          idProfil: 2,
          profilCode: 'CAISSIER',
          profilLibelle: 'Caissier(e)',
          nom: 'Rasoa',
          nomUtilisateur: 'caissier',
          motDePasseHash: 'caissier123',
        ),
      );

      final service = SupabaseSyncService.instance;

      expect(
        () => service.pullAll(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Action non autorisée : Le profil Caissier'),
        )),
      );

      expect(
        () => service.syncBidirectional(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Action non autorisée : Le profil Caissier'),
        )),
      );

      // Déconnecter
      auth.setCurrentUserForTesting(null);
    });
  });
}
