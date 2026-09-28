import 'package:flutter/material.dart';
import '../../../services/achat_service.dart';
import '../../../theme/app_theme.dart';

class NouveauFournisseurDialog extends StatefulWidget {
  final Function(int newSupplierId)? onSupplierCreated;

  const NouveauFournisseurDialog({super.key, this.onSupplierCreated});

  @override
  State<NouveauFournisseurDialog> createState() => _NouveauFournisseurDialogState();
}

class _NouveauFournisseurDialogState extends State<NouveauFournisseurDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _contactController = TextEditingController();
  final _telController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _contactController.dispose();
    _telController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = AchatService();
      final id = await service.ajouterFournisseur(
        raisonSociale: _nomController.text,
        nomContact: _contactController.text.trim().isNotEmpty ? _contactController.text.trim() : null,
        telephone: _telController.text.trim().isNotEmpty ? _telController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSupplierCreated?.call(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Fournisseur ajouté avec succès'),
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
                    'Nouveau Fournisseur',
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
              const SizedBox(height: 18),
              TextFormField(
                controller: _nomController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Raison sociale / Nom fournisseur *',
                  hintText: 'ex: Grossiste Behoririka, Import Chine',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nom requis' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Nom du contact / Responsable',
                  hintText: 'ex: M. Rabe',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _telController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  hintText: 'ex: 034 00 000 00',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (Optionnel)',
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
                        'Enregistrer le Fournisseur',
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
