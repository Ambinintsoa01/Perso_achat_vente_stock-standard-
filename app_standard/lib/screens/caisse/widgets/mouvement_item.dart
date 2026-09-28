import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/mouvement_caisse.dart';
import '../../../theme/app_theme.dart';

class MouvementItem extends StatelessWidget {
  final MouvementCaisse mouvement;

  const MouvementItem({super.key, required this.mouvement});

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'Ar',
      decimalDigits: 0,
    );

    final isCredit = mouvement.isCredit;
    final badgeColor = isCredit ? AppTheme.success : AppTheme.danger;
    final badgeBg = isCredit ? AppTheme.successBg : AppTheme.dangerBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icône circulaire de sens
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: badgeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Description & Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mouvement.typeLibelle ?? (isCredit ? 'ENCAISSEMENT' : 'DÉCAISSEMENT'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (mouvement.referencePiece != null)
                      Text(
                        mouvement.referencePiece!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  mouvement.description?.isNotEmpty == true
                      ? mouvement.description!
                      : (isCredit ? 'Entrée de fonds' : 'Sortie de fonds'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      mouvement.caisseNom ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.payment_rounded, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      mouvement.modePaiementLibelle ?? '',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Montant & Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? "+" : "-"} ${currencyFormatter.format(mouvement.montant)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mouvement.dateMouvement.length >= 16
                    ? mouvement.dateMouvement.substring(5, 16)
                    : mouvement.dateMouvement,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Solde: ${currencyFormatter.format(mouvement.soldeApres)}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
