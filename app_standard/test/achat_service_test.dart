import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/services/achat_service.dart';
import 'package:app_standard/services/caisse_service.dart';
import 'package:app_standard/services/stock_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

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

    // Créer une catégorie de test
    final idCat = await stockService.ajouterCategorie(code: 'ALIM', nom: 'Alimentation');

    // Créer deux articles de test avec stock initial
    await stockService.ajouterArticle(
      reference: 'ART-001',
      designation: 'Sucre Blanc 1kg',
      idCategorie: idCat,
      prixAchat: 4000.0,
      prixVente: 4600.0,
      stockInitial: 20.0,
    );

    await stockService.ajouterArticle(
      reference: 'ART-002',
      designation: 'Huile de Tournesol 1L',
      idCategorie: idCat,
      prixAchat: 8000.0,
      prixVente: 9500.0,
      stockInitial: 15.0,
    );
  });

  tearDown(() async {
    await db.close();
    DbHelper.setDatabaseForTesting(null);
  });

  test('Achat au comptant: impacte stock, CUMP et caisse en transaction atomique', () async {
    // 1. Récupérer l'état initial
    final articles = await stockService.getArticles();
    final articleTest = articles.firstWhere((a) => a.reference == 'ART-001'); // Sucre Blanc 1kg, stock initial = 20, cump initial = 4000
    final caisses = await caisseService.getCaisses();
    final caissePrincipale = caisses.first; // Tiroir-Caisse Espèces, solde = 250 000
    final modes = await caisseService.getModesPaiement();
    final modeEspece = modes.first;

    final double soldeInitialCaisse = caissePrincipale.soldeActuel;
    final double stockInitialArticle = articleTest.quantiteStock;

    // 2. Enregistrer un achat au comptant de 10 unités à 4200 Ar
    final qteAchetee = 10.0;
    final prixUnitaireAchat = 4200.0;
    final montantTotal = qteAchetee * prixUnitaireAchat; // 42 000 Ar

    final idCommande = await achatService.enregistrerAchat(
      idFournisseur: 1,
      articlesAchetes: [
        LigneAchatInput(
          idArticle: articleTest.id,
          designation: articleTest.designation,
          quantite: qteAchetee,
          prixUnitaire: prixUnitaireAchat,
        ),
      ],
      payeImmediatement: true,
      idCaisse: caissePrincipale.id,
      idModePaiement: modeEspece.id,
    );

    expect(idCommande, greaterThan(0));

    // 3. Vérifier l'impact sur le STOCK
    final articlesApres = await stockService.getArticles();
    final articleApres = articlesApres.firstWhere((a) => a.id == articleTest.id);
    expect(articleApres.quantiteStock, stockInitialArticle + qteAchetee);

    // CUMP attendu: ((20 * 4000) + (10 * 4200)) / (20 + 10) = (80000 + 42000) / 30 = 122000 / 30 = 4066.666...
    final expectedCump = ((stockInitialArticle * articleTest.coutMoyenUnitaire) + (qteAchetee * prixUnitaireAchat)) / (stockInitialArticle + qteAchetee);
    expect((articleApres.coutMoyenUnitaire - expectedCump).abs(), lessThan(0.01));

    // Vérifier l'enregistrement du mouvement_stock
    final mvtsStock = await db.query(
      'mouvement_stock',
      where: 'id_article = ? AND id_type_mouvement = 1',
      whereArgs: [articleTest.id],
    );
    expect(mvtsStock.isNotEmpty, true);
    expect((mvtsStock.last['quantite'] as num).toDouble(), qteAchetee);
    expect((mvtsStock.last['stock_apres'] as num).toDouble(), stockInitialArticle + qteAchetee);

    // 4. Vérifier l'impact sur la CAISSE
    final caissesApres = await caisseService.getCaisses();
    final caisseApres = caissesApres.firstWhere((c) => c.id == caissePrincipale.id);
    expect(caisseApres.soldeActuel, soldeInitialCaisse - montantTotal);

    // Vérifier l'enregistrement du mouvement_caisse
    final mvtsCaisse = await db.query(
      'mouvement_caisse',
      where: 'id_caisse = ? AND id_type_mouvement = 2', // 2 = DECAISSEMENT_ACHAT
      whereArgs: [caissePrincipale.id],
    );
    expect(mvtsCaisse.isNotEmpty, true);
    expect((mvtsCaisse.last['montant'] as num).toDouble(), montantTotal);
    expect((mvtsCaisse.last['solde_apres'] as num).toDouble(), soldeInitialCaisse - montantTotal);
  });

  test('Achat à crédit: augmente le stock sans impacter la caisse, puis règlement de la dette', () async {
    final articles = await stockService.getArticles();
    final articleTest = articles.firstWhere((a) => a.reference == 'ART-002'); // Huile
    final caisses = await caisseService.getCaisses();
    final caissePrincipale = caisses.first;
    final modes = await caisseService.getModesPaiement();
    final modeEspece = modes.first;

    final double soldeInitialCaisse = caissePrincipale.soldeActuel;
    final double stockInitialArticle = articleTest.quantiteStock;

    // 1. Achat à crédit de 5 unités à 8500 Ar
    final qteAchetee = 5.0;
    final prixAchat = 8500.0;
    final montantTotal = qteAchetee * prixAchat; // 42 500 Ar

    final idCommande = await achatService.enregistrerAchat(
      idFournisseur: 1,
      articlesAchetes: [
        LigneAchatInput(
          idArticle: articleTest.id,
          designation: articleTest.designation,
          quantite: qteAchetee,
          prixUnitaire: prixAchat,
        ),
      ],
      payeImmediatement: false,
    );

    expect(idCommande, greaterThan(0));

    // 2. Vérifier que le stock a augmenté
    final articlesApres = await stockService.getArticles();
    final articleApres = articlesApres.firstWhere((a) => a.id == articleTest.id);
    expect(articleApres.quantiteStock, stockInitialArticle + qteAchetee);

    // 3. Vérifier que la caisse N'A PAS été débitée
    final caissesApresAchat = await caisseService.getCaisses();
    final caisseApresAchat = caissesApresAchat.firstWhere((c) => c.id == caissePrincipale.id);
    expect(caisseApresAchat.soldeActuel, soldeInitialCaisse);

    // 4. Vérifier que la dette fournisseur existe
    final summary = await achatService.getAchatSummary();
    expect(summary.totalDettesFournisseurs, greaterThanOrEqualTo(montantTotal));

    final commandesImpayees = await achatService.getCommandesAchat(onlyUnpaid: true);
    final cmd = commandesImpayees.firstWhere((c) => c.id == idCommande);
    expect(cmd.estPaye, false);
    expect(cmd.resteAPayer, montantTotal);

    // 5. Régler la dette fournisseur
    await achatService.reglerDetteFournisseur(
      idCommandeAchat: cmd.id,
      idCaisse: caissePrincipale.id,
      idModePaiement: modeEspece.id,
      montant: montantTotal,
    );

    // 6. Vérifier que la caisse a maintenant été débitée
    final caissesApresReglement = await caisseService.getCaisses();
    final caisseApresReglement = caissesApresReglement.firstWhere((c) => c.id == caissePrincipale.id);
    expect(caisseApresReglement.soldeActuel, soldeInitialCaisse - montantTotal);

    // 7. Vérifier que la commande est maintenant marquée comme soldée
    final commandesApresReglement = await achatService.getCommandesAchat();
    final cmdSoldee = commandesApresReglement.firstWhere((c) => c.id == idCommande);
    expect(cmdSoldee.estPaye, true);
    expect(cmdSoldee.resteAPayer, 0.0);
  });
}
