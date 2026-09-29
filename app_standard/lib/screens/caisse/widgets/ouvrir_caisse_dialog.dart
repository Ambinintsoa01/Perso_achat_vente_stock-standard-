import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/caisse.dart';
import '../../../services/auth_service.dart';
import '../../../services/caisse_service.dart';
import '../../../theme/app_theme.dart';

class OuvrirCaisseDialog extends StatefulWidget {
  final List<Caisse> caisses;
  final VoidCallback onSuccess;

  const OuvrirCaisseDialog({
    super.key,
    required this.caisses,
    required this.onSuccess,
  });

  @override
  State<OuvrirCaisseDialog> createState() => _OuvrirCaisseDialogState();
}

class _OuvrirCaisseDialogState extends State<OuvrirCaisseDialog> {
  final CaisseService _caisseService = CaisseService();
  final Map<int, TextEditingController> _controllers = {};
  final TextEditingController _notesController = TextEditingController();
  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  bool _isSaving = false;
  Map<int, double> _soldesSuggeres = {};

  @override
  void initState() {
    super.initState();
    _chargerSoldesSuggeres();
  }

  Future<void> _chargerSoldesSuggeres() async {
    try {
      final suggeres = await _caisseService.getSoldesOuvertureSuggeres();
      for (final c in widget.caisses) {
        final val = suggeres[c.id] ?? c.soldeActuel;
        _controllers[c.id] = TextEditingController(text: val.toStringAsFixed(0));
      }
      if (mounted) {
        setState(() {
          _soldesSuggeres = suggeres;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  double _calculerTotalOuverture() {
    double total = 0;
    for (final c in widget.caisses) {
      final text = _controllers[c.id]?.text.replaceAll(' ', '') ?? '0';
      total += double.tryParse(text) ?? 0;
    }
    return total;
  }

  Future<void> _confirmerOuverture() async {
    final user = AuthService.instance.currentUser;
    final userId = user?.id ?? 1;

    final Map<int, double> soldes = {};
    for (final c in widget.caisses) {
      final text = _controllers[c.id]?.text.replaceAll(' ', '') ?? '0';
      soldes[c.id] = double.tryParse(text) ?? 0;
    }

    setState(() => _isSaving = true);
    try {
      await _caisseService.ouvrirJournal(
        idUtilisateur: userId,
        soldesOuvertureParCaisse: soldes,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1B5E20),
            content: Text('✓ Caisse ouverte avec succès pour la journée !'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e')),
        );
      }
    }
  }

  IconData _getIconForType(int idType) {
    if (idType == 1) return Icons.point_of_sale_rounded; // Espèces
    if (idType == 3) return Icons.phone_android_rounded; // Mobile Money
    return Icons.account_balance_rounded; // Banque
  }

  @override
  Widget build(BuildContext context) {
    final totalOuverture = _calculerTotalOuverture();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 700),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: Colors.black)),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OUVERTURE DE CAISSE (MATIN)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Reprise automatique des soldes restant de la veille',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Carte noire : Total reporté
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SOLDE GLOBAL DE DÉPART (REPORTS VEILLE)',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              currencyFormatter.format(totalOuverture),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Liste scrollable des comptes
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: widget.caisses.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final caisse = widget.caisses[index];
                          final controller = _controllers[caisse.id];
                          final soldeReport = _soldesSuggeres[caisse.id] ?? caisse.soldeActuel;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Icon(
                                    _getIconForType(caisse.idTypeCaisse),
                                    size: 20,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        caisse.nom,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Solde veille : ${currencyFormatter.format(soldeReport)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 130,
                                  child: TextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    onChanged: (_) => setState(() {}),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      suffixText: 'Ar',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Colors.black26),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Champ d'observations
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observations d\'ouverture (optionnel)',
                        hintText: 'Ex: Fond de caisse initial vérifié...',
                        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black26),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.black26),
                            ),
                            child: const Text('ANNULER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _confirmerOuverture,
                            icon: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                            label: Text(
                              _isSaving ? 'OUVERTURE...' : 'CONFIRMER L\'OUVERTURE',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
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
