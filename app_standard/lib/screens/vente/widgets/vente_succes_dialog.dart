import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/client.dart';
import '../../../models/commande_vente.dart';
import '../../../models/thermal_printer_settings.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../theme/app_theme.dart';

class VenteSuccesDialog extends StatefulWidget {
  final CommandeVente commande;
  final List<CommandeVenteLigne> lignes;
  final Client? client;
  final String? caissierNom;
  final String? modePaiementNom;
  final double? montantRecu;
  final VoidCallback onNouvelleVente;
  final VoidCallback onFermer;

  const VenteSuccesDialog({
    super.key,
    required this.commande,
    required this.lignes,
    this.client,
    this.caissierNom,
    this.modePaiementNom,
    this.montantRecu,
    required this.onNouvelleVente,
    required this.onFermer,
  });

  @override
  State<VenteSuccesDialog> createState() => _VenteSuccesDialogState();
}

class _VenteSuccesDialogState extends State<VenteSuccesDialog> {
  bool _isPrinting = false;
  bool _autoPrinted = false;
  ThermalPrinterSettings? _settings;

  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _checkAutoPrint();
  }

  Future<void> _checkAutoPrint() async {
    final settings = await ThermalPrinterService.instance.getSettings();
    if (mounted) {
      setState(() => _settings = settings);
    }
    if (settings.autoPrintOnSale) {
      _imprimerTicket(forceDialog: false);
      if (mounted) setState(() => _autoPrinted = true);
    }
  }

  Future<void> _imprimerTicket({bool forceDialog = false}) async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    try {
      await ThermalPrinterService.instance.printTicket(
        context: context,
        commande: widget.commande,
        lignes: widget.lignes,
        client: widget.client,
        caissierNom: widget.caissierNom,
        modePaiementNom: widget.modePaiementNom,
        montantRecu: widget.montantRecu,
        forceDialog: forceDialog,
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _partagerPdf() async {
    await ThermalPrinterService.instance.shareTicket(
      commande: widget.commande,
      lignes: widget.lignes,
      client: widget.client,
      caissierNom: widget.caissierNom,
      modePaiementNom: widget.modePaiementNom,
      montantRecu: widget.montantRecu,
    );
  }

  @override
  Widget build(BuildContext context) {
    final commande = widget.commande;
    final isPaye = commande.estPaye;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge de confirmation
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isPaye ? AppTheme.successBg : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaye ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 34,
                  color: isPaye ? AppTheme.success : const Color(0xFFD97706),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                isPaye ? 'VENTE ENCAISSÉE !' : 'VENTE À CRÉDIT VALIDÉE',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                commande.numeroCommande,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 14),

              // Carte Noire de Synthèse (Charte graphique Règle 2)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL DE LA VENTE',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPaye ? 'ACQUITTÉ' : 'CRÉANCE',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currencyFormatter.format(commande.montantTtc),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'Client : ${commande.clientNom ?? "Client Comptoir"}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${widget.lignes.length} article(s)',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (_autoPrinted)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.print_rounded, size: 14, color: AppTheme.success),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ticket thermique envoyé à l\'imprimante',
                          style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),

              // Bouton Principal : Imprimer le ticket thermique
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPrinting ? null : () => _imprimerTicket(forceDialog: false),
                  icon: _isPrinting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.receipt_long_rounded, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _isPrinting
                          ? 'IMPRESSION EN COURS...'
                          : 'IMPRIMER LE TICKET THERMIQUE (${_settings?.paperWidth ?? 80}mm)',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Boutons secondaires : Aperçu système / Partager PDF
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _imprimerTicket(forceDialog: true),
                      icon: const Icon(Icons.preview_rounded, size: 15),
                      label: const Text('APERÇU / DIALOGUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _partagerPdf,
                      icon: const Icon(Icons.share_rounded, size: 15),
                      label: const Text('PARTAGER PDF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Navigation : Nouvelle vente ou Fermer
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onFermer,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'RETOUR À LA LISTE',
                        style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.onNouvelleVente,
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                      label: const Text('NOUVELLE VENTE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
