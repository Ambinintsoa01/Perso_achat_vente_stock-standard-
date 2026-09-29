import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/caisse.dart';
import '../../models/commande_achat.dart';
import '../../models/mode_paiement.dart';
import '../../services/achat_service.dart';
import '../../services/caisse_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_filter_bar.dart';
import 'nouvel_achat_screen.dart';
import 'widgets/commande_achat_card.dart';
import 'widgets/nouveau_fournisseur_dialog.dart';
import 'widgets/regler_dette_dialog.dart';

class AchatScreen extends StatefulWidget {
  const AchatScreen({super.key});

  @override
  State<AchatScreen> createState() => _AchatScreenState();
}

class _AchatScreenState extends State<AchatScreen> {
  final AchatService _achatService = AchatService();
  final CaisseService _caisseService = CaisseService();

  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  List<CommandeAchat> _commandes = [];
  List<Caisse> _caisses = [];
  List<ModePaiement> _modesPaiement = [];
  AchatSummary? _summary;

  bool _onlyUnpaid = false;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _achatService.getAchatSummary();
      final commandes = await _achatService.getCommandesAchat(
        onlyUnpaid: _onlyUnpaid,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      final caisses = await _caisseService.getCaisses();
      final modes = await _caisseService.getModesPaiement();

      if (mounted) {
        setState(() {
          _summary = summary;
          _commandes = commandes;
          _caisses = caisses;
          _modesPaiement = modes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _ouvrirNouvelAchat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NouvelAchatScreen()),
    ).then((_) => _loadData());
  }

  void _ouvrirNouveauFournisseur() {
    showDialog(
      context: context,
      builder: (context) => NouveauFournisseurDialog(
        onSupplierCreated: (_) => _loadData(),
      ),
    );
  }

  void _ouvrirReglementDette(CommandeAchat commande) {
    showDialog(
      context: context,
      builder: (context) => ReglerDetteDialog(
        commande: commande,
        caisses: _caisses,
        modesPaiement: _modesPaiement,
        onSuccess: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'ACHATS & FOURNISSEURS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nouveau Fournisseur',
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
            onPressed: _ouvrirNouveauFournisseur,
          ),
          IconButton(
            tooltip: 'Nouvel Achat',
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _ouvrirNouvelAchat,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARTE NOIRE DU PATRON : DETTES FOURNISSEURS & TOTAL ACHATS
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'DETTES FOURNISSEURS EN COURS',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              if ((_summary?.totalDettesFournisseurs ?? 0) > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.danger,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'À payer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            currencyFormatter.format(_summary?.totalDettesFournisseurs ?? 0),
                            style: TextStyle(
                              color: (_summary?.totalDettesFournisseurs ?? 0) > 0 ? const Color(0xFFFCA5A5) : Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total achats cumulés', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormatter.format(_summary?.totalAchatsMois ?? 0),
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Commandes passées', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_summary?.nombreCommandes ?? 0} achats',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // FILTRE ONGLETS (TOUS LES ACHATS vs DETTES SEULEMENT)
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Tous les achats'),
                          selected: !_onlyUnpaid,
                          selectedColor: Colors.black,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: !_onlyUnpaid ? Colors.white : AppTheme.textPrimary,
                          ),
                          backgroundColor: const Color(0xFFF3F4F6),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _onlyUnpaid = false);
                              _loadData();
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pending_actions_rounded, size: 14, color: AppTheme.danger),
                              const SizedBox(width: 4),
                              Text(
                                'Dettes fournisseurs',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _onlyUnpaid ? Colors.white : AppTheme.danger,
                                ),
                              ),
                            ],
                          ),
                          selected: _onlyUnpaid,
                          selectedColor: AppTheme.danger,
                          backgroundColor: AppTheme.dangerBg,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _onlyUnpaid = true);
                              _loadData();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // FILTRE PAR DATE
                    DateFilterBar(
                      initialStartDate: _dateDebut,
                      initialEndDate: _dateFin,
                      onDateRangeChanged: (start, end) {
                        setState(() {
                          _dateDebut = start;
                          _dateFin = end;
                        });
                        _loadData();
                      },
                    ),
                    const SizedBox(height: 16),

                    // LISTE DES COMMANDES D'ACHAT
                    if (_commandes.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _onlyUnpaid ? 'Aucune dette fournisseur en cours !' : 'Aucun achat enregistré',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Enregistrez vos achats grossistes pour suivre vos stocks et décaissements.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _commandes.length,
                        itemBuilder: (context, index) {
                          final cmd = _commandes[index];
                          return CommandeAchatCard(
                            commande: cmd,
                            onRegler: !cmd.estPaye ? () => _ouvrirReglementDette(cmd) : null,
                          );
                        },
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _ouvrirNouveauFournisseur,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18, color: Colors.black),
                  label: const Text('+ FOURNISSEUR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.black, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ouvrirNouvelAchat,
                  icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  label: const Text('+ NOUVEL ACHAT', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
