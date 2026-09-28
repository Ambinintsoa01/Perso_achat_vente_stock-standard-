import 'package:flutter/material.dart';
import '../../../services/stock_service.dart';
import '../../../theme/app_theme.dart';

class NouvelleCategorieDialog extends StatefulWidget {
  final Function(int newCategoryId)? onCategoryCreated;

  const NouvelleCategorieDialog({super.key, this.onCategoryCreated});

  @override
  State<NouvelleCategorieDialog> createState() => _NouvelleCategorieDialogState();
}

class _NouvelleCategorieDialogState extends State<NouvelleCategorieDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nomController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = StockService();
      final id = await service.ajouterCategorie(
        code: _codeController.text,
        nom: _nomController.text,
        description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onCategoryCreated?.call(id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Catégorie créée avec succès'),
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
        width: 400,
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
                    'Nouvelle Catégorie',
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
                  labelText: 'Nom de la catégorie *',
                  hintText: 'ex: Vêtements, Électronique, Alimentation',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Nom requis' : null,
                onChanged: (val) {
                  // Génération automatique d'un code court
                  if (_codeController.text.isEmpty || _codeController.text.length <= 4) {
                    final clean = val.replaceAll(' ', '').toUpperCase();
                    _codeController.text = clean.length > 4 ? clean.substring(0, 4) : clean;
                  }
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Code catégorie *',
                  hintText: 'ex: VETM, ELEC, ALIM',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Code requis' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optionnel)',
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
                        'Enregistrer la Catégorie',
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
