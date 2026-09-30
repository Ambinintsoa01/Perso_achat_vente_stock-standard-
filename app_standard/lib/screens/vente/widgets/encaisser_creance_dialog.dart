import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/caisse.dart';
import '../../../models/commande_vente.dart';
import '../../../models/mode_paiement.dart';
import '../../../services/vente_service.dart';
import '../../../theme/app_theme.dart';

class EncaisserCreanceDialog extends StatefulWidget {
  final CommandeVente commande;
  final List<Caisse> caisses;
  final List<ModePaiement> modesPaiement;
  final VoidCallback onSuccess;

  const EncaisserCreanceDialog({
    super.key,
    required this.commande,
    required this.caisses,
    required this.modesPaiement,
    required this.onSuccess,
  });

  @override
  State<EncaisserCreanceDialog> createState() => _EncaisserCreanceDialogState();
}

class _EncaisserCreanceDialogState extends State<EncaisserCreanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();

  late int _selectedCaisseId;
  late int _selectedModePaiementId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCaisseId = widget.caisses.isNotEmpty ? widget.caisses.first.id : 1;
    _selectedModePaiementId = widget.modesPaiement.isNotEmpty ? widget.modesPaiement.first.id : 1;
    _montantController.text = widget.commande.resteAPayer.toStringAsFixed(0);
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

    if (widget.commande.idFacture == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: AppTheme.danger, content: Text('Aucune facture associée à cette vente')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = VenteService();
      await service.reglerCreanceClient(
        idFactureClient: widget.commande.idFacture!,
        idCaisse: _selectedCaisseId,
        idModePaiement: _selectedModePaiementId,
        montantRegle: montant,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        widget.onSuccess();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Encaissement de ${montant.toStringAsFixed(0)} Ar enregistré avec succès'),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Encaisser Créance Client',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Contenu défilable
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 6),

                        // Récapitulatif dette client
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.commande.clientNom ?? 'Client Comptoir',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.danger),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    Text(
                                      'Réf: ${widget.commande.numeroCommande}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.danger),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Reste dû', style: TextStyle(fontSize: 10, color: AppTheme.danger)),
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

                        // Caisse à créditer
                        DropdownButtonFormField<int>(
                          initialValue: _selectedCaisseId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Compte / Caisse qui encaisse *'),
                          items: widget.caisses.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(
                                '${c.nom} (${currencyFormatter.format(c.soldeActuel)})',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
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
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Moyen de paiement *'),
                          items: widget.modesPaiement.map((mp) {
                            return DropdownMenuItem<int>(
                              value: mp.id,
                              child: Text(
                                mp.libelle,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedModePaiementId = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Montant à régler
                        TextFormField(
                          controller: _montantController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Montant à encaisser *',
                            suffixText: 'Ar',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Montant requis';
                            final parsed = double.tryParse(val.replaceAll(' ', '').replaceAll(',', '.'));
                            if (parsed == null || parsed <= 0) return 'Montant invalide';
                            if (parsed > widget.commande.resteAPayer) return 'Dépasse le montant dû';
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Confirmer l\'Encaissement', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
