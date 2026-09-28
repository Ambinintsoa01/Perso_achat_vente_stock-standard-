import 'package:flutter/material.dart';
import '../../models/categorie.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import 'produits_list_screen.dart';
import 'widgets/nouvelle_categorie_dialog.dart';

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  final StockService _stockService = StockService();
  final TextEditingController _searchController = TextEditingController();

  List<Categorie> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final list = await _stockService.getCategories();
      if (mounted) {
        setState(() {
          _categories = list;
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

  void _ouvrirNouvelleCategorie() {
    showDialog(
      context: context,
      builder: (context) => NouvelleCategorieDialog(
        onCategoryCreated: (_) => _loadCategories(),
      ),
    );
  }

  void _ouvrirProduitsCategorie(Categorie categorie) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProduitsListScreen(
          initialCategoryId: categorie.id,
        ),
      ),
    ).then((_) => _loadCategories());
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredCategories = _categories.where((c) {
      if (query.isEmpty) return true;
      return c.nom.toLowerCase().contains(query) || c.code.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'CATÉGORIES DE PRODUITS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle Catégorie',
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _ouvrirNouvelleCategorie,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une catégorie ou un code...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // En-tête avec compteur
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'FAMILLES D\'ARTICLES',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${filteredCategories.length} catégories',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Liste des catégories
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black))
                : filteredCategories.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'Aucune catégorie trouvée',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Créez votre première catégorie pour organiser votre stock.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _ouvrirNouvelleCategorie,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Créer une Catégorie'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: Colors.black,
                        onRefresh: _loadCategories,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, index) {
                            final cat = filteredCategories[index];
                            return _buildCategoryCard(cat);
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
          child: ElevatedButton.icon(
            onPressed: _ouvrirNouvelleCategorie,
            icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            label: const Text(
              '+ NOUVELLE CATÉGORIE',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Categorie cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _ouvrirProduitsCategorie(cat),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.folder_outlined,
            color: Color(0xFF2563EB),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cat.nom,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cat.code,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                '${cat.nombreArticles} article(s)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (cat.description != null && cat.description!.isNotEmpty) ...[
                const Text(' • ', style: TextStyle(color: Colors.grey)),
                Expanded(
                  child: Text(
                    cat.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
