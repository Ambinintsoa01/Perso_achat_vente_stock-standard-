import 'package:flutter/material.dart';
import '../../models/article.dart';
import '../../models/categorie.dart';
import '../../models/unite_mesure.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/ajustement_stock_dialog.dart';
import 'widgets/article_card.dart';
import 'widgets/nouveau_produit_dialog.dart';
import 'widgets/nouvelle_categorie_dialog.dart';

class ProduitsListScreen extends StatefulWidget {
  final int? initialCategoryId;
  final bool initialOnlyAlerts;

  const ProduitsListScreen({
    super.key,
    this.initialCategoryId,
    this.initialOnlyAlerts = false,
  });

  @override
  State<ProduitsListScreen> createState() => _ProduitsListScreenState();
}

class _ProduitsListScreenState extends State<ProduitsListScreen> {
  final StockService _stockService = StockService();
  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Categorie> _categories = [];
  List<UniteMesure> _unites = [];

  int? _selectedCategoryId;
  bool _onlyAlerts = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    _onlyAlerts = widget.initialOnlyAlerts;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _stockService.getCategories();
      final unites = await _stockService.getUnites();
      final articles = await _stockService.getArticles(
        idCategorie: _selectedCategoryId,
        searchQuery: _searchController.text,
        onlyLowStock: _onlyAlerts,
      );

      if (mounted) {
        setState(() {
          _categories = categories;
          _unites = unites;
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _ouvrirNouveauProduit() {
    showDialog(
      context: context,
      builder: (context) => NouveauProduitDialog(
        categories: _categories,
        unites: _unites,
        preselectedCategoryId: _selectedCategoryId,
        onSuccess: _loadData,
      ),
    );
  }

  void _ouvrirNouvelleCategorie() {
    showDialog(
      context: context,
      builder: (context) => NouvelleCategorieDialog(
        onCategoryCreated: (newId) {
          _selectedCategoryId = newId;
          _loadData();
        },
      ),
    );
  }

  void _ouvrirAjustementStock(Article article) {
    showDialog(
      context: context,
      builder: (context) => AjustementStockDialog(
        articles: _articles,
        preselectedArticle: article,
        initialIsEntree: true,
        onSuccess: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'CATALOGUE PRODUITS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle Catégorie',
            icon: const Icon(Icons.create_new_folder_outlined, size: 22),
            onPressed: _ouvrirNouvelleCategorie,
          ),
          IconButton(
            tooltip: 'Nouveau Produit',
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _ouvrirNouveauProduit,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche & Filtre d'alerte
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom, référence ou code-barres...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _loadData();
                            },
                          )
                        : const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.grey),
                  ),
                  onChanged: (val) => _loadData(),
                ),
                const SizedBox(height: 12),

                // Filtres Catégories (Chips horizontaux)
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Chip Tous
                      ChoiceChip(
                        label: const Text('Tous'),
                        selected: _selectedCategoryId == null && !_onlyAlerts,
                        selectedColor: Colors.black,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (_selectedCategoryId == null && !_onlyAlerts) ? Colors.white : AppTheme.textPrimary,
                        ),
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategoryId = null;
                            _onlyAlerts = false;
                          });
                          _loadData();
                        },
                      ),
                      const SizedBox(width: 8),

                      // Chip Alertes Rupture
                      FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.danger),
                            const SizedBox(width: 4),
                            Text(
                              'Alertes Stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _onlyAlerts ? Colors.white : AppTheme.danger,
                              ),
                            ),
                          ],
                        ),
                        selected: _onlyAlerts,
                        selectedColor: AppTheme.danger,
                        backgroundColor: AppTheme.dangerBg,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (selected) {
                          setState(() => _onlyAlerts = selected);
                          _loadData();
                        },
                      ),
                      const SizedBox(width: 8),

                      // Chips de chaque catégorie
                      ..._categories.map((cat) {
                        final isSelected = _selectedCategoryId == cat.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${cat.nom} (${cat.nombreArticles})'),
                            selected: isSelected,
                            selectedColor: Colors.black,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                            backgroundColor: const Color(0xFFF3F4F6),
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = selected ? cat.id : null;
                              });
                              _loadData();
                            },
                          ),
                        );
                      }),

                      // Bouton ajouter catégorie rapide
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                        label: const Text('Catégorie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onPressed: _ouvrirNouvelleCategorie,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Liste des articles
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : _articles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucun produit trouvé',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Commencez par ajouter votre premier produit au catalogue.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _ouvrirNouveauProduit,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Ajouter un Produit'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.black,
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _articles.length,
                          itemBuilder: (context, index) {
                            final art = _articles[index];
                            return ArticleCard(
                              article: art,
                              onAdjustStock: () => _ouvrirAjustementStock(art),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ouvrirNouvelleCategorie,
                  icon: const Icon(Icons.folder_open_rounded, size: 18, color: Colors.black),
                  label: const Text(
                    '+ CATÉGORIE',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.black, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ouvrirNouveauProduit,
                  icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    '+ NOUVEAU PRODUIT',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
