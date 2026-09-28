import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/caisse.dart';
import '../../../models/commande_achat.dart';
import '../../../models/mode_paiement.dart';
import '../../../services/achat_service.dart';
import '../../../theme/app_theme.dart';

class ReglerDetteDialog extends StatefulWidget {
  final CommandeAchat commande;
  final List<Caisse> caisses;
  final List<ModePaiement> modesPaiement;
  final VoidCallback onSuccess;

  const ReglerDetteDialog({
    super.key,
    required this.commande,
    required this.caisses,
    required this.modesPaiement,
    required this.onSuccess,
  });

  @override
  State<ReglerDetteDialog> createState() => _ReglerDetteDialogState();
}

class _ReglerDetteDialogState extends State<ReglerDetteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();

  late int _selectedCaisseId;
  late int _selectedModePaiementId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _montantController.text = widget.commande.resteAPayer.toStringAsFixed(0);
    _selectedCaisseId = widget.caisses.isNotEmpty ? widget.caisses.first.id : 1;
    _selectedModePaiementId = widget.modesPaiement.isNotEmpty ? widget.modesPaiement.first.id : 1;
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final montant = double.tryParse(_montantController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    if (montant <= 0) return;

    setState(() => _isLoading = true);
    try {
      final service = AchatService();
      await service.reglerDetteFournisseur(
        idCommandeAchat: widget.commande.id,
        idCaisse: _selectedCaisseId,
        idModePaiement: _selectedModePaiementId,
        montant: montant,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Règlement de ${montant.toStringAsFixed(0)} Ar enregistré avec succès'),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'Ar',
      decimalDigits: 0,
    );

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Régler Dette Fournisseur',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Récapitulatif dette
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.commande.fournisseurNom ?? 'Fournisseur',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.danger),
                        ),
                        Text(
                          'Réf: ${widget.commande.numeroCommande}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.danger),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Reste à payer', style: TextStyle(fontSize: 10, color: AppTheme.danger)),
                        Text(
                          currencyFormatter.format(widget.commande.resteAPayer),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.danger),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Caisse débitée
              DropdownButtonFormField<int>(
                initialValue: _selectedCaisseId,
                decoration: const InputDecoration(labelText: 'Compte / Caisse à débiter *'),
                items: widget.caisses.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.id,
                    child: Text('${c.nom} (${c.soldeActuel.toStringAsFixed(0)} Ar)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCaisseId = val);
                },
              ),
              const SizedBox(height: 14),

              // Mode de paiement
              DropdownButtonFormField<int>(
                initialValue: _selectedModePaiementId,
                decoration: const InputDecoration(labelText: 'Moyen de paiement *'),
                items: widget.modesPaiement.map((mp) {
                  return DropdownMenuItem<int>(
                    value: mp.id,
                    child: Text(mp.libelle),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedModePaiementId = val);
                },
              ),
              const SizedBox(height: 14),

              // Montant à payer
              TextFormField(
                controller: _montantController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant à régler *',
                  suffixText: 'Ar',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Montant requis';
                  final parsed = double.tryParse(val.replaceAll(' ', '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  if (parsed > widget.commande.resteAPayer) return 'Dépasse le reste à payer';
                  return null;
                },
              ),
              const SizedBox(height: 22),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirmer le Règlement', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
