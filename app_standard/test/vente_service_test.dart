import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/services/caisse_service.dart';
import 'package:app_standard/services/stock_service.dart';
import 'package:app_standard/services/vente_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late VenteService venteService;
  late CaisseService caisseService;
  late StockService stockService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DbHelper.setDatabaseForTesting(db);
    await DbHelper.instance.populateTestDb(db);

    venteService = VenteService();
    caisseService = CaisseService();
    stockService = StockService();

    // Créer une catégorie de test
    final idCat = await stockService.ajouterCategorie(code: 'ALIM', nom: 'Alimentation');

    // Créer un article de test avec stock initial de 20 unités
    await stockService.ajouterArticle(
      reference: 'ART-001',
      designation: 'Sucre Blanc 1kg',
      idCategorie: idCat,
      prixAchat: 4000.0,
      prixVente: 4600.0,
      stockInitial: 20.0,
    );
  });

  tearDown(() async {
    await db.close();
    DbHelper.setDatabaseForTesting(null);
  });

  test('Vente au comptant: décrémente stock, crédite caisse et solde la facture en transaction atomique', () async {
    final articles = await stockService.getArticles();
    final article = articles.firstWhere((a) => a.reference == 'ART-001');
    final caisses = await caisseService.getCaisses();
    final caisse = caisses.first; // Tiroir-Caisse Espèces, solde = 250 000
    final clients = await venteService.getClients();
    final client = clients.first;

    final soldeInitialCaisse = caisse.soldeActuel;
    final stockInitial = article.quantiteStock; // 20.0

    // Vente de 5 unités à 4600 Ar = 23 000 Ar
    final idCommande = await venteService.enregistrerVente(
      idClient: client.id,
      articlesVendus: [
        LigneVenteInput(
          idArticle: article.id,
          designation: article.designation,
          quantite: 5.0,
          prixUnitaire: 4600.0,
        ),
      ],
      payeImmediatement: true,
      idCaisse: caisse.id,
      idModePaiement: 1, // Espèces
    );

    expect(idCommande, isPositive);

    // 1. Vérification du stock décrémenté
    final articlesApres = await stockService.getArticles();
    final articleApres = articlesApres.firstWhere((a) => a.id == article.id);
    expect(articleApres.quantiteStock, equals(stockInitial - 5.0)); // 15.0

    // 2. Vérification du mouvement de stock
    final mvtsStock = await stockService.getMouvementsStock();
    final mvtVente = mvtsStock.firstWhere((m) => m.referenceDocument?.startsWith('BCV-') == true);
    expect(mvtVente.quantite, equals(5.0));
    expect(mvtVente.isSortie, isTrue);

    // 3. Vérification du solde de caisse augmenté
    final caissesApres = await caisseService.getCaisses();
    final caisseApres = caissesApres.firstWhere((c) => c.id == caisse.id);
    expect(caisseApres.soldeActuel, equals(soldeInitialCaisse + 23000.0));

    // 4. Vérification du mouvement de caisse
    final mvtsCaisse = await db.query(
      'mouvement_caisse',
      where: 'id_type_mouvement = 1', // 1 = ENCAISSEMENT_VENTE
    );
    expect(mvtsCaisse.isNotEmpty, isTrue);
    expect((mvtsCaisse.last['montant'] as num).toDouble(), equals(23000.0));

    // 5. Vérification de la commande et de son statut
    final commandes = await venteService.getCommandesVente();
    final commande = commandes.firstWhere((c) => c.id == idCommande);
    expect(commande.estPaye, isTrue);
    expect(commande.montantTtc, equals(23000.0));
  });

  test('Vente à crédit: décrémente stock sans impacter la caisse, puis encaissement de la créance', () async {
    final articles = await stockService.getArticles();
    final article = articles.firstWhere((a) => a.reference == 'ART-001');
    final caisses = await caisseService.getCaisses();
    final caisse = caisses.first;
    final clients = await venteService.getClients();
    final client = clients.first;

    final soldeInitialCaisse = caisse.soldeActuel;

    // Vente de 3 unités à 4600 Ar = 13 800 Ar À CRÉDIT
    final idCommande = await venteService.enregistrerVente(
      idClient: client.id,
      articlesVendus: [
        LigneVenteInput(
          idArticle: article.id,
          designation: article.designation,
          quantite: 3.0,
          prixUnitaire: 4600.0,
        ),
      ],
      payeImmediatement: false,
    );

    // 1. Le stock doit baisser de 3 (20 -> 17)
    final articlesApres = await stockService.getArticles();
    expect(articlesApres.firstWhere((a) => a.id == article.id).quantiteStock, equals(17.0));

    // 2. La caisse NE doit PAS avoir changé
    final caissesApres = await caisseService.getCaisses();
    expect(caissesApres.firstWhere((c) => c.id == caisse.id).soldeActuel, equals(soldeInitialCaisse));

    // 3. La commande doit être non payée
    final impayes = await venteService.getCommandesVente(onlyUnpaid: true);
    final commandeImpayee = impayes.firstWhere((c) => c.id == idCommande);
    expect(commandeImpayee.estPaye, isFalse);
    expect(commandeImpayee.resteAPayer, equals(13800.0));

    // 4. Encaissement de la créance
    final idFacture = commandeImpayee.idFacture;
    expect(idFacture, isNotNull);

    await venteService.reglerCreanceClient(
      idFactureClient: idFacture!,
      idCaisse: caisse.id,
      idModePaiement: 1,
      montantRegle: 13800.0,
      notes: 'Encaissement total dette client',
    );

    // 5. Après encaissement : caisse augmentée, facture soldée
    final caissesFinales = await caisseService.getCaisses();
    expect(caissesFinales.firstWhere((c) => c.id == caisse.id).soldeActuel, equals(soldeInitialCaisse + 13800.0));

    final impayesApres = await venteService.getCommandesVente(onlyUnpaid: true);
    expect(impayesApres.any((c) => c.id == idCommande), isFalse);

    final toutesCommandes = await venteService.getCommandesVente();
    final commandeSoldee = toutesCommandes.firstWhere((c) => c.id == idCommande);
    expect(commandeSoldee.estPaye, isTrue);
  });

  test('Blocage de vente en cas de stock insuffisant', () async {
    final articles = await stockService.getArticles();
    final article = articles.firstWhere((a) => a.reference == 'ART-001'); // Stock disponible = 20.0
    final clients = await venteService.getClients();

    expect(
      () async => await venteService.enregistrerVente(
        idClient: clients.first.id,
        articlesVendus: [
          LigneVenteInput(
            idArticle: article.id,
            designation: article.designation,
            quantite: 50.0, // Dépasse les 20 unités disponibles !
            prixUnitaire: 4600.0,
          ),
        ],
        payeImmediatement: true,
      ),
      throwsA(isA<Exception>()),
    );

    // Le stock ne doit pas avoir bougé
    final articlesApres = await stockService.getArticles();
    expect(articlesApres.firstWhere((a) => a.id == article.id).quantiteStock, equals(20.0));
  });

  test('Filtre par date obligatoire sur les commandes de vente', () async {
    final articles = await stockService.getArticles();
    final article = articles.firstWhere((a) => a.reference == 'ART-001');
    final clients = await venteService.getClients();

    await venteService.enregistrerVente(
      idClient: clients.first.id,
      articlesVendus: [
        LigneVenteInput(
          idArticle: article.id,
          designation: article.designation,
          quantite: 2.0,
          prixUnitaire: 4600.0,
        ),
      ],
      payeImmediatement: false,
    );

    final today = DateTime.now();
    final commandesAujourdhui = await venteService.getCommandesVente(
      dateDebut: today,
      dateFin: today,
    );
    expect(commandesAujourdhui.isNotEmpty, isTrue);

    // Date dans le futur -> aucune commande trouvée
    final futur = today.add(const Duration(days: 30));
    final commandesFutur = await venteService.getCommandesVente(
      dateDebut: futur,
      dateFin: futur,
    );
    expect(commandesFutur.isEmpty, isTrue);
  });

  test('Gestion des clients et KPIs du résumé des ventes', () async {
    // 1. Client comptoir par défaut présent
    final clientsInitiaux = await venteService.getClients();
    expect(clientsInitiaux.isNotEmpty, isTrue);
    expect(clientsInitiaux.any((c) => c.nomComplet.contains('Comptoir')), isTrue);

    // 2. Ajout d'un nouveau client
    final nouveauClientId = await venteService.ajouterClient(
      nomComplet: 'Société Razafy SARL',
      telephone: '034 11 222 33',
      email: 'contact@razafy.mg',
      ville: 'Antananarivo',
    );
    expect(nouveauClientId, isPositive);

    final clientsApres = await venteService.getClients();
    expect(clientsApres.any((c) => c.nomComplet == 'Société Razafy SARL'), isTrue);

    // 3. Vérification du résumé des ventes (VenteSummary)
    final summary = await venteService.getVenteSummary();
    expect(summary.totalVentesMois, isNonNegative);
    expect(summary.nombreVentes, isNonNegative);
  });
}
