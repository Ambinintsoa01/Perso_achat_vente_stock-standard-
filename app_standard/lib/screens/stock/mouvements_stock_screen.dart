import 'package:flutter/material.dart';
import '../../models/article.dart';
import '../../models/mouvement_stock.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/ajustement_stock_dialog.dart';
import 'widgets/mouvement_stock_item.dart';

class MouvementsStockScreen extends StatefulWidget {
  final Article? initialArticle;
  final int? initialSens;

  const MouvementsStockScreen({
    super.key,
    this.initialArticle,
    this.initialSens,
  });

  @override
  State<MouvementsStockScreen> createState() => _MouvementsStockScreenState();
}

class _MouvementsStockScreenState extends State<MouvementsStockScreen> {
  final StockService _stockService = StockService();
  final TextEditingController _searchController = TextEditingController();

  List<MouvementStock> _mouvements = [];
  List<Article> _articles = [];
  List<Map<String, dynamic>> _typesMouvement = [];

  Article? _selectedArticle;
  int? _selectedSens; // null = Tous, 1 = Entrée, -1 = Sortie
  int? _selectedTypeMouvement; // null = Tous
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedArticle = widget.initialArticle;
    _selectedSens = widget.initialSens;
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
      final articles = await _stockService.getArticles();
      final types = await _stockService.getTypesMouvementStock();
      final mouvements = await _stockService.getMouvementsStock(
        idArticle: _selectedArticle?.id,
        idTypeMouvement: _selectedTypeMouvement,
        sens: _selectedSens,
        searchQuery: _searchController.text,
      );

      if (mounted) {
        setState(() {
          _articles = articles;
          _typesMouvement = types;
          _mouvements = mouvements;
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

  void _ouvrirAjustementStock({required bool isEntree}) {
    if (_articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun article disponible pour ajustement')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AjustementStockDialog(
        articles: _articles,
        preselectedArticle: _selectedArticle,
        initialIsEntree: isEntree,
        onSuccess: _loadData,
      ),
    );
  }

  void _choisirArticleFiltre() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Filtrer par produit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.all_inclusive_rounded, color: Colors.black),
                title: const Text('Tous les produits', style: TextStyle(fontWeight: FontWeight.w700)),
                trailing: _selectedArticle == null ? const Icon(Icons.check_rounded, color: Colors.black) : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedArticle = null);
                  _loadData();
                },
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _articles.length,
                  itemBuilder: (context, index) {
                    final article = _articles[index];
                    final isSelected = _selectedArticle?.id == article.id;
                    return ListTile(
                      title: Text(article.designation, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Réf : ${article.reference} • Stock : ${article.quantiteStock} ${article.uniteCode ?? ''}'),
                      trailing: isSelected ? const Icon(Icons.check_rounded, color: Colors.black) : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _selectedArticle = article);
                        _loadData();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcul des statistiques sur la sélection affichée
    double totalEntrees = 0;
    double totalSorties = 0;
    for (var m in _mouvements) {
      if (m.isEntree) {
        totalEntrees += m.quantite;
      } else {
        totalSorties += m.quantite;
      }
    }
    final soldeNet = totalEntrees - totalSorties;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          _selectedArticle != null
              ? 'FLUX : ${_selectedArticle!.designation.toUpperCase()}'
              : 'MOUVEMENTS DE STOCK',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filtrer par produit',
            icon: Icon(
              Icons.filter_list_rounded,
              color: _selectedArticle != null ? Colors.black : Colors.black54,
              size: 24,
            ),
            onPressed: _choisirArticleFiltre,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARTE NOIRE : SYNTHÈSE DES FLUX DE STOCKS
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
                              Expanded(
                                child: Text(
                                  _selectedArticle != null
                                      ? 'MOUVEMENTS : ${_selectedArticle!.designation.toUpperCase()}'
                                      : 'FLUX GLOBAL DES STOCKS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_mouvements.length} mouvements',
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Text(
                                  '${soldeNet >= 0 ? "+" : ""}${_formatNumber(soldeNet)}',
                                  style: TextStyle(
                                    color: soldeNet >= 0 ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedArticle?.uniteCode ?? 'unités',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _buildStatItem('Total Entrées', '+$totalEntrees', Icons.arrow_downward_rounded, AppTheme.success),
                              _buildStatItem('Total Sorties', '-$totalSorties', Icons.arrow_upward_rounded, AppTheme.danger),
                              if (_selectedArticle != null)
                                _buildStatItem('Stock actuel', '${_selectedArticle!.quantiteStock}', Icons.inventory_2_rounded, Colors.white)
                              else
                                _buildStatItem('Articles touchés', '${_countUniqueArticles()} réf', Icons.category_rounded, Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // CHAMP DE RECHERCHE
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _loadData(),
                        decoration: InputDecoration(
                          hintText: 'Rechercher par produit, référence, N° doc...',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadData();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // FILTRE DU PRODUIT SÉLECTIONNÉ (SI ACTIF)
                    if (_selectedArticle != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 180),
                                  child: Text(
                                    _selectedArticle!.designation,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedArticle = null);
                                    _loadData();
                                  },
                                  child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // FILTRES HORIZONTAUX PAR TYPE / SENS
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'Tous les flux',
                            selected: _selectedSens == null && _selectedTypeMouvement == null,
                            onSelected: () {
                              setState(() {
                                _selectedSens = null;
                                _selectedTypeMouvement = null;
                              });
                              _loadData();
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Entrées (+)',
                            selected: _selectedSens == 1 && _selectedTypeMouvement == null,
                            activeColor: AppTheme.success,
                            onSelected: () {
                              setState(() {
                                _selectedSens = 1;
                                _selectedTypeMouvement = null;
                              });
                              _loadData();
                            },
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            label: 'Sorties (-)',
                            selected: _selectedSens == -1 && _selectedTypeMouvement == null,
                            activeColor: AppTheme.danger,
                            onSelected: () {
                              setState(() {
                                _selectedSens = -1;
                                _selectedTypeMouvement = null;
                              });
                              _loadData();
                            },
                          ),
                          ..._typesMouvement.map((t) {
                            final typeId = t['id'] as int;
                            final typeLibelle = t['libelle'] as String;
                            final isTypeSensEntree = (t['sens'] as int? ?? 1) == 1;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildFilterChip(
                                label: typeLibelle,
                                selected: _selectedTypeMouvement == typeId,
                                activeColor: isTypeSensEntree ? AppTheme.success : AppTheme.danger,
                                onSelected: () {
                                  setState(() {
                                    if (_selectedTypeMouvement == typeId) {
                                      _selectedTypeMouvement = null;
                                    } else {
                                      _selectedSens = null;
                                      _selectedTypeMouvement = typeId;
                                    }
                                  });
                                  _loadData();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // LISTE DES MOUVEMENTS
                    if (_mouvements.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucun mouvement trouvé',
                              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Modifiez vos filtres ou effectuez une entrée/sortie de stock.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _mouvements.length,
                        itemBuilder: (context, index) {
                          return MouvementStockItem(mouvement: _mouvements[index]);
                        },
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
                  onPressed: () => _ouvrirAjustementStock(isEntree: false),
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: AppTheme.danger),
                  label: const Text('SORTIE STOCK', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.danger, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _ouvrirAjustementStock(isEntree: true),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white),
                  label: const Text('ENTRÉE STOCK', style: TextStyle(fontWeight: FontWeight.w700)),
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

  int _countUniqueArticles() {
    final set = <int>{};
    for (var m in _mouvements) {
      set.add(m.idArticle);
    }
    return set.length;
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    Color? activeColor,
  }) {
    final color = activeColor ?? Colors.black;
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
