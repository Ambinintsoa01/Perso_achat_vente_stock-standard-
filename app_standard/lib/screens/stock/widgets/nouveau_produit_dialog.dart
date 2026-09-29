import 'package:flutter/material.dart';
import '../../../models/categorie.dart';
import '../../../models/unite_mesure.dart';
import '../../../services/stock_service.dart';
import '../../../theme/app_theme.dart';
import 'nouvelle_categorie_dialog.dart';

class NouveauProduitDialog extends StatefulWidget {
  final List<Categorie> categories;
  final List<UniteMesure> unites;
  final int? preselectedCategoryId;
  final VoidCallback onSuccess;

  const NouveauProduitDialog({
    super.key,
    required this.categories,
    required this.unites,
    this.preselectedCategoryId,
    required this.onSuccess,
  });

  @override
  State<NouveauProduitDialog> createState() => _NouveauProduitDialogState();
}

class _NouveauProduitDialogState extends State<NouveauProduitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();
  final _codeBarreController = TextEditingController();
  final _nomController = TextEditingController();
  final _descController = TextEditingController();
  final _prixAchatController = TextEditingController();
  final _prixVenteController = TextEditingController();
  final _seuilAlerteController = TextEditingController(text: '5');
  final _stockInitialController = TextEditingController(text: '0');

  late List<Categorie> _categoriesList;
  int? _selectedCategorieId;
  int? _selectedUniteId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categoriesList = List.from(widget.categories);
    _selectedCategorieId = widget.preselectedCategoryId ??
        (_categoriesList.isNotEmpty ? _categoriesList.first.id : null);
    _selectedUniteId = widget.unites.isNotEmpty ? widget.unites.first.id : 1;

    // Référence suggérée
    _refController.text = 'ART-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  @override
  void dispose() {
    _refController.dispose();
    _codeBarreController.dispose();
    _nomController.dispose();
    _descController.dispose();
    _prixAchatController.dispose();
    _prixVenteController.dispose();
    _seuilAlerteController.dispose();
    _stockInitialController.dispose();
    super.dispose();
  }

  void _creerNouvelleCategorie() {
    showDialog(
      context: context,
      builder: (context) => NouvelleCategorieDialog(
        onCategoryCreated: (newId) async {
          final service = StockService();
          final updated = await service.getCategories();
          if (mounted) {
            setState(() {
              _categoriesList = updated;
              _selectedCategorieId = newId;
            });
          }
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final prixAchat = double.tryParse(_prixAchatController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    final prixVente = double.tryParse(_prixVenteController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    final seuilAlerte = double.tryParse(_seuilAlerteController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 5;
    final stockInitial = double.tryParse(_stockInitialController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

    setState(() => _isLoading = true);
    try {
      final service = StockService();
      await service.ajouterArticle(
        reference: _refController.text,
        codeBarre: _codeBarreController.text.trim().isNotEmpty ? _codeBarreController.text.trim() : null,
        designation: _nomController.text,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        idCategorie: _selectedCategorieId,
        idUnite: _selectedUniteId,
        prixAchat: prixAchat,
        prixVente: prixVente,
        seuilAlerte: seuilAlerte,
        stockInitial: stockInitial,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text('Article créé et ajouté au catalogue'),
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
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
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
                    'Nouveau Produit / Article',
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Référence & Code Barre
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _refController,
                              decoration: const InputDecoration(labelText: 'Référence / SKU *'),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _codeBarreController,
                              decoration: const InputDecoration(
                                labelText: 'Code-Barres (Optionnel)',
                                suffixIcon: Icon(Icons.qr_code_scanner_rounded, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Désignation
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Désignation / Nom du produit *',
                          hintText: 'ex: T-shirt Col Rond Noir Taille L',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 14),

                      // Catégorie + Bouton Ajout rapide
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedCategorieId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Catégorie'),
                              items: _categoriesList.map((cat) {
                                return DropdownMenuItem<int>(
                                  value: cat.id,
                                  child: Text(
                                    cat.nom,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedCategorieId = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Créer une catégorie',
                            icon: const Icon(Icons.add_rounded, size: 20, color: Colors.black),
                            style: IconButton.styleFrom(
                              side: const BorderSide(color: AppTheme.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.all(14),
                            ),
                            onPressed: _creerNouvelleCategorie,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Unité de mesure
                      DropdownButtonFormField<int>(
                        initialValue: _selectedUniteId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unité de mesure'),
                        items: widget.unites.map((u) {
                          return DropdownMenuItem<int>(
                            value: u.id,
                            child: Text(
                              '${u.nom} (${u.code})',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedUniteId = val),
                      ),
                      const SizedBox(height: 14),

                      // Prix d'achat & Prix de vente
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _prixAchatController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Prix d\'achat (Coût)',
                                hintText: '0',
                                suffixText: 'Ar',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _prixVenteController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Prix de vente standard *',
                                hintText: '0',
                                suffixText: 'Ar',
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Seuil d'alerte & Stock initial
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _seuilAlerteController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Seuil d\'alerte stock',
                                hintText: '5',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _stockInitialController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Stock initial de départ',
                                hintText: '0',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description ou caractéristiques (Optionnel)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                    : const Text(
                        'Enregistrer le Produit',
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
