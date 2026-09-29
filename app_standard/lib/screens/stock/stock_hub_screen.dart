import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/article.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import 'categories_list_screen.dart';
import 'mouvements_stock_screen.dart';
import 'produits_list_screen.dart';
import 'widgets/ajustement_stock_dialog.dart';
import 'widgets/nouveau_produit_dialog.dart';
import 'widgets/nouvelle_categorie_dialog.dart';

class StockHubScreen extends StatefulWidget {
  const StockHubScreen({super.key});

  @override
  State<StockHubScreen> createState() => _StockHubScreenState();
}

class _StockHubScreenState extends State<StockHubScreen> {
  final StockService _stockService = StockService();
  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  StockSummary? _summary;
  List<Article> _articles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _stockService.getStockSummary();
      final articles = await _stockService.getArticles();

      if (mounted) {
        setState(() {
          _summary = summary;
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

  void _ouvrirCatalogue({bool onlyAlerts = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProduitsListScreen(initialOnlyAlerts: onlyAlerts),
      ),
    ).then((_) => _loadSummary());
  }

  void _ouvrirAddStock() {
    if (_articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord ajouter des produits au catalogue')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AjustementStockDialog(
        articles: _articles,
        initialIsEntree: true,
        onSuccess: _loadSummary,
      ),
    );
  }

  void _ouvrirRemoveStock() {
    if (_articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord ajouter des produits au catalogue')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AjustementStockDialog(
        articles: _articles,
        initialIsEntree: false,
        onSuccess: _loadSummary,
      ),
    );
  }

  void _ouvrirMouvementsStock({Article? article}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MouvementsStockScreen(initialArticle: article),
      ),
    ).then((_) => _loadSummary());
  }

  void _ouvrirNouveauProduit() async {
    final categories = await _stockService.getCategories();
    final unites = await _stockService.getUnites();
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => NouveauProduitDialog(
          categories: categories,
          unites: unites,
          onSuccess: _loadSummary,
        ),
      );
    }
  }

  void _ouvrirCategoriesList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoriesListScreen(),
      ),
    ).then((_) => _loadSummary());
  }

  void _ouvrirNouvelleCategorie() {
    showDialog(
      context: context,
      builder: (context) => NouvelleCategorieDialog(
        onCategoryCreated: (_) => _loadSummary(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'GESTION DES STOCKS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Historique des Mouvements',
            icon: const Icon(Icons.history_rounded, size: 24),
            onPressed: () => _ouvrirMouvementsStock(),
          ),
          IconButton(
            tooltip: 'Nouveau Produit',
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _ouvrirNouveauProduit,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              onRefresh: _loadSummary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARTE NOIRE DU PATRON : VALEUR TOTALE DU STOCK
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'VALEUR DU STOCK (ACHAT)',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_summary?.totalArticles ?? 0} références',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            currencyFormatter.format(_summary?.totalValeurAchat ?? 0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Valeur marchande (Vente)', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormatter.format(_summary?.totalValeurVente ?? 0),
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              if ((_summary?.articlesEnAlerte ?? 0) > 0 || (_summary?.articlesEnRupture ?? 0) > 0)
                                GestureDetector(
                                  onTap: () => _ouvrirCatalogue(onlyAlerts: true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.danger,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${(_summary?.articlesEnAlerte ?? 0) + (_summary?.articlesEnRupture ?? 0)} en alerte',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // SECTION LES 4 GRANDES CARTES (DESIGN DE RÉFÉRENCE - ÉCRAN 1)
                    const Text(
                      'ACTIONS STOCKS',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Carte 1: PRODUCTS
                    _buildHubCard(
                      title: 'PRODUCTS',
                      subtitle: 'Catalogue complet, prix et fiches articles',
                      icon: Icons.inventory_2_outlined,
                      accentColor: Colors.black,
                      onTap: () => _ouvrirCatalogue(),
                    ),
                    const SizedBox(height: 12),

                    // Carte 2: CATEGORIES
                    _buildHubCard(
                      title: 'CATEGORIES',
                      subtitle: 'Familles et classement des produits',
                      icon: Icons.category_outlined,
                      accentColor: const Color(0xFF2563EB),
                      onTap: _ouvrirCategoriesList,
                    ),
                    const SizedBox(height: 12),

                    // Carte 3: ADD STOCK
                    _buildHubCard(
                      title: 'ADD STOCK',
                      subtitle: 'Entrée directe de stock / Réception',
                      icon: Icons.add_box_outlined,
                      accentColor: AppTheme.success,
                      onTap: _ouvrirAddStock,
                    ),
                    const SizedBox(height: 12),

                    // Carte 4: REMOVE STOCK
                    _buildHubCard(
                      title: 'REMOVE STOCK',
                      subtitle: 'Sortie manuelle, perte ou dépréciation',
                      icon: Icons.indeterminate_check_box_outlined,
                      accentColor: AppTheme.danger,
                      onTap: _ouvrirRemoveStock,
                    ),
                    const SizedBox(height: 12),

                    // Carte 5: MOUVEMENTS DE STOCK
                    _buildHubCard(
                      title: 'MOUVEMENTS DE STOCK',
                      subtitle: 'Historique des flux, entrées, sorties et traçabilité',
                      icon: Icons.swap_vert_rounded,
                      accentColor: const Color(0xFF7C3AED),
                      onTap: _ouvrirMouvementsStock,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
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
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18, color: Colors.black),
                  label: const Text('+ CATÉGORIE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
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
                  label: const Text('+ NOUVEAU PRODUIT', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildHubCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
