import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/journal_caisse.dart';
import '../../../services/caisse_service.dart';
import '../../../theme/app_theme.dart';

class JournalCaisseDetailsDialog extends StatefulWidget {
  final int idJournal;

  const JournalCaisseDetailsDialog({
    super.key,
    required this.idJournal,
  });

  @override
  State<JournalCaisseDetailsDialog> createState() => _JournalCaisseDetailsDialogState();
}

class _JournalCaisseDetailsDialogState extends State<JournalCaisseDetailsDialog> {
  final CaisseService _caisseService = CaisseService();
  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  JournalCaisse? _journal;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final j = await _caisseService.getJournalDetails(widget.idJournal);
      if (mounted) {
        setState(() {
          _journal = j;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: Colors.black)),
        ),
      );
    }

    if (_journal == null) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Journal introuvable'),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
            ],
          ),
        ),
      );
    }

    final j = _journal!;
    final isOuvert = j.isOuvert;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              j.numeroJournal,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOuvert ? const Color(0xFFE8F5E9) : Colors.black.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isOuvert ? 'OUVERT' : 'CLÔTURÉ',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isOuvert ? const Color(0xFF2E7D32) : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date : ${j.dateJournal}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Synthèse Carte Noire
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSummaryItem('REPORT OUVERTURE', j.soldeOuvertureTotal, Colors.white),
                        _buildSummaryItem('ENTRÉES (+)', j.totalEntrees, const Color(0xFFA5D6A7)),
                        _buildSummaryItem('SORTIES (-)', j.totalSorties, const Color(0xFFEF9A9A)),
                        _buildSummaryItem('THÉORIQUE', j.soldeTheoriqueTotal, Colors.white),
                      ],
                    ),
                    if (!isOuvert) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryItem('RÉEL COMPTÉ', j.soldeReelTotal, Colors.white, isBold: true),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: j.hasEcart
                                  ? (j.ecartTotal > 0 ? const Color(0xFFEF6C00) : const Color(0xFFC62828))
                                  : const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              j.hasEcart
                                  ? 'Écart : ${j.ecartTotal >= 0 ? '+' : ''}${currencyFormatter.format(j.ecartTotal)}'
                                  : '✓ Écart : 0 Ar (Parfait)',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Informations Caissiers & Horodatage
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ouvert par :', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                          Text(
                            '${j.nomUtilisateurOuverture ?? 'Utilisateur #${j.idUtilisateurOuverture}'} (${j.dateOuverture.substring(11, 16)})',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (j.dateFermeture != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Clôturé par :', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                            Text(
                              '${j.nomUtilisateurFermeture ?? 'Utilisateur'} (${j.dateFermeture!.substring(11, 16)})',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Détail des comptes de caisse (lignes)
              const Text(
                'DÉTAIL PAR COMPTE DE CAISSE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: j.lignes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final l = j.lignes[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l.caisseNom ?? 'Compte #${l.idCaisse}',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              if (l.soldeReel != null)
                                Text(
                                  'Réel : ${currencyFormatter.format(l.soldeReel!)}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Report: ${currencyFormatter.format(l.soldeOuverture)} | +${currencyFormatter.format(l.totalEntrees)} | -${currencyFormatter.format(l.totalSorties)}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              Text(
                                'Théorique: ${currencyFormatter.format(l.soldeTheorique)}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (l.hasEcart) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Écart: ${l.ecart >= 0 ? '+' : ''}${currencyFormatter.format(l.ecart)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: l.ecart > 0 ? const Color(0xFFEF6C00) : const Color(0xFFC62828),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              if (j.notesOuverture != null || j.notesFermeture != null) ...[
                const SizedBox(height: 12),
                if (j.notesOuverture != null)
                  Text('Notes ouverture : ${j.notesOuverture}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                if (j.notesFermeture != null)
                  Text('Notes fermeture : ${j.notesFermeture}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 16),

              // Bouton Fermer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('FERMER', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, double amount, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            currencyFormatter.format(amount),
            style: TextStyle(color: color, fontSize: 13, fontWeight: isBold ? FontWeight.w800 : FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
