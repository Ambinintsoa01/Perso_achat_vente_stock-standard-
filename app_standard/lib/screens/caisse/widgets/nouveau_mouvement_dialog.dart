import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/caisse.dart';
import '../../../models/mode_paiement.dart';
import '../../../services/caisse_service.dart';
import '../../../theme/app_theme.dart';

class NouveauMouvementDialog extends StatefulWidget {
  final List<Caisse> caisses;
  final List<ModePaiement> modesPaiement;
  final int? selectedCaisseId;
  final VoidCallback onSuccess;

  const NouveauMouvementDialog({
    super.key,
    required this.caisses,
    required this.modesPaiement,
    this.selectedCaisseId,
    required this.onSuccess,
  });

  @override
  State<NouveauMouvementDialog> createState() => _NouveauMouvementDialogState();
}

class _NouveauMouvementDialogState extends State<NouveauMouvementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _referenceController = TextEditingController();

  bool _isEncaissement = true;
  late int _selectedCaisseId;
  late int _selectedModePaiementId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCaisseId = widget.selectedCaisseId ?? (widget.caisses.isNotEmpty ? widget.caisses.first.id : 1);
    _selectedModePaiementId = widget.modesPaiement.isNotEmpty ? widget.modesPaiement.first.id : 1;
  }

  @override
  void dispose() {
    _montantController.dispose();
    _descriptionController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final montant = double.tryParse(_montantController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    if (montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un montant valide supérieur à 0')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final service = CaisseService();
      // Type 1: ENCAISSEMENT_VENTE / Type 6: APPORT (sens +1)
      // Type 5: DEPENSE_DIVERSE / Type 2: DECAISSEMENT_ACHAT (sens -1)
      final typeId = _isEncaissement ? 1 : 5;

      await service.enregistrerMouvement(
        idCaisse: _selectedCaisseId,
        idTypeMouvement: typeId,
        idModePaiement: _selectedModePaiementId,
        montant: montant,
        referencePiece: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text(
              _isEncaissement
                  ? 'Encaissement de ${montant.toStringAsFixed(0)} Ar enregistré'
                  : 'Décaissement de ${montant.toStringAsFixed(0)} Ar enregistré',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.decimalPattern('fr_FR');

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
              // Titre et Fermer (fixe en haut)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Opération de Caisse',
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
                        // Sélecteur Type (Encaissement vs Décaissement)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isEncaissement = true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _isEncaissement ? Colors.black : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '+ Encaissement',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _isEncaissement ? Colors.white : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _isEncaissement = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !_isEncaissement ? AppTheme.danger : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '- Décaissement',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: !_isEncaissement ? Colors.white : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Sélection de la caisse
                        DropdownButtonFormField<int>(
                          initialValue: _selectedCaisseId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Compte / Caisse cible'),
                          items: widget.caisses.map((c) {
                            return DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(
                                '${c.nom} (${currencyFormatter.format(c.soldeActuel)} Ar)',
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
                          decoration: const InputDecoration(labelText: 'Moyen de paiement'),
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

                        // Montant
                        TextFormField(
                          controller: _montantController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Montant en Ariary *',
                            hintText: 'ex: 50 000',
                            suffixText: 'Ar',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Montant requis';
                            final parsed = double.tryParse(val.replaceAll(' ', '').replaceAll(',', '.'));
                            if (parsed == null || parsed <= 0) return 'Montant invalide';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Motif / Description',
                            hintText: 'ex: Vente directe, achat fournitures, apport',
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Référence
                        TextFormField(
                          controller: _referenceController,
                          decoration: const InputDecoration(
                            labelText: 'Référence / N° Reçu (Optionnel)',
                            hintText: 'ex: TKT-0012, MV-987213',
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Bouton valider
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isEncaissement ? Colors.black : AppTheme.danger,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isEncaissement ? 'Valider l\'Encaissement' : 'Valider le Décaissement',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
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
