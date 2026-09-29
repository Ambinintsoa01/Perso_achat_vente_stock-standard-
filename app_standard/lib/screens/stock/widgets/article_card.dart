import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/article.dart';
import '../../../theme/app_theme.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onAdjustStock;
  final VoidCallback? onViewMovements;

  const ArticleCard({
    super.key,
    required this.article,
    this.onAdjustStock,
    this.onViewMovements,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'Ar',
      decimalDigits: 0,
    );

    Color getStatusColor() {
      if (article.isRupture) return AppTheme.danger;
      if (article.isAlerteStock) return AppTheme.warning;
      return AppTheme.success;
    }

    Color getStatusBg() {
      if (article.isRupture) return AppTheme.dangerBg;
      if (article.isAlerteStock) return AppTheme.warningBg;
      return AppTheme.successBg;
    }

    String getStatusText() {
      if (article.isRupture) return 'RUPTURE';
      if (article.isAlerteStock) return 'ALERTE STOCK';
      return 'EN STOCK';
    }

    final statusColor = getStatusColor();
    final statusBg = getStatusBg();

    return GestureDetector(
      onTap: onViewMovements,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: article.isRupture ? AppTheme.danger.withValues(alpha: 0.3) : AppTheme.border,
            width: article.isRupture ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          // Vignette visuelle du produit
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: Colors.black87,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),

          // Informations centrales (Désignation, Référence, Catégorie)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        getStatusText(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      article.reference,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  article.designation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (article.categorieNom != null) ...[
                      Text(
                        article.categorieNom!,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(' • ', style: TextStyle(color: Colors.grey.shade400)),
                    ],
                    Text(
                      'Stock: ${article.quantiteStock.toStringAsFixed(article.quantiteStock.truncateToDouble() == article.quantiteStock ? 0 : 2)} ${article.uniteCode ?? "pcs"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Prix & Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFormatter.format(article.prixVenteStandard),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (article.prixAchatEstime > 0) ...[
                const SizedBox(height: 2),
                Text(
                  'Achat: ${currencyFormatter.format(article.prixAchatEstime)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              InkWell(
                onTap: onAdjustStock,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 12, color: Colors.black87),
                      SizedBox(width: 4),
                      Text(
                        'Ajuster',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.black87),
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
  );
}
}
