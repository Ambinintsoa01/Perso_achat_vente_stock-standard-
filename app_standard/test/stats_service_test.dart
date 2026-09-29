import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/services/achat_service.dart';
import 'package:app_standard/services/caisse_service.dart';
import 'package:app_standard/services/stats_service.dart';
import 'package:app_standard/services/stock_service.dart';
import 'package:app_standard/services/vente_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late StatsService statsService;
  late StockService stockService;
  late AchatService achatService;
  late VenteService venteService;
  late CaisseService caisseService;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    DbHelper.setDatabaseForTesting(db);
    await DbHelper.instance.populateTestDb(db);

    statsService = StatsService();
    stockService = StockService();
    achatService = AchatService();
    venteService = VenteService();
    caisseService = CaisseService();

    // 1. Créer catégories
    final idCatAlim = await stockService.ajouterCategorie(code: 'ALIM', nom: 'Alimentation');
    final idCatBoi = await stockService.ajouterCategorie(code: 'BOIS', nom: 'Boissons');

    // 2. Créer articles avec stock de départ
    // Article 1: 20 unités à CUMP 4000 Ar = Valeur Stock 80 000 Ar, Prix vente = 4600 Ar
    await stockService.ajouterArticle(
      reference: 'SUCRE-1KG',
      designation: 'Sucre Blanc 1kg',
      idCategorie: idCatAlim,
      prixAchat: 4000.0,
      prixVente: 4600.0,
      stockInitial: 20.0,
    );

    // Article 2: 10 unités à CUMP 2500 Ar = Valeur Stock 25 000 Ar, Prix vente = 3000 Ar
    await stockService.ajouterArticle(
      reference: 'EAU-1L',
      designation: 'Eau Minérale 1L',
      idCategorie: idCatBoi,
      prixAchat: 2500.0,
      prixVente: 3000.0,
      stockInitial: 10.0,
    );
  });

  tearDown(() async {
    await db.close();
    DbHelper.setDatabaseForTesting(null);
  });

  test('KPIs: Valeur de stock, Valeur totale entrée, Valeur totale sortie', () async {
    // 1. Valeur de stock initiale: (20 * 4000) + (10 * 2500) = 80 000 + 25 000 = 105 000 Ar
    final summaryInit = await statsService.getKpiSummary();
    expect(summaryInit.valeurStockActuel, equals(105000.0));
    expect(summaryInit.totalArticles, equals(2));
    expect(summaryInit.totalQuantiteEnStock, equals(30.0));

    // 2. Réaliser un achat de 10 Sucres à 4200 Ar (Entrée en stock = 42 000 Ar)
    final articles = await stockService.getArticles();
    final sucre = articles.firstWhere((a) => a.reference == 'SUCRE-1KG');
    final caisses = await caisseService.getCaisses();
    final caisse = caisses.first;

    await achatService.enregistrerAchat(
      idFournisseur: 1,
      articlesAchetes: [
        LigneAchatInput(
          idArticle: sucre.id,
          designation: sucre.designation,
          quantite: 10.0,
          prixUnitaire: 4200.0,
        ),
      ],
      payeImmediatement: true,
      idCaisse: caisse.id,
      idModePaiement: 1,
    );

    // 3. Réaliser une vente de 5 Sucres à 4600 Ar (Sortie valorisée = 23 000 Ar)
    final clients = await venteService.getClients();
    await venteService.enregistrerVente(
      idClient: clients.first.id,
      articlesVendus: [
        LigneVenteInput(
          idArticle: sucre.id,
          designation: sucre.designation,
          quantite: 5.0,
          prixUnitaire: 4600.0,
        ),
      ],
      payeImmediatement: true,
      idCaisse: caisse.id,
      idModePaiement: 1,
    );

    // 4. Vérifier les KPIs
    final summary = await statsService.getKpiSummary();
    expect(summary.valeurTotaleEntrees, greaterThanOrEqualTo(42000.0));
    expect(summary.valeurTotaleSorties, greaterThanOrEqualTo(23000.0));
    expect(summary.valeurStockActuel, greaterThan(0.0));
    expect(summary.totalAchats, greaterThanOrEqualTo(42000.0));
    expect(summary.totalVentes, greaterThanOrEqualTo(23000.0));
  });

  test('Évolution des ventes: filtrable par catégorie et produit', () async {
    final articles = await stockService.getArticles();
    final sucre = articles.firstWhere((a) => a.reference == 'SUCRE-1KG');
    final eau = articles.firstWhere((a) => a.reference == 'EAU-1L');
    final clients = await venteService.getClients();

    // Vente 1: Sucre
    await venteService.enregistrerVente(
      idClient: clients.first.id,
      articlesVendus: [
        LigneVenteInput(
          idArticle: sucre.id,
          designation: sucre.designation,
          quantite: 3.0,
          prixUnitaire: 4600.0,
        ),
      ],
      payeImmediatement: false,
    );

    // Vente 2: Eau
    await venteService.enregistrerVente(
      idClient: clients.first.id,
      articlesVendus: [
        LigneVenteInput(
          idArticle: eau.id,
          designation: eau.designation,
          quantite: 4.0,
          prixUnitaire: 3000.0,
        ),
      ],
      payeImmediatement: false,
    );

    // A. Évolution globale (Toutes catégories & produits)
    final tous = await statsService.getEvolutionVentes();
    expect(tous.isNotEmpty, isTrue);
    final totalTous = tous.fold<double>(0.0, (sum, p) => sum + p.montant);
    expect(totalTous, equals((3 * 4600.0) + (4 * 3000.0))); // 13800 + 12000 = 25800

    // B. Filtré par catégorie Boissons (idCategorie = eau.idCategorie)
    final boissons = await statsService.getEvolutionVentes(idCategorie: eau.idCategorie);
    expect(boissons.isNotEmpty, isTrue);
    final totalBoissons = boissons.fold<double>(0.0, (sum, p) => sum + p.montant);
    expect(totalBoissons, equals(12000.0));

    // C. Filtré par produit Sucre uniquement
    final sucreOnly = await statsService.getEvolutionVentes(idArticle: sucre.id);
    expect(sucreOnly.isNotEmpty, isTrue);
    final totalSucre = sucreOnly.fold<double>(0.0, (sum, p) => sum + p.montant);
    expect(totalSucre, equals(13800.0));
  });

  test('Dépenses: Achats fournisseurs + Décaissements divers', () async {
    final caisses = await caisseService.getCaisses();
    final caisse = caisses.first;

    // 1. Dépense Achat fournisseur : 50 000 Ar
    await caisseService.enregistrerMouvement(
      idCaisse: caisse.id,
      idTypeMouvement: 2, // DECAISSEMENT_ACHAT
      idModePaiement: 1,
      montant: 50000.0,
      description: 'Achat fournitures',
    );

    // 2. Décaissement divers : 20 000 Ar (DEPENSE_DIVERSE = id 5)
    await caisseService.enregistrerMouvement(
      idCaisse: caisse.id,
      idTypeMouvement: 5, // DEPENSE_DIVERSE
      idModePaiement: 1,
      montant: 20000.0,
      description: 'Facture électricité',
    );

    // 3. Vérification de l'évolution des dépenses
    final evolution = await statsService.getEvolutionDepenses();
    expect(evolution.isNotEmpty, isTrue);
    expect(evolution.first.montantAchats, equals(50000.0));
    expect(evolution.first.montantDepensesDiverses, equals(20000.0));
    expect(evolution.first.total, equals(70000.0));

    // 4. Vérification de la répartition
    final repartition = await statsService.getRepartitionDepenses();
    expect(repartition.length, equals(2));
    final itemAchat = repartition.firstWhere((r) => r.typeCode == 'DECAISSEMENT_ACHAT');
    expect(itemAchat.montant, equals(50000.0));
    expect(itemAchat.pourcentage, closeTo(71.42, 0.5));
  });
}
