import 'package:flutter/material.dart';
import '../../../models/caisse.dart';
import '../../../services/caisse_service.dart';
import '../../../theme/app_theme.dart';

class TransfertInterneDialog extends StatefulWidget {
  final List<Caisse> caisses;
  final VoidCallback onSuccess;

  const TransfertInterneDialog({
    super.key,
    required this.caisses,
    required this.onSuccess,
  });

  @override
  State<TransfertInterneDialog> createState() => _TransfertInterneDialogState();
}

class _TransfertInterneDialogState extends State<TransfertInterneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _fraisController = TextEditingController();
  final _motifController = TextEditingController();

  late int _idCaisseSource;
  late int _idCaisseDestination;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _idCaisseSource = widget.caisses.isNotEmpty ? widget.caisses.first.id : 1;
    _idCaisseDestination = widget.caisses.length > 1 ? widget.caisses[1].id : (widget.caisses.isNotEmpty ? widget.caisses.first.id : 1);
  }

  @override
  void dispose() {
    _montantController.dispose();
    _fraisController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idCaisseSource == _idCaisseDestination) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La caisse source et la caisse de destination doivent être différentes')),
      );
      return;
    }

    final montant = double.tryParse(_montantController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    final frais = double.tryParse(_fraisController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

    setState(() => _isLoading = true);
    try {
      final service = CaisseService();
      await service.transfertInterne(
        idCaisseSource: _idCaisseSource,
        idCaisseDestination: _idCaisseDestination,
        montant: montant,
        frais: frais,
        motif: _motifController.text.trim().isNotEmpty ? _motifController.text.trim() : 'Transfert interne',
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Virement de ${montant.toStringAsFixed(0)} Ar effectué avec succès'),
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
                    'Virement Interne / Transfert',
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
              const SizedBox(height: 16),

              // Caisse Source (Débitée)
              DropdownButtonFormField<int>(
                initialValue: _idCaisseSource,
                decoration: const InputDecoration(labelText: 'Compte Source (Débité) *'),
                items: widget.caisses.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.id,
                    child: Text('${c.nom} (${c.soldeActuel.toStringAsFixed(0)} Ar)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _idCaisseSource = val);
                },
              ),
              const SizedBox(height: 14),

              // Caisse Destination (Créditée)
              DropdownButtonFormField<int>(
                initialValue: _idCaisseDestination,
                decoration: const InputDecoration(labelText: 'Compte Destination (Crédité) *'),
                items: widget.caisses.map((c) {
                  return DropdownMenuItem<int>(
                    value: c.id,
                    child: Text('${c.nom} (${c.soldeActuel.toStringAsFixed(0)} Ar)'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _idCaisseDestination = val);
                },
              ),
              const SizedBox(height: 14),

              // Montant viré
              TextFormField(
                controller: _montantController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Montant transféré *',
                  hintText: 'ex: 100 000',
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

              // Frais de retrait / transfert
              TextFormField(
                controller: _fraisController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Frais opérateur (ex: Frais retrait MVola)',
                  hintText: '0 si aucun',
                  suffixText: 'Ar',
                ),
              ),
              const SizedBox(height: 14),

              // Motif
              TextFormField(
                controller: _motifController,
                decoration: const InputDecoration(
                  labelText: 'Motif du transfert',
                  hintText: 'ex: Retrait MVola vers caisse liquide',
                ),
              ),
              const SizedBox(height: 22),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Confirmer le Virement',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
