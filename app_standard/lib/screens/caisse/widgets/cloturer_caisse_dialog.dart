import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/journal_caisse.dart';
import '../../../services/auth_service.dart';
import '../../../services/caisse_service.dart';
import '../../../theme/app_theme.dart';

class CloturerCaisseDialog extends StatefulWidget {
  final JournalCaisse journal;
  final VoidCallback onSuccess;

  const CloturerCaisseDialog({
    super.key,
    required this.journal,
    required this.onSuccess,
  });

  @override
  State<CloturerCaisseDialog> createState() => _CloturerCaisseDialogState();
}

class _CloturerCaisseDialogState extends State<CloturerCaisseDialog> {
  final CaisseService _caisseService = CaisseService();
  final Map<int, TextEditingController> _controllers = {};
  final TextEditingController _notesController = TextEditingController();
  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  bool _isLoading = true;
  bool _isSaving = false;
  List<JournalCaisseLigne> _lignes = [];

  @override
  void initState() {
    super.initState();
    _chargerLignes();
  }

  Future<void> _chargerLignes() async {
    try {
      final lignes = await _caisseService.getLignesJournalAvecTotaux(widget.journal.id);
      for (final l in lignes) {
        // Pré-remplir avec le solde théorique calculé
        final initVal = l.soldeTheorique;
        _controllers[l.idCaisse] = TextEditingController(text: initVal.toStringAsFixed(0));
      }
      if (mounted) {
        setState(() {
          _lignes = lignes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  double _getMontantReel(int idCaisse) {
    final text = _controllers[idCaisse]?.text.replaceAll(' ', '') ?? '0';
    return double.tryParse(text) ?? 0;
  }

  double _calculerTotalReel() {
    double total = 0;
    for (final l in _lignes) {
      total += _getMontantReel(l.idCaisse);
    }
    return total;
  }

  double _calculerTotalTheorique() {
    double total = 0;
    for (final l in _lignes) {
      total += l.soldeTheorique;
    }
    return total;
  }

  Future<void> _validerCloture() async {
    final user = AuthService.instance.currentUser;
    final userId = user?.id ?? 1;

    final Map<int, double> reels = {};
    for (final l in _lignes) {
      reels[l.idCaisse] = _getMontantReel(l.idCaisse);
    }

    setState(() => _isSaving = true);
    try {
      await _caisseService.fermerJournal(
        idJournal: widget.journal.id,
        idUtilisateurFermeture: userId,
        soldesReelsParCaisse: reels,
        notesFermeture: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1B5E20),
            content: Text('✓ Caisse clôturée avec succès. Les soldes sont enregistrés pour demain !'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalTheorique = _calculerTotalTheorique();
    final totalReel = _calculerTotalReel();
    final ecartTotal = totalReel - totalTheorique;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 780),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: Colors.black)),
              )
            : Padding(
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
                          child: const Icon(Icons.nights_stay_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CLÔTURE DE CAISSE (SOIR)',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.journal.numeroJournal} • Arrêté des comptes du soir',
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

                    // Synthèse Carte Noire : Théorique vs Réel compté
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL THÉORIQUE',
                                      style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        currencyFormatter.format(totalTheorique),
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TOTAL RÉEL COMPTÉ',
                                      style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        currencyFormatter.format(totalReel),
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Badge écart
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ecartTotal.abs() < 0.01
                                      ? const Color(0xFF2E7D32).withValues(alpha: 0.25)
                                      : (ecartTotal > 0
                                          ? const Color(0xFFEF6C00).withValues(alpha: 0.25)
                                          : const Color(0xFFC62828).withValues(alpha: 0.25)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ecartTotal.abs() < 0.01
                                        ? const Color(0xFF81C784)
                                        : (ecartTotal > 0 ? const Color(0xFFFFB74D) : const Color(0xFFE57373)),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      ecartTotal.abs() < 0.01
                                          ? 'ÉQUILIBRÉ'
                                          : (ecartTotal > 0 ? 'EXCÉDENT' : 'MANQUANT'),
                                      style: TextStyle(
                                        color: ecartTotal.abs() < 0.01
                                            ? const Color(0xFF81C784)
                                            : (ecartTotal > 0 ? const Color(0xFFFFB74D) : const Color(0xFFE57373)),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${ecartTotal >= 0 ? '+' : ''}${currencyFormatter.format(ecartTotal)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lignes par compte (scrollable)
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _lignes.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final l = _lignes[index];
                          final controller = _controllers[l.idCaisse];
                          final montantReel = _getMontantReel(l.idCaisse);
                          final ecartLigne = montantReel - l.soldeTheorique;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l.caisseNom ?? 'Compte #${l.idCaisse}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    // Mini badge écart
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: ecartLigne.abs() < 0.01
                                            ? const Color(0xFFE8F5E9)
                                            : (ecartLigne > 0 ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        ecartLigne.abs() < 0.01
                                            ? '✓ 0 Ar'
                                            : '${ecartLigne > 0 ? '+' : ''}${currencyFormatter.format(ecartLigne)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: ecartLigne.abs() < 0.01
                                              ? const Color(0xFF2E7D32)
                                              : (ecartLigne > 0 ? const Color(0xFFE65100) : const Color(0xFFC62828)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Détail des flux : Ouverture + Entrées - Sorties = Théorique
                                Text(
                                  'Matin: ${currencyFormatter.format(l.soldeOuverture)} | Entrées: +${currencyFormatter.format(l.totalEntrees)} | Sorties: -${currencyFormatter.format(l.totalSorties)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Saisie du montant réel compté
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Attendu : ${currencyFormatter.format(l.soldeTheorique)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      child: TextField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.right,
                                        onChanged: (_) => setState(() {}),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Réel compté',
                                          suffixText: 'Ar',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Colors.black26),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(color: Colors.black, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Champ d'observations de clôture
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Observations de clôture (justification si écart...)',
                        hintText: 'Ex: Comptage physique vérifié, écart de 200 Ar...',
                        labelStyle: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black26),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Boutons d'action
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Colors.black26),
                            ),
                            child: const Text('ANNULER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _validerCloture,
                            icon: _isSaving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
                            label: Text(
                              _isSaving ? 'CLÔTURE...' : 'VALIDER LA CLÔTURE (SOIR)',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
