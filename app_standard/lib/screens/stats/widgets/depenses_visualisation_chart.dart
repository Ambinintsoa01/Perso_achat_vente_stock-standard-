import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/stats_data.dart';
import '../../../theme/app_theme.dart';

class DepensesVisualisationChart extends StatefulWidget {
  final List<DepenseEvolutionPoint> evolutionData;
  final List<DepenseRepartitionItem> repartitionData;
  final NumberFormat currencyFormatter;

  const DepensesVisualisationChart({
    super.key,
    required this.evolutionData,
    required this.repartitionData,
    required this.currencyFormatter,
  });

  @override
  State<DepensesVisualisationChart> createState() => _DepensesVisualisationChartState();
}

class _DepensesVisualisationChartState extends State<DepensesVisualisationChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    // Calculs globaux
    final totalAchats = widget.evolutionData.fold<double>(0.0, (sum, p) => sum + p.montantAchats);
    final totalDivers = widget.evolutionData.fold<double>(0.0, (sum, p) => sum + p.montantDepensesDiverses);
    final totalGlobal = totalAchats + totalDivers;

    final pctAchats = totalGlobal > 0 ? (totalAchats / totalGlobal) * 100 : 0.0;
    final pctDivers = totalGlobal > 0 ? (totalDivers / totalGlobal) * 100 : 0.0;

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
          // Titre
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, color: Colors.black, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'VISUALISATION DES DÉPENSES',
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Achats + Décaissements',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barre visuelle de proportion (Barre segmentée)
          if (totalGlobal > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    if (pctAchats > 0)
                      Expanded(
                        flex: (pctAchats * 10).toInt().clamp(1, 1000),
                        child: Container(color: Colors.black),
                      ),
                    if (pctDivers > 0)
                      Expanded(
                        flex: (pctDivers * 10).toInt().clamp(1, 1000),
                        child: Container(color: Colors.grey.shade400),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Légende des dépenses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Achats
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Achats Fournisseurs (${pctAchats.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                // Divers
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dépenses Diverses (${pctDivers.toStringAsFixed(0)}%)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Badge infobulle interactif
          if (_selectedIndex != null && _selectedIndex! < widget.evolutionData.length) ...[
            Builder(
              builder: (context) {
                final point = widget.evolutionData[_selectedIndex!];
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 12, color: Colors.white70),
                              const SizedBox(width: 6),
                              Text(
                                point.date,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            widget.currencyFormatter.format(point.total),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Achats : ${widget.currencyFormatter.format(point.montantAchats)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Text(
                            'Divers : ${widget.currencyFormatter.format(point.montantDepensesDiverses)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Graphe en barres superposées/empilées
          if (widget.evolutionData.isEmpty)
            Container(
              height: 150,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 36, color: Colors.black26),
                  SizedBox(height: 6),
                  Text(
                    'Aucune dépense enregistrée sur cette période',
                    style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          else
            _buildStackedBarChart(),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Ligne de résumé financier
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Achats', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.currencyFormatter.format(totalAchats),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Dépenses Diverses', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        widget.currencyFormatter.format(totalDivers),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Total Charges', style: TextStyle(color: AppTheme.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        widget.currencyFormatter.format(totalGlobal),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.danger),
                      ),
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

  Widget _buildStackedBarChart() {
    final maxTotal = widget.evolutionData.fold<double>(0.0, (m, p) => max(m, p.total));
    final safeMax = maxTotal > 0 ? maxTotal : 1.0;

    return SizedBox(
      height: 170,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableHeight = constraints.maxHeight;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(widget.evolutionData.length, (index) {
                    final point = widget.evolutionData[index];
                    final heightFactor = (point.total / safeMax).clamp(0.05, 1.0);
                    final barHeight = (availableHeight * heightFactor).clamp(6.0, availableHeight);
                    final isSelected = _selectedIndex == index;

                    // Hauteurs relatives au sein de la barre empilée
                    final double ratioAchats = point.total > 0 ? (point.montantAchats / point.total) : 1.0;
                    final double ratioDivers = point.total > 0 ? (point.montantDepensesDiverses / point.total) : 0.0;

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
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: barHeight,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
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
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                child: Column(
                                  children: [
                                    // Partie haute: Dépenses diverses (Gris)
                                    if (ratioDivers > 0)
                                      Expanded(
                                        flex: (ratioDivers * 100).toInt().clamp(1, 100),
                                        child: Container(color: Colors.grey.shade400),
                                      ),
                                    // Partie basse: Achats fournisseurs (Noir)
                                    if (ratioAchats > 0)
                                      Expanded(
                                        flex: (ratioAchats * 100).toInt().clamp(1, 100),
                                        child: Container(color: Colors.black),
                                      ),
                                  ],
                                ),
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
          // Dates abrégées sur l'axe X
          Row(
            children: List.generate(widget.evolutionData.length, (index) {
              final rawDate = widget.evolutionData[index].date;
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
