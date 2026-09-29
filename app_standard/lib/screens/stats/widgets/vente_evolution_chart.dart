import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/article.dart';
import '../../../models/categorie.dart';
import '../../../models/stats_data.dart';
import '../../../theme/app_theme.dart';

class VenteEvolutionChart extends StatefulWidget {
  final List<VenteEvolutionPoint> data;
  final List<Categorie> categories;
  final List<Article> articles;
  final int? selectedCategorieId;
  final int? selectedArticleId;
  final Function(int? idCategorie) onCategorieChanged;
  final Function(int? idArticle) onArticleChanged;
  final NumberFormat currencyFormatter;

  const VenteEvolutionChart({
    super.key,
    required this.data,
    required this.categories,
    required this.articles,
    this.selectedCategorieId,
    this.selectedArticleId,
    required this.onCategorieChanged,
    required this.onArticleChanged,
    required this.currencyFormatter,
  });

  @override
  State<VenteEvolutionChart> createState() => _VenteEvolutionChartState();
}

class _VenteEvolutionChartState extends State<VenteEvolutionChart> {
  int? _selectedIndex;
  bool _showMontant = true; // true = Montant Ar, false = Quantité

  @override
  Widget build(BuildContext context) {
    // Calculs de synthèse sur la sélection active
    final totalMontant = widget.data.fold<double>(0.0, (sum, p) => sum + p.montant);
    final totalQuantite = widget.data.fold<double>(0.0, (sum, p) => sum + p.quantite);
    final totalCommandes = widget.data.fold<int>(0, (sum, p) => sum + p.nombreCommandes);

    // Produits filtrés par catégorie active pour le dropdown produit
    final articlesFiltres = widget.selectedCategorieId == null
        ? widget.articles
        : widget.articles.where((a) => a.idCategorie == widget.selectedCategorieId).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Titre et sélecteur de mode (Montant vs Quantité)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.trending_up_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'ÉVOLUTION DES VENTES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Segmented Toggle Montant / Qté
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showMontant = true),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showMontant ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Montant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _showMontant ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _showMontant = false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: !_showMontant ? Colors.black : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Quantité',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: !_showMontant ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Ligne de Filtres : Catégorie & Produit (isExpanded: true)
          Row(
            children: [
              // Filtre Catégorie
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Catégorie',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: widget.selectedCategorieId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Toutes les catégories', overflow: TextOverflow.ellipsis),
                        ),
                        ...widget.categories.map((c) {
                          return DropdownMenuItem<int?>(
                            value: c.id,
                            child: Text(c.nom, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        widget.onCategorieChanged(val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Filtre Produit
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Produit',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: widget.selectedArticleId,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tous les produits', overflow: TextOverflow.ellipsis),
                        ),
                        ...articlesFiltres.map((a) {
                          return DropdownMenuItem<int?>(
                            value: a.id,
                            child: Text(a.designation, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        widget.onArticleChanged(val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Badge infobulle interactif si un jour est sélectionné
          if (_selectedIndex != null && _selectedIndex! < widget.data.length) ...[
            Builder(
              builder: (context) {
                final point = widget.data[_selectedIndex!];
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 13, color: Colors.white70),
                          const SizedBox(width: 6),
                          Text(
                            point.date,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      Text(
                        _showMontant
                            ? widget.currencyFormatter.format(point.montant)
                            : '${point.quantite.toStringAsFixed(0)} unités (${widget.currencyFormatter.format(point.montant)})',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Graphe en barres interactif
          if (widget.data.isEmpty)
            Container(
              height: 160,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 36, color: Colors.black26),
                  SizedBox(height: 6),
                  Text(
                    'Aucune vente enregistrée pour ces critères',
                    style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            _buildInteractiveBarChart(),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Synthèse de la sélection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Ventes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.currencyFormatter.format(totalMontant),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Quantité vendue', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    Text(
                      '${totalQuantite.toStringAsFixed(0)} unités',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Commandes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    Text(
                      '$totalCommandes',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveBarChart() {
    final values = widget.data.map((p) => _showMontant ? p.montant : p.quantite).toList();
    final maxValue = values.fold<double>(0.0, (m, v) => max(m, v));
    final safeMax = maxValue > 0 ? maxValue : 1.0;

    return SizedBox(
      height: 180,
      child: Column(
        children: [
          // Zone des barres
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(widget.data.length, (index) {
                    final point = widget.data[index];
                    final val = _showMontant ? point.montant : point.quantite;
                    final heightFactor = (val / safeMax).clamp(0.05, 1.0);
                    final barHeight = (availableHeight * heightFactor).clamp(6.0, availableHeight);
                    final isSelected = _selectedIndex == index;

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            if (_selectedIndex == index) {
                              _selectedIndex = null;
                            } else {
                              _selectedIndex = index;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: barHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black
                                    : (val > 0 ? Colors.black87 : Colors.grey.shade300),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                border: isSelected
                                    ? Border.all(color: Colors.black, width: 2)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Ligne d'axe X (dates abrégées)
          Row(
            children: List.generate(widget.data.length, (index) {
              final rawDate = widget.data[index].date;
              // Format date court: '29/09'
              String label = rawDate;
              if (rawDate.length >= 10) {
                label = '${rawDate.substring(8, 10)}/${rawDate.substring(5, 7)}';
              }
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.black45,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
