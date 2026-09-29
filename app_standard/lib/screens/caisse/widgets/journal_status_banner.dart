import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/journal_caisse.dart';
import '../../../theme/app_theme.dart';

class JournalStatusBanner extends StatelessWidget {
  final JournalCaisse? journal;
  final VoidCallback onOuvrirCaisse;
  final VoidCallback onCloturerCaisse;
  final VoidCallback onVoirDetails;

  const JournalStatusBanner({
    super.key,
    required this.journal,
    required this.onOuvrirCaisse,
    required this.onCloturerCaisse,
    required this.onVoirDetails,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'Ar',
      decimalDigits: 0,
    );

    // CAS 1 : Caisse fermée / Non encore ouverte ce jour
    if (journal == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Colors.black87,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JOURNAL DE CAISSE FERMÉ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Ouvrez la session du matin pour synchroniser les soldes de départ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onOuvrirCaisse,
              icon: const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.white),
              label: const Text(
                'OUVRIR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    // CAS 2 : Caisse OUVERTE
    final j = journal!;
    double sumEntrees = 0;
    double sumSorties = 0;
    double sumTheorique = 0;

    for (final l in j.lignes) {
      sumEntrees += l.totalEntrees;
      sumSorties += l.totalSorties;
      sumTheorique += l.soldeTheorique;
    }

    String heureOuverture = '';
    try {
      final dt = DateTime.parse(j.dateOuverture);
      heureOuverture = DateFormat('HH:mm').format(dt);
    } catch (_) {
      heureOuverture = j.dateOuverture;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : Badge statut vert + N° Journal + Heure
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'CAISSE OUVERTE',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${j.numeroJournal} • Ouverte à $heureOuverture',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              InkWell(
                onTap: onVoirDetails,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Détails',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),

          // Grille des 4 indicateurs clés de la session en cours
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  title: 'Report matin',
                  amount: currencyFormatter.format(j.soldeOuvertureTotal),
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  title: 'Entrées jour',
                  amount: '+${currencyFormatter.format(sumEntrees)}',
                  color: const Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  title: 'Sorties jour',
                  amount: '-${currencyFormatter.format(sumSorties)}',
                  color: const Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMiniStat(
                  title: 'Théorique actuel',
                  amount: currencyFormatter.format(sumTheorique),
                  color: Colors.black,
                  isBold: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bouton clôturer la caisse du soir
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCloturerCaisse,
              icon: const Icon(Icons.nights_stay_outlined, size: 16, color: Colors.black),
              label: const Text(
                'CLÔTURER LA CAISSE (SOIR)',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat({
    required String title,
    required String amount,
    required Color color,
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
