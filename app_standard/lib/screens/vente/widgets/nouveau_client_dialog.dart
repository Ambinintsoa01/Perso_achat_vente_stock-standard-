import 'package:flutter/material.dart';
import '../../../services/vente_service.dart';
import '../../../theme/app_theme.dart';

class NouveauClientDialog extends StatefulWidget {
  final Function(int idClient)? onClientCreated;

  const NouveauClientDialog({super.key, this.onClientCreated});

  @override
  State<NouveauClientDialog> createState() => _NouveauClientDialogState();
}

class _NouveauClientDialogState extends State<NouveauClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _adresseController = TextEditingController();
  final _villeController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final service = VenteService();
      final id = await service.ajouterClient(
        nomComplet: _nomController.text.trim(),
        telephone: _telephoneController.text.trim().isNotEmpty ? _telephoneController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        adresse: _adresseController.text.trim().isNotEmpty ? _adresseController.text.trim() : null,
        ville: _villeController.text.trim().isNotEmpty ? _villeController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onClientCreated?.call(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Client "${_nomController.text.trim()}" ajouté avec succès'),
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
                      'Nouveau Client',
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

              // Formulaire scrollable
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nomController,
                          decoration: const InputDecoration(
                            labelText: 'Nom Complet / Société *',
                            hintText: 'ex: Mme Rasoa, SARL Madacom',
                            prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Nom requis';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _telephoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Numéro Téléphone',
                            hintText: 'ex: 034 12 345 67',
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Adresse Email',
                            hintText: 'ex: client@gmail.com',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _adresseController,
                          decoration: const InputDecoration(
                            labelText: 'Adresse physique',
                            hintText: 'ex: Lot II B 12, Analakely',
                            prefixIcon: Icon(Icons.home_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _villeController,
                          decoration: const InputDecoration(
                            labelText: 'Ville',
                            hintText: 'ex: Antananarivo',
                            prefixIcon: Icon(Icons.location_city_outlined, size: 20),
                          ),
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
                              : const Text('Enregistrer le Client', style: TextStyle(fontWeight: FontWeight.w700)),
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
