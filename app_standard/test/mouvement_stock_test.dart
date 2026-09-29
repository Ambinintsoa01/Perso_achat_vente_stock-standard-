import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/services/achat_service.dart';
import 'package:app_standard/services/stock_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late StockService stockService;
  late AchatService achatService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DbHelper.setDatabaseForTesting(db);
    await DbHelper.instance.populateTestDb(db);

    stockService = StockService();
    achatService = AchatService();

    // Créer une catégorie de test
    final idCat = await stockService.ajouterCategorie(code: 'EPICERIE', nom: 'Épicerie');

    // Créer deux articles
    await stockService.ajouterArticle(
      reference: 'ART-SUCRE',
      designation: 'Sucre Roux 1kg',
      idCategorie: idCat,
      prixAchat: 3500.0,
      stockInitial: 0.0,
    );

    await stockService.ajouterArticle(
      reference: 'ART-FARINE',
      designation: 'Farine de Blé 1kg',
      idCategorie: idCat,
      prixAchat: 4000.0,
      stockInitial: 0.0,
    );
  });

  tearDown(() async {
    await db.close();
    DbHelper.setDatabaseForTesting(null);
  });

  test('Historique des mouvements de stock: enregistrement et filtres', () async {
    final articles = await stockService.getArticles();
    final sucre = articles.firstWhere((a) => a.reference == 'ART-SUCRE');
    final farine = articles.firstWhere((a) => a.reference == 'ART-FARINE');

    // 1. Réaliser un achat de Sucre (Entrée de 20 unités)
    await achatService.enregistrerAchat(
      idFournisseur: 1,
      articlesAchetes: [
        LigneAchatInput(
          idArticle: sucre.id,
          designation: sucre.designation,
          quantite: 20.0,
          prixUnitaire: 3600.0,
        ),
      ],
      payeImmediatement: false,
    );

    // 2. Réaliser un ajustement positif de Farine (+8 unités)
    await stockService.ajusterStock(
      idArticle: farine.id,
      quantite: 8.0,
      idTypeMouvement: 3, // AJUSTEMENT_POSITIF
      remarque: 'Arrivage supplémentaire',
    );

    // 3. Réaliser un ajustement négatif de Sucre (-3 unités, avarie)
    await stockService.ajusterStock(
      idArticle: sucre.id,
      quantite: 3.0,
      idTypeMouvement: 4, // AJUSTEMENT_NEGATIF
      remarque: 'Paquet déchiré',
    );

    // 4. Test filtre: Tous les mouvements
    final tous = await stockService.getMouvementsStock();
    expect(tous.length, 3);

    // 5. Test filtre: Par article (Sucre uniquement)
    final mvtsSucre = await stockService.getMouvementsStock(idArticle: sucre.id);
    expect(mvtsSucre.length, 2);
    expect(mvtsSucre.any((m) => m.isEntree && m.quantite == 20.0), true);
    expect(mvtsSucre.any((m) => m.isSortie && m.quantite == 3.0), true);

    // 6. Test filtre: Par sens Entrée (+1)
    final entrees = await stockService.getMouvementsStock(sens: 1);
    expect(entrees.length, 2); // Achat sucre + ajustement positif farine
    expect(entrees.every((m) => m.isEntree), true);

    // 7. Test filtre: Par sens Sortie (-1)
    final sorties = await stockService.getMouvementsStock(sens: -1);
    expect(sorties.length, 1);
    expect(sorties.first.quantite, 3.0);
    expect(sorties.first.remarque, 'Paquet déchiré');

    // 8. Test filtre: Recherche textuelle
    final rechercheFarine = await stockService.getMouvementsStock(searchQuery: 'Farine');
    expect(rechercheFarine.length, 1);
    expect(rechercheFarine.first.articleDesignation, 'Farine de Blé 1kg');

    final rechercheMotif = await stockService.getMouvementsStock(searchQuery: 'déchiré');
    expect(rechercheMotif.length, 1);
  });
}
