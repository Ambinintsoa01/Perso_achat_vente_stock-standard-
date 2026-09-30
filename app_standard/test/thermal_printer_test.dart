import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_standard/database/db_helper.dart';
import 'package:app_standard/models/commande_vente.dart';
import 'package:app_standard/models/thermal_printer_settings.dart';
import 'package:app_standard/screens/vente/widgets/commande_vente_card.dart';
import 'package:app_standard/screens/vente/widgets/thermal_printer_config_dialog.dart';
import 'package:app_standard/screens/vente/widgets/vente_succes_dialog.dart';
import 'package:app_standard/services/caisse_service.dart';
import 'package:app_standard/services/stock_service.dart';
import 'package:app_standard/services/thermal_printer_service.dart';
import 'package:app_standard/services/vente_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('ThermalPrinterSettings tests', () {
    test('Default values are correct and helpers return expected widths', () {
      const settings = ThermalPrinterSettings();
      expect(settings.storeName, 'MON COMMERCE');
      expect(settings.paperWidth, 80);
      expect(settings.is80mm, isTrue);
      expect(settings.is58mm, isFalse);
      expect(settings.showQrCode, isTrue);
      expect(settings.autoPrintOnSale, isFalse);
      expect(settings.directPrint, isFalse);
    });

    test('Serialization toMap and fromMap works seamlessly', () {
      final original = const ThermalPrinterSettings().copyWith(
        storeName: 'SUPERMARCHE TSARA',
        slogan: 'Le meilleur choix',
        address: 'Analakely, Antananarivo',
        phone: '034 11 222 33',
        nif: '123456789',
        stat: '987654321',
        paperWidth: 58,
        autoPrintOnSale: true,
        directPrint: true,
        selectedPrinterName: 'POS-58',
      );

      final map = original.toMap();
      final restored = ThermalPrinterSettings.fromMap(map);

      expect(restored.storeName, 'SUPERMARCHE TSARA');
      expect(restored.slogan, 'Le meilleur choix');
      expect(restored.address, 'Analakely, Antananarivo');
      expect(restored.phone, '034 11 222 33');
      expect(restored.nif, '123456789');
      expect(restored.stat, '987654321');
      expect(restored.paperWidth, 58);
      expect(restored.is58mm, isTrue);
      expect(restored.autoPrintOnSale, isTrue);
      expect(restored.directPrint, isTrue);
      expect(restored.selectedPrinterName, 'POS-58');
    });

    test('SharedPreferences persistence saves and loads settings', () async {
      SharedPreferences.setMockInitialValues({});

      final settingsToSave = const ThermalPrinterSettings().copyWith(
        storeName: 'BOUTIQUE CENTRALE',
        paperWidth: 58,
        autoPrintOnSale: true,
      );

      await settingsToSave.saveToPrefs();
      final loaded = await ThermalPrinterSettings.loadFromPrefs();

      expect(loaded.storeName, 'BOUTIQUE CENTRALE');
      expect(loaded.paperWidth, 58);
      expect(loaded.autoPrintOnSale, isTrue);
    });
  });

  group('ThermalPrinterService PDF generation tests', () {
    final sampleCommande = CommandeVente(
      id: 101,
      numeroCommande: 'BCV-9876543',
      idClient: 1,
      clientNom: 'Rakoto Jean',
      idStatut: 5,
      dateCommande: '2026-09-30 10:15',
      montantHt: 45000.0,
      montantTva: 0.0,
      montantTtc: 45000.0,
      lignesCount: 2,
      estPaye: true,
      montantPaye: 45000.0,
      resteAPayer: 0.0,
      idFacture: 201,
      numeroFacture: 'FC-9876543',
    );

    final sampleLignes = [
      CommandeVenteLigne(
        id: 1,
        idCommandeVente: 101,
        idArticle: 1,
        articleDesignation: 'Riz Blanc Makalioka 5kg',
        quantite: 2,
        prixUnitaire: 15000.0,
        tauxRemise: 0.0,
        montantHt: 30000.0,
        montantTtc: 30000.0,
      ),
      CommandeVenteLigne(
        id: 2,
        idCommandeVente: 101,
        idArticle: 2,
        articleDesignation: 'Huile de Tournesol 1L',
        quantite: 1,
        prixUnitaire: 15000.0,
        tauxRemise: 0.0,
        montantHt: 15000.0,
        montantTtc: 15000.0,
      ),
    ];

    test('generateReceiptPdf produces valid PDF bytes for 80mm roll format', () async {
      final service = ThermalPrinterService.instance;
      const settings80 = ThermalPrinterSettings(
        storeName: 'PERSO MEGA STORE',
        paperWidth: 80,
        showQrCode: true,
      );

      final pdfBytes = await service.generateReceiptPdf(
        commande: sampleCommande,
        lignes: sampleLignes,
        settings: settings80,
        caissierNom: 'Rasoa Fanjatiana',
        modePaiementNom: 'Espèces / Cash',
        montantRecu: 50000.0,
      );

      expect(pdfBytes, isNotEmpty);
      // Les fichiers PDF commencent par le header '%PDF'
      final header = utf8.decode(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });

    test('generateReceiptPdf produces valid PDF bytes for 58mm compact roll format', () async {
      final service = ThermalPrinterService.instance;
      const settings58 = ThermalPrinterSettings(
        storeName: 'MINI SHOP 58',
        paperWidth: 58,
        showQrCode: true,
      );

      final pdfBytes = await service.generateReceiptPdf(
        commande: sampleCommande,
        lignes: sampleLignes,
        settings: settings58,
        caissierNom: 'Rasoa',
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });

    test('generateReceiptPdf produces valid PDF for unpaid / credit sales', () async {
      final service = ThermalPrinterService.instance;
      final creditCommande = CommandeVente(
        id: 102,
        numeroCommande: 'BCV-CREDIT-01',
        idClient: 2,
        clientNom: 'Client Entreprise',
        idStatut: 2,
        dateCommande: '2026-09-30',
        montantHt: 100000.0,
        montantTva: 0.0,
        montantTtc: 100000.0,
        lignesCount: 1,
        estPaye: false,
        montantPaye: 30000.0,
        resteAPayer: 70000.0,
      );

      final pdfBytes = await service.generateReceiptPdf(
        commande: creditCommande,
        lignes: [sampleLignes.first],
      );

      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });

    test('generateTestTicketPdf generates valid test ticket PDF bytes', () async {
      final service = ThermalPrinterService.instance;
      const settings = ThermalPrinterSettings(
        storeName: 'TEST STORE',
        paperWidth: 80,
      );

      final pdfBytes = await service.generateTestTicketPdf(settings);
      expect(pdfBytes, isNotEmpty);
      final header = utf8.decode(pdfBytes.sublist(0, 4));
      expect(header, '%PDF');
    });
  });

  group('VenteService getCommandeById and getPaiementsCommande tests', () {
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

      final idCat = await stockService.ajouterCategorie(code: 'EPICERIE', nom: 'Épicerie');
      await stockService.ajouterArticle(
        reference: 'ART-TEST-TH',
        designation: 'Café Moulu 250g',
        idCategorie: idCat,
        prixAchat: 2500.0,
        prixVente: 3500.0,
        stockInitial: 50.0,
      );
    });

    tearDown(() async {
      await db.close();
      DbHelper.setDatabaseForTesting(null);
    });

    test('Enregistrer vente then getCommandeById retrieves invoice and payment info', () async {
      final articles = await stockService.getArticles();
      final article = articles.firstWhere((a) => a.reference == 'ART-TEST-TH');
      final clients = await venteService.getClients();
      final client = clients.first;
      final caisses = await caisseService.getCaisses();
      final caisse = caisses.first;

      final idCmd = await venteService.enregistrerVente(
        idClient: client.id,
        articlesVendus: [
          LigneVenteInput(
            idArticle: article.id,
            designation: article.designation,
            quantite: 3,
            prixUnitaire: 3500.0,
          ),
        ],
        payeImmediatement: true,
        idCaisse: caisse.id,
        idModePaiement: 1,
      );

      final fetchedCmd = await venteService.getCommandeById(idCmd);
      expect(fetchedCmd, isNotNull);
      expect(fetchedCmd!.numeroCommande.startsWith('BCV-'), isTrue);
      expect(fetchedCmd.montantTtc, 10500.0);
      expect(fetchedCmd.estPaye, isTrue);
      expect(fetchedCmd.idFacture, isNotNull);
      expect(fetchedCmd.numeroFacture?.startsWith('FC-'), isTrue);

      final paiements = await venteService.getPaiementsCommande(idCmd);
      expect(paiements, isNotEmpty);
      expect(paiements.first['montant'], 10500.0);
      expect(paiements.first['mode_paiement_libelle'], 'Espèces / Cash');
    });
  });

  group('Thermal Printing UI Widgets tests', () {
    testWidgets('CommandeVenteCard displays print button and triggers onPrint', (tester) async {
      bool printTriggered = false;

      final commande = CommandeVente(
        id: 1,
        numeroCommande: 'BCV-1234',
        idClient: 1,
        clientNom: 'Client Test',
        idStatut: 5,
        dateCommande: '2026-09-30',
        montantHt: 20000.0,
        montantTva: 0.0,
        montantTtc: 20000.0,
        lignesCount: 1,
        estPaye: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CommandeVenteCard(
              commande: commande,
              onPrint: () => printTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('BCV-1234'), findsOneWidget);
      expect(find.byIcon(Icons.print_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.print_outlined));
      await tester.pump();

      expect(printTriggered, isTrue);
    });

    testWidgets('VenteSuccesDialog renders with thermal print and navigation options', (tester) async {
      ThermalPrinterService.resetForTesting();
      SharedPreferences.setMockInitialValues({'tp_auto_print': false});
      bool nouvelleVenteTriggered = false;
      bool fermerTriggered = false;

      final commande = CommandeVente(
        id: 1,
        numeroCommande: 'BCV-777',
        idClient: 1,
        clientNom: 'Rakoto',
        idStatut: 5,
        dateCommande: '2026-09-30',
        montantHt: 15000.0,
        montantTva: 0.0,
        montantTtc: 15000.0,
        lignesCount: 1,
        estPaye: true,
        idFacture: 10,
        numeroFacture: 'FC-777',
      );

      final lignes = [
        CommandeVenteLigne(
          id: 1,
          idCommandeVente: 1,
          idArticle: 1,
          articleDesignation: 'Huile',
          quantite: 1,
          prixUnitaire: 15000.0,
          montantHt: 15000.0,
          montantTtc: 15000.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VenteSuccesDialog(
              commande: commande,
              lignes: lignes,
              onNouvelleVente: () => nouvelleVenteTriggered = true,
              onFermer: () => fermerTriggered = true,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('VENTE ENCAISSÉE !'), findsOneWidget);
      expect(find.text('BCV-777'), findsOneWidget);
      expect(find.textContaining('IMPRIMER LE TICKET THERMIQUE'), findsOneWidget);
      expect(find.text('NOUVELLE VENTE'), findsOneWidget);
      expect(find.text('RETOUR À LA LISTE'), findsOneWidget);

      await tester.tap(find.text('NOUVELLE VENTE'));
      expect(nouvelleVenteTriggered, isTrue);

      await tester.tap(find.text('RETOUR À LA LISTE'));
      expect(fermerTriggered, isTrue);
    });

    testWidgets('ThermalPrinterConfigDialog renders properly and displays paper width options', (tester) async {
      ThermalPrinterService.resetForTesting();
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ThermalPrinterConfigDialog(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text('IMPRIMANTE THERMIQUE'), findsOneWidget);
      expect(find.text('80 mm'), findsOneWidget);
      expect(find.text('58 mm'), findsOneWidget);
      expect(find.text('TESTER'), findsOneWidget);
      expect(find.text('ENREGISTRER'), findsOneWidget);
    });
  });
}
