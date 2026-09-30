import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/models/journal_caisse.dart';
import 'package:app_standard/screens/caisse/caisse_screen.dart';
import 'package:app_standard/screens/caisse/widgets/journal_caisse_details_dialog.dart';
import 'package:app_standard/services/auth_service.dart';
import 'package:app_standard/services/caisse_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late CaisseService caisseService;
  late AuthService authService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DbHelper.setDatabaseForTesting(db);
    await DbHelper.instance.populateTestDb(db, openDefaultJournal: false);

    caisseService = CaisseService();
    authService = AuthService.instance;
    authService.logout();
  });

  tearDown(() async {
    authService.logout();
    await db.close();
    DbHelper.setDatabaseForTesting(null);
  });

  test('Journal de Caisse : Cycle complet Ouverture -> Mouvements -> Clôture -> Report le lendemain', () async {
    // 1. Initialement, aucun journal ouvert
    final journalInitial = await caisseService.getJournalOuvert();
    expect(journalInitial, isNull);

    final caisses = await caisseService.getCaisses();
    expect(caisses, isNotEmpty);
    final caisseComptoir = caisses.firstWhere((c) => c.code == 'CSH-01');
    final caisseMvola = caisses.firstWhere((c) => c.code == 'MVOLA-01');

    // Règle métier : Aucun mouvement ni transfert de caisse possible si aucun journal n'est ouvert
    expect(
      () => caisseService.enregistrerMouvement(
        idCaisse: caisseComptoir.id,
        idTypeMouvement: 1,
        idModePaiement: 1,
        montant: 50000.0,
      ),
      throwsA(isA<Exception>()),
    );

    expect(
      () => caisseService.transfertInterne(
        idCaisseSource: caisseComptoir.id,
        idCaisseDestination: caisseMvola.id,
        montant: 20000.0,
      ),
      throwsA(isA<Exception>()),
    );

    // 2. OUVERTURE JOUR 1 (Matin)
    // Comptoir = 100 000 Ar, MVola = 500 000 Ar
    final journalJour1 = await caisseService.ouvrirJournal(
      idUtilisateur: 1,
      soldesOuvertureParCaisse: {
        caisseComptoir.id: 100000.0,
        caisseMvola.id: 500000.0,
      },
      notes: 'Ouverture Jour 1',
    );

    expect(journalJour1.isOuvert, isTrue);
    expect(journalJour1.soldeOuvertureTotal, 600000.0);

    // Vérifier que getJournalOuvert() renvoie bien ce journal
    final activeJournal = await caisseService.getJournalOuvert();
    expect(activeJournal, isNotNull);
    expect(activeJournal!.id, journalJour1.id);

    // 3. FLUX DU JOUR 1
    // a. Encaissement vente sur Comptoir (+50 000 Ar)
    await caisseService.enregistrerMouvement(
      idCaisse: caisseComptoir.id,
      idTypeMouvement: 1, // ENCAISSEMENT_VENTE
      idModePaiement: 1,
      montant: 50000.0,
      description: 'Vente au comptoir',
    );

    // b. Dépense diverse sur Comptoir (-10 000 Ar)
    await caisseService.enregistrerMouvement(
      idCaisse: caisseComptoir.id,
      idTypeMouvement: 5, // DEPENSE_DIVERSE
      idModePaiement: 1,
      montant: 10000.0,
      description: 'Achat ampoules boutique',
    );

    // c. Encaissement Mobile Money sur MVola (+200 000 Ar)
    await caisseService.enregistrerMouvement(
      idCaisse: caisseMvola.id,
      idTypeMouvement: 1, // ENCAISSEMENT_VENTE
      idModePaiement: 4, // MVOLA
      montant: 200000.0,
      description: 'Vente règlement MVola',
    );

    // 4. VÉRIFICATION DU CALCUL EN DIRECT
    final lignesDirect = await caisseService.getLignesJournalAvecTotaux(journalJour1.id);
    final ligneComptoir = lignesDirect.firstWhere((l) => l.idCaisse == caisseComptoir.id);
    final ligneMvola = lignesDirect.firstWhere((l) => l.idCaisse == caisseMvola.id);

    // Comptoir : 100 000 + 50 000 - 10 000 = 140 000 Ar
    expect(ligneComptoir.soldeOuverture, 100000.0);
    expect(ligneComptoir.totalEntrees, 50000.0);
    expect(ligneComptoir.totalSorties, 10000.0);
    expect(ligneComptoir.soldeTheorique, 140000.0);

    // MVola : 500 000 + 200 000 = 700 000 Ar
    expect(ligneMvola.soldeOuverture, 500000.0);
    expect(ligneMvola.totalEntrees, 200000.0);
    expect(ligneMvola.totalSorties, 0.0);
    expect(ligneMvola.soldeTheorique, 700000.0);

    // 5. CLÔTURE JOUR 1 (Soir)
    // La caissière compte les espèces dans le tiroir (140 000 Ar) et vérifie MVola (700 000 Ar)
    await caisseService.fermerJournal(
      idJournal: journalJour1.id,
      idUtilisateurFermeture: 1,
      soldesReelsParCaisse: {
        caisseComptoir.id: 140000.0,
        caisseMvola.id: 700000.0,
      },
      notesFermeture: 'Clôture normale sans écart',
    );

    // Vérifier que le journal est bien clôturé
    final journalCloture = await caisseService.getJournalDetails(journalJour1.id);
    expect(journalCloture!.isCloture, isTrue);
    expect(journalCloture.soldeTheoriqueTotal, 840000.0);
    expect(journalCloture.soldeReelTotal, 840000.0);
    expect(journalCloture.ecartTotal, 0.0);

    // Plus aucun journal n'est ouvert actuellement
    expect(await caisseService.getJournalOuvert(), isNull);

    // Règle métier : Dès la clôture du soir, les mouvements de caisse sont à nouveau interdits
    expect(
      () => caisseService.enregistrerMouvement(
        idCaisse: caisseComptoir.id,
        idTypeMouvement: 1,
        idModePaiement: 1,
        montant: 10000.0,
      ),
      throwsA(isA<Exception>()),
    );

    // 6. RÈGLE CRUCIALE DEMANDÉE PAR L'UTILISATEUR :
    // "Le reste d'argent dans la caisse (comptoire ou mobile money) d'aujourd'hui sera le solde de demain et ainsi de suite"
    final suggestionsJour2 = await caisseService.getSoldesOuvertureSuggeres();
    expect(suggestionsJour2[caisseComptoir.id], 140000.0,
        reason: 'Le solde restant du comptoir (140 000 Ar) devient le solde de départ de demain');
    expect(suggestionsJour2[caisseMvola.id], 700000.0,
        reason: 'Le solde restant de MVola (700 000 Ar) devient le solde de départ de demain');

    // 7. OUVERTURE JOUR 2 (Matin)
    final journalJour2 = await caisseService.ouvrirJournal(
      idUtilisateur: 1,
      soldesOuvertureParCaisse: {
        caisseComptoir.id: suggestionsJour2[caisseComptoir.id]!,
        caisseMvola.id: suggestionsJour2[caisseMvola.id]!,
      },
      notes: 'Ouverture Jour 2 avec report',
    );

    expect(journalJour2.isOuvert, isTrue);
    expect(journalJour2.soldeOuvertureTotal, 840000.0);

    final lignesJour2 = await caisseService.getLignesJournalAvecTotaux(journalJour2.id);
    final ligneComptoirJour2 = lignesJour2.firstWhere((l) => l.idCaisse == caisseComptoir.id);
    final ligneMvolaJour2 = lignesJour2.firstWhere((l) => l.idCaisse == caisseMvola.id);

    expect(ligneComptoirJour2.soldeOuverture, 140000.0);
    expect(ligneMvolaJour2.soldeOuverture, 700000.0);

    // Clôture Jour 2 avec un petit écart (ex: 139 500 Ar comptoir, soit -500 Ar manquant)
    await caisseService.fermerJournal(
      idJournal: journalJour2.id,
      idUtilisateurFermeture: 1,
      soldesReelsParCaisse: {
        caisseComptoir.id: 139500.0,
        caisseMvola.id: 700000.0,
      },
      notesFermeture: 'Manquant de 500 Ar sur le comptoir',
    );

    // Jour 3 : Le solde de départ du comptoir reprendra les 139 500 Ar constatés !
    final suggestionsJour3 = await caisseService.getSoldesOuvertureSuggeres();
    expect(suggestionsJour3[caisseComptoir.id], 139500.0);
  });

  test('Journal de Caisse : Filtres de dates sur l\'historique (AGENTS.md)', () async {
    final caisses = await caisseService.getCaisses();
    final cId = caisses.first.id;

    // Créer et fermer un journal
    final j = await caisseService.ouvrirJournal(
      idUtilisateur: 1,
      soldesOuvertureParCaisse: {cId: 50000.0},
    );
    await caisseService.fermerJournal(
      idJournal: j.id,
      idUtilisateurFermeture: 1,
      soldesReelsParCaisse: {cId: 50000.0},
    );

    // Liste sans filtre
    final tous = await caisseService.getJournaux();
    expect(tous.length, 1);

    // Filtre date du jour
    final aujourdhui = await caisseService.getJournaux(
      dateDebut: DateTime.now(),
      dateFin: DateTime.now(),
    );
    expect(aujourdhui.length, 1);

    // Filtre date future
    final futur = await caisseService.getJournaux(
      dateDebut: DateTime.now().add(const Duration(days: 10)),
      dateFin: DateTime.now().add(const Duration(days: 20)),
    );
    expect(futur.length, 0);
  });

  testWidgets('Interface CaisseScreen : Bandeau statut, Tabs et Historique des journaux', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await authService.login(nomUtilisateur: 'caissier', motDePasse: 'caissier123');
      await tester.pumpWidget(
        const MaterialApp(
          home: CaisseScreen(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    // Le bandeau "JOURNAL DE CAISSE FERMÉ" doit être présent au départ
    expect(find.text('JOURNAL DE CAISSE FERMÉ'), findsOneWidget);
    expect(find.text('OUVRIR'), findsOneWidget);

    // Les deux onglets du haut doivent être visibles
    expect(find.text('OPÉRATIONS DU JOUR'), findsOneWidget);
    expect(find.text('JOURNAUX DE CAISSE'), findsOneWidget);

    // Basculer vers l'onglet "JOURNAUX DE CAISSE"
    await tester.tap(find.text('JOURNAUX DE CAISSE'));
    await tester.pump();

    expect(find.text('HISTORIQUE DES JOURNAUX DE CAISSE'), findsOneWidget);

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(seconds: 12));
  });

  testWidgets('JournalCaisseDetailsDialog renders without overflow on a narrow mobile viewport (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    JournalCaisse? journal;
    await tester.runAsync(() async {
      final caisses = await caisseService.getCaisses();
      final soldes = {for (var c in caisses) c.id: c.soldeActuel};
      final j = await caisseService.ouvrirJournal(
        idUtilisateur: 1,
        soldesOuvertureParCaisse: soldes,
        notes: 'Ouverture test',
      );
      journal = await caisseService.getJournalDetails(j.id);
    });

    expect(journal, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JournalCaisseDetailsDialog(
            idJournal: journal!.id,
            initialJournal: journal,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OUVERT'), findsOneWidget);
    expect(find.text('OUVERTURE'), findsOneWidget);
    expect(find.text('THÉORIQUE'), findsOneWidget);
    expect(find.text('DÉTAIL PAR COMPTE DE CAISSE'), findsOneWidget);
    expect(find.text('FERMER'), findsOneWidget);
  });
}
