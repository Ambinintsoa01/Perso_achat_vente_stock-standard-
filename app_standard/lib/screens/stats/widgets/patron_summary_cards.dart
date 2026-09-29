import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/stats_data.dart';
import '../../../theme/app_theme.dart';

class PatronSummaryCards extends StatelessWidget {
  final DashboardPatronSummary data;
  final NumberFormat currencyFormatter;

  const PatronSummaryCards({
    super.key,
    required this.data,
    required this.currencyFormatter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête de section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 20, color: Colors.black87),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TABLEAU DE BORD PATRON (4 CARTES CLÉS)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Aujourd\'hui',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grille responsive
        LayoutBuilder(
          builder: (context, constraints) {
            final isLargeDesktop = constraints.maxWidth >= 900;
            if (isLargeDesktop) {
              return Row(
                children: [
                  Expanded(child: _buildCaisseJourCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildBeneficeJourCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDettesClientsCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildAlertesStockCard()),
                ],
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildCaisseJourCard()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildBeneficeJourCard()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildDettesClientsCard()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildAlertesStockCard()),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // 1. CARTE CAISSE DU JOUR
  Widget _buildCaisseJourCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'CAISSE DU JOUR',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.point_of_sale_rounded, color: Colors.white70, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currencyFormatter.format(data.caisseJourTotal),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Esp: ${currencyFormatter.format(data.caisseJourEspeces)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Mob: ${currencyFormatter.format(data.caisseJourMobile)}',
                  style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 10, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. CARTE BÉNÉFICE DU JOUR
  Widget _buildBeneficeJourCard() {
    final isPositif = data.beneficeJourMarge >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'BÉNÉFICE DU JOUR',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.trending_up_rounded, color: AppTheme.success, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currencyFormatter.format(data.beneficeJourMarge),
              style: TextStyle(
                color: isPositif ? AppTheme.success : AppTheme.danger,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'CA Ventes : ${currencyFormatter.format(data.ventesJourTotal)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 3. CARTE DETTES À RÉCUPÉRER
  Widget _buildDettesClientsCard() {
    final aDettes = data.dettesClientsTotal > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: aDettes ? const Color(0xFFFCA5A5) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'DETTES CLIENTS',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.pending_actions_rounded, color: AppTheme.danger, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              currencyFormatter.format(data.dettesClientsTotal),
              style: TextStyle(
                color: aDettes ? AppTheme.danger : AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.nbClientsEnRetard} client(s) en attente',
            style: TextStyle(
              color: aDettes ? AppTheme.danger : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 4. CARTE ALERTES STOCK
  Widget _buildAlertesStockCard() {
    final aAlerte = data.alertesStockRupture > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: aAlerte ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: aAlerte ? const Color(0xFFF87171) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'ALERTES STOCK',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.warning_amber_rounded,
                color: aAlerte ? AppTheme.danger : Colors.grey,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${data.alertesStockRupture} réf.',
              style: TextStyle(
                color: aAlerte ? AppTheme.danger : AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            aAlerte ? 'Rupture imminente !' : 'Stock suffisant',
            style: TextStyle(
              color: aAlerte ? AppTheme.danger : AppTheme.success,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
