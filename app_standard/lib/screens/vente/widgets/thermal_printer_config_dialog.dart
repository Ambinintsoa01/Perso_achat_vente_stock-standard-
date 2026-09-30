import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../models/thermal_printer_settings.dart';
import '../../../services/thermal_printer_service.dart';
import '../../../theme/app_theme.dart';

class ThermalPrinterConfigDialog extends StatefulWidget {
  const ThermalPrinterConfigDialog({super.key});

  @override
  State<ThermalPrinterConfigDialog> createState() => _ThermalPrinterConfigDialogState();
}

class _ThermalPrinterConfigDialogState extends State<ThermalPrinterConfigDialog> {
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _sloganController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nifController = TextEditingController();
  final _statController = TextEditingController();
  final _footerController = TextEditingController();

  int _paperWidth = 80;
  bool _autoPrintOnSale = false;
  bool _directPrint = false;
  bool _showQrCode = true;
  String? _selectedPrinterName;

  List<Printer> _availablePrinters = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettingsAndPrinters();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _sloganController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nifController.dispose();
    _statController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndPrinters() async {
    setState(() => _isLoading = true);
    final settings = await ThermalPrinterService.instance.getSettings();
    final printers = await ThermalPrinterService.instance.getAvailablePrinters();

    if (mounted) {
      setState(() {
        _storeNameController.text = settings.storeName;
        _sloganController.text = settings.slogan;
        _addressController.text = settings.address;
        _phoneController.text = settings.phone;
        _emailController.text = settings.email;
        _nifController.text = settings.nif;
        _statController.text = settings.stat;
        _footerController.text = settings.footerMessage;

        _paperWidth = settings.paperWidth;
        _autoPrintOnSale = settings.autoPrintOnSale;
        _directPrint = settings.directPrint;
        _showQrCode = settings.showQrCode;
        _selectedPrinterName = settings.selectedPrinterName;

        _availablePrinters = printers;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshPrinters() async {
    final printers = await ThermalPrinterService.instance.getAvailablePrinters();
    if (mounted) {
      setState(() {
        _availablePrinters = printers;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${printers.length} imprimante(s) détectée(s)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updated = ThermalPrinterSettings(
        storeName: _storeNameController.text.trim().isEmpty ? 'MON COMMERCE' : _storeNameController.text.trim(),
        slogan: _sloganController.text.trim(),
        address: _addressController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        nif: _nifController.text.trim(),
        stat: _statController.text.trim(),
        footerMessage: _footerController.text.trim(),
        paperWidth: _paperWidth,
        autoPrintOnSale: _autoPrintOnSale,
        directPrint: _directPrint,
        selectedPrinterName: _selectedPrinterName,
        showQrCode: _showQrCode,
      );

      await ThermalPrinterService.instance.saveSettings(updated);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Paramètres d\'impression thermique enregistrés !'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testerImpression() async {
    final tempSettings = ThermalPrinterSettings(
      storeName: _storeNameController.text.trim().isEmpty ? 'MON COMMERCE' : _storeNameController.text.trim(),
      slogan: _sloganController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      nif: _nifController.text.trim(),
      stat: _statController.text.trim(),
      footerMessage: _footerController.text.trim(),
      paperWidth: _paperWidth,
      autoPrintOnSale: _autoPrintOnSale,
      directPrint: _directPrint,
      selectedPrinterName: _selectedPrinterName,
      showQrCode: _showQrCode,
    );

    await ThermalPrinterService.instance.saveSettings(tempSettings);
    if (!mounted) return;
    await ThermalPrinterService.instance.printTestTicket(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: Colors.black)),
              )
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // En-tête
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.print_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'IMPRIMANTE THERMIQUE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Facturation, tickets de caisse & format rouleau',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Corps avec scroll
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Format papier (80mm vs 58mm)
                            const Text(
                              'LARGEUR DU PAPIER THERMIQUE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildPaperWidthOption(
                                    title: '80 mm',
                                    subtitle: 'Standard caisse POS',
                                    width: 80,
                                    icon: Icons.receipt_long_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildPaperWidthOption(
                                    title: '58 mm',
                                    subtitle: 'Compact / Portable',
                                    width: 58,
                                    icon: Icons.receipt_rounded,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),

                            // 2. Sélection de l'imprimante
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'IMPRIMANTE SYSTÈME',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _refreshPrinters,
                                  icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.black87),
                                  label: const Text('Actualiser', style: TextStyle(fontSize: 11, color: Colors.black87)),
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: _selectedPrinterName,
                              decoration: InputDecoration(
                                hintText: 'Sélectionner l\'imprimante thermique',
                                prefixIcon: const Icon(Icons.local_printshop_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Toujours demander (Boîte système)', style: TextStyle(fontSize: 12)),
                                ),
                                ..._availablePrinters.map(
                                  (p) => DropdownMenuItem<String?>(
                                    value: p.name,
                                    child: Text(
                                      '${p.name} ${p.isDefault ? "(Par défaut)" : ""}',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedPrinterName = val);
                              },
                            ),

                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),

                            // 3. Options d'automatisation
                            const Text(
                              'AUTOMATISATION & OPTIONS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Impression automatique après vente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Lance le ticket dès la validation de la commande', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              value: _autoPrintOnSale,
                              activeThumbColor: Colors.black,
                              onChanged: (val) => setState(() => _autoPrintOnSale = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Impression directe (sans dialogue)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Imprime instantanément sans ouvrir l\'aperçu système', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              value: _directPrint,
                              activeThumbColor: Colors.black,
                              onChanged: _selectedPrinterName == null
                                  ? null
                                  : (val) => setState(() => _directPrint = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Afficher le QR Code sur le ticket', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: const Text('Permet de scanner la référence de vente rapidement', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              value: _showQrCode,
                              activeThumbColor: Colors.black,
                              onChanged: (val) => setState(() => _showQrCode = val),
                            ),

                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 12),

                            // 4. Coordonnées de l'établissement
                            const Text(
                              'INFORMATIONS DU MAGASIN / FACTURATION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _storeNameController,
                              decoration: InputDecoration(
                                labelText: 'Nom du magasin / Entreprise *',
                                prefixIcon: const Icon(Icons.storefront_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (val) => (val == null || val.trim().isEmpty) ? 'Requis' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _sloganController,
                              decoration: InputDecoration(
                                labelText: 'Slogan / Activité (ex: Vente de gros & détail)',
                                prefixIcon: const Icon(Icons.subtitles_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _addressController,
                                    decoration: InputDecoration(
                                      labelText: 'Adresse',
                                      prefixIcon: const Icon(Icons.place_rounded, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    decoration: InputDecoration(
                                      labelText: 'Téléphone',
                                      prefixIcon: const Icon(Icons.phone_rounded, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _nifController,
                                    decoration: InputDecoration(
                                      labelText: 'NIF (optionnel)',
                                      prefixIcon: const Icon(Icons.badge_rounded, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _statController,
                                    decoration: InputDecoration(
                                      labelText: 'STAT (optionnel)',
                                      prefixIcon: const Icon(Icons.numbers_rounded, size: 18),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _footerController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Pied de ticket / Message de remerciement',
                                prefixIcon: const Icon(Icons.notes_rounded, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pied avec actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                      ),
                      child: Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _testerImpression,
                            icon: const Icon(Icons.print_outlined, size: 16),
                            label: const Text('TESTER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ANNULER', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _sauvegarder,
                            icon: _isSaving
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_rounded, size: 16),
                            label: const Text('ENREGISTRER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPaperWidthOption({
    required String title,
    required String subtitle,
    required int width,
    required IconData icon,
  }) {
    final isSelected = _paperWidth == width;
    return InkWell(
      onTap: () => setState(() => _paperWidth = width),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.black87),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check, size: 12, color: Colors.black),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
