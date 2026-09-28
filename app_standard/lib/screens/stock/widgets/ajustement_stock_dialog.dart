import 'package:flutter/material.dart';
import '../../../models/article.dart';
import '../../../services/stock_service.dart';
import '../../../theme/app_theme.dart';

class AjustementStockDialog extends StatefulWidget {
  final List<Article> articles;
  final Article? preselectedArticle;
  final bool initialIsEntree;
  final VoidCallback onSuccess;

  const AjustementStockDialog({
    super.key,
    required this.articles,
    this.preselectedArticle,
    this.initialIsEntree = true,
    required this.onSuccess,
  });

  @override
  State<AjustementStockDialog> createState() => _AjustementStockDialogState();
}

class _AjustementStockDialogState extends State<AjustementStockDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantiteController = TextEditingController();
  final _motifController = TextEditingController();

  late bool _isEntree;
  late int _selectedArticleId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isEntree = widget.initialIsEntree;
    _selectedArticleId = widget.preselectedArticle?.id ??
        (widget.articles.isNotEmpty ? widget.articles.first.id : 1);
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final qte = double.tryParse(_quantiteController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    if (qte <= 0) return;

    setState(() => _isLoading = true);
    try {
      final service = StockService();
      // Type 3: AJUSTEMENT_POSITIF (sens +1) / Type 4: AJUSTEMENT_NEGATIF (sens -1)
      final typeId = _isEntree ? 3 : 4;

      await service.ajusterStock(
        idArticle: _selectedArticleId,
        idDepot: 1, // Dépôt principal
        quantite: qte,
        idTypeMouvement: typeId,
        remarque: _motifController.text.trim().isNotEmpty
            ? _motifController.text.trim()
            : (_isEntree ? 'Entrée manuelle de stock' : 'Sortie manuelle de stock'),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text(
              _isEntree
                  ? 'Entrée de +$qte article(s) enregistrée'
                  : 'Sortie de -$qte article(s) enregistrée',
            ),
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
                    'Mouvement de Stock',
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

              // Sélecteur Entrée / Sortie
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
                        onTap: () => setState(() => _isEntree = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isEntree ? Colors.black : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '+ Entrée Stock',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _isEntree ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isEntree = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isEntree ? AppTheme.danger : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '- Sortie Stock',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: !_isEntree ? Colors.white : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sélection Article
              DropdownButtonFormField<int>(
                initialValue: _selectedArticleId,
                decoration: const InputDecoration(labelText: 'Article à ajuster'),
                items: widget.articles.map((art) {
                  return DropdownMenuItem<int>(
                    value: art.id,
                    child: Text(
                      '${art.designation} (Reste: ${art.quantiteStock.toStringAsFixed(0)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedArticleId = val);
                },
              ),
              const SizedBox(height: 14),

              // Quantité
              TextFormField(
                controller: _quantiteController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Quantité à ajouter / retirer *',
                  hintText: 'ex: 10',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Quantité requise';
                  final parsed = double.tryParse(val.replaceAll(' ', '').replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Quantité invalide';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Motif
              TextFormField(
                controller: _motifController,
                decoration: const InputDecoration(
                  labelText: 'Motif / Justification',
                  hintText: 'ex: Réassort, casse, échantillon, correction',
                ),
              ),
              const SizedBox(height: 22),

              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEntree ? Colors.black : AppTheme.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isEntree ? 'Confirmer l\'Entrée en Stock' : 'Confirmer la Sortie de Stock',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
