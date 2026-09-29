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
      padding: const EdgeInsets.all(14),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: badgeColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
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
                    if (mouvement.referencePiece != null && mouvement.referencePiece!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          mouvement.referencePiece!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  mouvement.description?.isNotEmpty == true
                      ? mouvement.description!
                      : (isCredit ? 'Entrée de fonds' : 'Sortie de fonds'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (mouvement.caisseNom != null && mouvement.caisseNom!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              mouvement.caisseNom!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    if (mouvement.modePaiementLibelle != null && mouvement.modePaiementLibelle!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payment_rounded, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: Text(
                              mouvement.modePaiementLibelle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Montant & Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${isCredit ? "+" : "-"} ${currencyFormatter.format(mouvement.montant)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 3),
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
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  'Solde: ${currencyFormatter.format(mouvement.soldeApres)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
