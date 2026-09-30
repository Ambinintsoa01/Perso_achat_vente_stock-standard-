import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/client.dart';
import '../models/commande_vente.dart';
import '../models/thermal_printer_settings.dart';
import '../theme/app_theme.dart';

class ThermalPrinterService {
  static final ThermalPrinterService instance = ThermalPrinterService._internal();

  ThermalPrinterService._internal();

  ThermalPrinterSettings? _cachedSettings;

  @visibleForTesting
  static void resetForTesting() {
    instance._cachedSettings = null;
  }

  /// Récupérer les paramètres actuels d'impression thermique
  Future<ThermalPrinterSettings> getSettings() async {
    _cachedSettings ??= await ThermalPrinterSettings.loadFromPrefs();
    return _cachedSettings!;
  }

  /// Sauvegarder les paramètres d'impression thermique
  Future<void> saveSettings(ThermalPrinterSettings settings) async {
    _cachedSettings = settings;
    await settings.saveToPrefs();
  }

  /// Obtenir la liste des imprimantes disponibles sur le système
  Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters().timeout(
        const Duration(milliseconds: 800),
        onTimeout: () => [],
      );
    } catch (e) {
      debugPrint('Erreur lors de la détection des imprimantes: $e');
      return [];
    }
  }

  /// Formateur monétaire pour les montants du ticket
  static final NumberFormat currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  /// Génère le document PDF formaté pour imprimante thermique (80mm ou 58mm)
  Future<Uint8List> generateReceiptPdf({
    required CommandeVente commande,
    required List<CommandeVenteLigne> lignes,
    ThermalPrinterSettings? settings,
    Client? client,
    String? caissierNom,
    String? modePaiementNom,
    double? montantRecu,
  }) async {
    final s = settings ?? await getSettings();
    final is58 = s.is58mm;

    // Définition du format de page thermique
    final rollWidth = (is58 ? 58.0 : 80.0) * PdfPageFormat.mm;
    final pageMargin = (is58 ? 3.0 : 4.0) * PdfPageFormat.mm;

    // Fonts standard 14 (intégrées au standard PDF, pas de chargement réseau requis)
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final doc = pw.Document();

    final isSolde = commande.estPaye;
    final totalTtc = commande.montantTtc;
    final montantPaye = commande.montantPaye > 0 ? commande.montantPaye : (isSolde ? totalTtc : 0.0);
    final resteAPayer = commande.resteAPayer;

    // Date de la vente
    String dateAffichee = commande.dateCommande;
    if (!dateAffichee.contains(':')) {
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm').format(now);
      dateAffichee = '$dateAffichee $timeStr';
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          rollWidth,
          double.infinity,
          marginLeft: pageMargin,
          marginRight: pageMargin,
          marginTop: pageMargin,
          marginBottom: pageMargin + 10 * PdfPageFormat.mm, // Marge de fin pour la découpe
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. En-tête de la boutique / entreprise
              pw.Text(
                s.storeName.toUpperCase(),
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: is58 ? 12.0 : 14.0,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (s.slogan.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  s.slogan,
                  style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 7.5 : 8.5),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (s.address.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  s.address,
                  style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 7.0 : 8.0),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (s.phone.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Tél : ${s.phone}',
                  style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 7.0 : 8.0),
                  textAlign: pw.TextAlign.center,
                ),
              ],
              if (s.nif.isNotEmpty || s.stat.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  [
                    if (s.nif.isNotEmpty) 'NIF: ${s.nif}',
                    if (s.stat.isNotEmpty) 'STAT: ${s.stat}',
                  ].join(' | '),
                  style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 6.5 : 7.5),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              // Ligne de séparation
              _buildDashedLine(is58: is58, font: fontRegular),

              // 2. Type de document & Numéro
              pw.Text(
                isSolde ? 'FACTURE / TICKET DE CAISSE' : 'FACTURE VENTE (CRÉANCE)',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: is58 ? 9.5 : 10.5,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
                child: pw.Text(
                  isSolde ? 'ACQUITTÉE' : 'NON SOLDÉE / CRÉANCE',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: is58 ? 7.5 : 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              // Métadonnées : Référence, Date, Caissier, Client
              _buildMetaRow('N° Commande :', commande.numeroCommande, fontRegular, fontBold, is58),
              if (commande.numeroFacture != null && commande.numeroFacture!.isNotEmpty)
                _buildMetaRow('N° Facture :', commande.numeroFacture!, fontRegular, fontBold, is58),
              _buildMetaRow('Date :', dateAffichee, fontRegular, fontBold, is58),
              if (caissierNom != null && caissierNom.isNotEmpty)
                _buildMetaRow('Caissier :', caissierNom, fontRegular, fontBold, is58),
              _buildMetaRow(
                'Client :',
                commande.clientNom ?? client?.nomComplet ?? 'Client Comptoir',
                fontRegular,
                fontBold,
                is58,
              ),
              if (client?.telephone != null && client!.telephone!.isNotEmpty)
                _buildMetaRow('Tél Client :', client.telephone!, fontRegular, fontBold, is58),

              // Ligne de séparation
              _buildDashedLine(is58: is58, font: fontRegular),

              // 3. Titres de colonnes des articles
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('DÉSIGNATION', style: pw.TextStyle(font: fontBold, fontSize: is58 ? 7.5 : 8.5)),
                  pw.Text('TOTAL', style: pw.TextStyle(font: fontBold, fontSize: is58 ? 7.5 : 8.5)),
                ],
              ),
              pw.SizedBox(height: 3),

              // Lignes des articles vendus
              ...lignes.map((l) {
                final qteStr = l.quantite % 1 == 0 ? l.quantite.toInt().toString() : l.quantite.toStringAsFixed(2);
                final remiseStr = l.tauxRemise > 0 ? ' (-${l.tauxRemise.toStringAsFixed(0)}%)' : '';
                final detailStr = '$qteStr x ${currencyFormatter.format(l.prixUnitaire)}$remiseStr';

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        l.articleDesignation ?? 'Article',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: is58 ? 7.5 : 8.5,
                        ),
                      ),
                      pw.SizedBox(height: 1),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            detailStr,
                            style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 7.0 : 8.0),
                          ),
                          pw.Text(
                            currencyFormatter.format(l.montantTtc),
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: is58 ? 7.5 : 8.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              // Ligne de séparation
              _buildDashedLine(is58: is58, font: fontRegular),

              // 4. Totaux & Règlements
              _buildSummaryRow(
                'Articles (${lignes.length}) :',
                currencyFormatter.format(commande.montantHt),
                fontRegular,
                fontRegular,
                is58,
              ),

              pw.SizedBox(height: 3),

              // Encadré Grand Total TTC
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 3),
                padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.black, width: 1.0),
                    bottom: pw.BorderSide(color: PdfColors.black, width: 1.0),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'TOTAL TTC',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: is58 ? 10.5 : 12.0,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      currencyFormatter.format(totalTtc),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: is58 ? 10.5 : 12.0,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 3),

              // Détails de paiement
              if (modePaiementNom != null && modePaiementNom.isNotEmpty)
                _buildSummaryRow('Mode de règlement :', modePaiementNom, fontRegular, fontRegular, is58),

              _buildSummaryRow(
                'Montant payé :',
                currencyFormatter.format(montantPaye),
                fontRegular,
                fontBold,
                is58,
              ),

              if (montantRecu != null && montantRecu > totalTtc) ...[
                _buildSummaryRow('Montant remis :', currencyFormatter.format(montantRecu), fontRegular, fontRegular, is58),
                _buildSummaryRow('Monnaie rendue :', currencyFormatter.format(montantRecu - totalTtc), fontBold, fontBold, is58),
              ],

              if (!isSolde && resteAPayer > 0) ...[
                pw.SizedBox(height: 2),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  color: PdfColors.grey200,
                  child: _buildSummaryRow(
                    'RESTE À PAYER :',
                    currencyFormatter.format(resteAPayer),
                    fontBold,
                    fontBold,
                    is58,
                  ),
                ),
              ],

              // 5. Code QR ou Code-barres pour identification rapide
              if (s.showQrCode || s.showBarcode) ...[
                _buildDashedLine(is58: is58, font: fontRegular),
                pw.Container(
                  alignment: pw.Alignment.center,
                  child: s.showQrCode
                      ? pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: commande.numeroCommande,
                          width: is58 ? 50.0 : 65.0,
                          height: is58 ? 50.0 : 65.0,
                        )
                      : pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: commande.numeroCommande,
                          width: is58 ? 110.0 : 150.0,
                          height: 30.0,
                        ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  commande.numeroCommande,
                  style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 6.5 : 7.5),
                  textAlign: pw.TextAlign.center,
                ),
              ],

              // 6. Pied de ticket
              _buildDashedLine(is58: is58, font: fontRegular),
              if (s.footerMessage.isNotEmpty)
                pw.Text(
                  s.footerMessage,
                  style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 7.0 : 8.0),
                  textAlign: pw.TextAlign.center,
                ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Logiciel de Gestion Commerciale & Caisse',
                style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 6.0 : 7.0, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),

              // Espace pour découpe papier thermique
              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  /// Génère un ticket thermique de test pour tester la largeur et la connectivité de l'imprimante
  Future<Uint8List> generateTestTicketPdf(ThermalPrinterSettings settings) async {
    final is58 = settings.is58mm;
    final rollWidth = (is58 ? 58.0 : 80.0) * PdfPageFormat.mm;
    final pageMargin = (is58 ? 3.0 : 4.0) * PdfPageFormat.mm;

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          rollWidth,
          double.infinity,
          marginLeft: pageMargin,
          marginRight: pageMargin,
          marginTop: pageMargin,
          marginBottom: pageMargin + 10 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                settings.storeName.toUpperCase(),
                style: pw.TextStyle(font: fontBold, fontSize: is58 ? 12.0 : 14.0),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                '*** TICKET DE TEST IMPRIMANTE ***',
                style: pw.TextStyle(font: fontBold, fontSize: is58 ? 8.5 : 9.5),
                textAlign: pw.TextAlign.center,
              ),
              _buildDashedLine(is58: is58, font: fontRegular),
              _buildMetaRow('Format configuré :', is58 ? '58 mm (Compact)' : '80 mm (Standard)', fontRegular, fontBold, is58),
              _buildMetaRow('Date & Heure :', DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()), fontRegular, fontBold, is58),
              _buildMetaRow('Imprimante :', settings.selectedPrinterName ?? 'Imprimante par défaut OS', fontRegular, fontBold, is58),
              _buildDashedLine(is58: is58, font: fontRegular),
              pw.Text('Exemple de ligne d\'article :', style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 7.5 : 8.5)),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Article Démonstration Test', style: pw.TextStyle(font: fontBold, fontSize: is58 ? 7.5 : 8.5)),
                  pw.Text('15 000 Ar', style: pw.TextStyle(font: fontBold, fontSize: is58 ? 7.5 : 8.5)),
                ],
              ),
              _buildDashedLine(is58: is58, font: fontRegular),
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'TEST-PRINT-SUCCESS',
                  width: is58 ? 50.0 : 60.0,
                  height: is58 ? 50.0 : 60.0,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Configuration imprimante thermique réussie !',
                style: pw.TextStyle(font: fontBold, fontSize: is58 ? 7.5 : 8.5),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 15),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  /// Lancement de l'impression thermique d'une vente
  Future<bool> printTicket({
    required BuildContext context,
    required CommandeVente commande,
    required List<CommandeVenteLigne> lignes,
    Client? client,
    String? caissierNom,
    String? modePaiementNom,
    double? montantRecu,
    bool forceDialog = false,
  }) async {
    final settings = await getSettings();
    final is58 = settings.is58mm;
    final rollFormat = is58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

    final pdfBytes = await generateReceiptPdf(
      commande: commande,
      lignes: lignes,
      settings: settings,
      client: client,
      caissierNom: caissierNom,
      modePaiementNom: modePaiementNom,
      montantRecu: montantRecu,
    );

    try {
      // Si impression directe configurée et nom d'imprimante renseigné sans forcer la boîte de dialogue
      if (!forceDialog && settings.directPrint && settings.selectedPrinterName != null) {
        final printers = await getAvailablePrinters();
        final targetPrinter = printers.where((p) => p.name == settings.selectedPrinterName).firstOrNull;

        if (targetPrinter != null) {
          final success = await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'Ticket_${commande.numeroCommande}',
            format: rollFormat,
          );
          return success;
        }
      }

      // Par défaut ou si l'imprimante directe n'est pas trouvée : dialogue standard
      final result = await Printing.layoutPdf(
        name: 'Ticket_${commande.numeroCommande}',
        format: rollFormat,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      return result;
    } catch (e) {
      debugPrint('Erreur d\'impression thermique: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Erreur lors de l\'impression : $e'),
          ),
        );
      }
      return false;
    }
  }

  /// Impression d'un ticket de test
  Future<void> printTestTicket({required BuildContext context}) async {
    final settings = await getSettings();
    final is58 = settings.is58mm;
    final rollFormat = is58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80;

    try {
      final pdfBytes = await generateTestTicketPdf(settings);

      if (settings.directPrint && settings.selectedPrinterName != null) {
        final printers = await getAvailablePrinters();
        final target = printers.where((p) => p.name == settings.selectedPrinterName).firstOrNull;
        if (target != null) {
          await Printing.directPrintPdf(
            printer: target,
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'Ticket_Test',
            format: rollFormat,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppTheme.darkCard,
                content: Text('Ticket de test envoyé à l\'imprimante !'),
              ),
            );
          }
          return;
        }
      }

      await Printing.layoutPdf(
        name: 'Ticket_Test',
        format: rollFormat,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            content: Text('Erreur ticket test : $e'),
          ),
        );
      }
    }
  }

  /// Partager ou sauvegarder le ticket au format PDF
  Future<void> shareTicket({
    required CommandeVente commande,
    required List<CommandeVenteLigne> lignes,
    Client? client,
    String? caissierNom,
    String? modePaiementNom,
    double? montantRecu,
  }) async {
    final settings = await getSettings();
    final pdfBytes = await generateReceiptPdf(
      commande: commande,
      lignes: lignes,
      settings: settings,
      client: client,
      caissierNom: caissierNom,
      modePaiementNom: modePaiementNom,
      montantRecu: montantRecu,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Ticket_${commande.numeroCommande}.pdf',
    );
  }

  // Helpers de rendu pour les lignes du ticket
  pw.Widget _buildDashedLine({required bool is58, required pw.Font font}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.0),
      child: pw.Text(
        '-' * (is58 ? 32 : 46),
        style: pw.TextStyle(font: font, fontSize: 8.0, color: PdfColors.grey800),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildMetaRow(String label, String value, pw.Font fontRegular, pw.Font fontBold, bool is58) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontRegular, fontSize: is58 ? 7.0 : 8.0)),
          pw.Flexible(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: fontBold, fontSize: is58 ? 7.0 : 8.0),
              textAlign: pw.TextAlign.right,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryRow(String label, String value, pw.Font fontLabel, pw.Font fontValue, bool is58) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: fontLabel, fontSize: is58 ? 7.5 : 8.5)),
          pw.Text(value, style: pw.TextStyle(font: fontValue, fontSize: is58 ? 7.5 : 8.5)),
        ],
      ),
    );
  }
}
