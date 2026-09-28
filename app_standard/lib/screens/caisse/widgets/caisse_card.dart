import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/caisse.dart';
import '../../../theme/app_theme.dart';

class CaisseCard extends StatelessWidget {
  final Caisse caisse;
  final bool isSelected;
  final VoidCallback onTap;

  const CaisseCard({
    super.key,
    required this.caisse,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'Ar',
      decimalDigits: 0,
    );

    IconData getIcon() {
      if (caisse.code.contains('CSH') || caisse.nom.toLowerCase().contains('espèces')) {
        return Icons.point_of_sale_rounded;
      } else if (caisse.code.contains('MVOLA') || caisse.nom.toLowerCase().contains('mvola')) {
        return Icons.phone_android_rounded;
      } else if (caisse.code.contains('OM') || caisse.nom.toLowerCase().contains('orange')) {
        return Icons.phone_iphone_rounded;
      } else {
        return Icons.account_balance_rounded;
      }
    }

    Color getAccentColor() {
      if (caisse.code.contains('CSH') || caisse.nom.toLowerCase().contains('espèces')) {
        return AppTheme.cashColor;
      } else if (caisse.code.contains('MVOLA') || caisse.nom.toLowerCase().contains('mvola')) {
        return AppTheme.mvola;
      } else if (caisse.code.contains('OM') || caisse.nom.toLowerCase().contains('orange')) {
        return AppTheme.orangeMoney;
      } else {
        return AppTheme.bankColor;
      }
    }

    final accent = getAccentColor();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.black : AppTheme.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.15) : accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    getIcon(),
                    color: isSelected ? Colors.white : accent,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    caisse.typeLibelle ?? 'Compte',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caisse.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                if (caisse.numeroCompte != null && caisse.numeroCompte!.isNotEmpty)
                  Text(
                    caisse.numeroCompte!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(caisse.soldeActuel),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

