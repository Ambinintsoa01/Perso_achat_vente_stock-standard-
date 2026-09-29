import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/caisse.dart';
import '../../models/mode_paiement.dart';
import '../../models/mouvement_caisse.dart';
import '../../services/auth_service.dart';
import '../../services/caisse_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/access_denied_screen.dart';
import '../../widgets/date_filter_bar.dart';
import '../../widgets/user_avatar_button.dart';
import 'widgets/caisse_card.dart';
import 'widgets/mouvement_item.dart';
import 'widgets/nouveau_mouvement_dialog.dart';
import 'widgets/transfert_interne_dialog.dart';

class CaisseScreen extends StatefulWidget {
  const CaisseScreen({super.key});

  @override
  State<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends State<CaisseScreen> {
  final CaisseService _caisseService = CaisseService();
  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  List<Caisse> _caisses = [];
  List<MouvementCaisse> _mouvements = [];
  List<ModePaiement> _modesPaiement = [];
  double _totalTresorerie = 0.0;
  int? _selectedCaisseFilter;
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
      final caisses = await _caisseService.getCaisses();
      final total = await _caisseService.getTotalTresorerie();
      final mouvements = await _caisseService.getMouvements(
        idCaisse: _selectedCaisseFilter,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      final modes = await _caisseService.getModesPaiement();

      if (mounted) {
        setState(() {
          _caisses = caisses;
          _totalTresorerie = total;
          _mouvements = mouvements;
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

  void _ouvrirNouveauMouvement() {
    showDialog(
      context: context,
      builder: (context) => NouveauMouvementDialog(
        caisses: _caisses,
        modesPaiement: _modesPaiement,
        selectedCaisseId: _selectedCaisseFilter,
        onSuccess: _loadData,
      ),
    );
  }

  void _ouvrirVirementInterne() {
    showDialog(
      context: context,
      builder: (context) => TransfertInterneDialog(
        caisses: _caisses,
        onSuccess: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calcul de la répartition
    double totalCash = 0;
    double totalMobile = 0;
    double totalBanque = 0;

    for (var c in _caisses) {
      if (c.code.contains('CSH') || c.idTypeCaisse == 1) {
        totalCash += c.soldeActuel;
      } else if (c.idTypeCaisse == 3) {
        totalMobile += c.soldeActuel;
      } else if (c.idTypeCaisse == 2) {
        totalBanque += c.soldeActuel;
      }
    }

    // Détection de la caisse sélectionnée
    Caisse? selectedCaisse;
    if (_selectedCaisseFilter != null) {
      try {
        selectedCaisse = _caisses.firstWhere((c) => c.id == _selectedCaisseFilter);
      } catch (_) {
        selectedCaisse = null;
      }
    }

    final double montantAffiche = selectedCaisse != null 
        ? selectedCaisse.soldeActuel 
        : _totalTresorerie;

    final String titreAffiche = selectedCaisse != null
        ? 'SOLDE : ${selectedCaisse.nom.toUpperCase()}'
        : 'DISPONIBLE TOTAL';

    final user = AuthService.instance.currentUser;
    if (user != null && !user.profil.canAccessCaisse) {
      return const AccessDeniedScreen(
        moduleName: 'Caisse & Trésorerie',
        profilsRequis: 'Caissier, Gérant, Administrateur',
      );
    }
    final canTransfert = user == null || user.profil.canFaireTransfertCaisse;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'CAISSE & TRÉSORERIE',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          if (canTransfert)
            IconButton(
              tooltip: 'Virement interne',
              icon: const Icon(Icons.swap_horiz_rounded, size: 24),
              onPressed: _ouvrirVirementInterne,
            ),
          IconButton(
            tooltip: 'Nouvelle opération',
            icon: const Icon(Icons.add_rounded, size: 24),
            onPressed: _ouvrirNouveauMouvement,
          ),
          const UserAvatarButton(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : RefreshIndicator(
              color: Colors.black,
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARTE NOIRE MODERNE : TOTAL TRÉSORERIE OU SOLDE COMPTE SÉLECTIONNÉ
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
                              Expanded(
                                child: Text(
                                  titreAffiche,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (selectedCaisse != null)
                                InkWell(
                                  onTap: () {
                                    setState(() => _selectedCaisseFilter = null);
                                    _loadData();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.20),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white30),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Voir global',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.close_rounded, size: 14, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_caisses.length} comptes actifs',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              currencyFormatter.format(montantAffiche),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          // Ventilation rapide OU détails du compte sélectionné
                          if (selectedCaisse != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSummaryMiniBadge(
                                  title: 'Trésorerie globale',
                                  amount: _totalTresorerie,
                                  icon: Icons.account_balance_wallet_rounded,
                                ),
                                _buildSummaryMiniBadge(
                                  title: 'Solde initial',
                                  amount: selectedCaisse.soldeInitial,
                                  icon: Icons.history_rounded,
                                ),
                                _buildSummaryMiniBadge(
                                  title: 'Type / Compte',
                                  valueText: selectedCaisse.numeroCompte?.isNotEmpty == true
                                      ? selectedCaisse.numeroCompte!
                                      : (selectedCaisse.typeLibelle ?? selectedCaisse.code),
                                  icon: Icons.tag_rounded,
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildSummaryMiniBadge(
                                  title: 'Espèces (Cash)',
                                  amount: totalCash,
                                  icon: Icons.point_of_sale_rounded,
                                ),
                                _buildSummaryMiniBadge(
                                  title: 'Mobile Money',
                                  amount: totalMobile,
                                  icon: Icons.phone_android_rounded,
                                ),
                                _buildSummaryMiniBadge(
                                  title: 'Banque',
                                  amount: totalBanque,
                                  icon: Icons.account_balance_rounded,
                                ),
                              ],
                            ),
                          const SizedBox(height: 18),
                          // Boutons d'action rapide sur la carte noire
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _ouvrirNouveauMouvement,
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.black),
                                  label: const Text('Opération', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _ouvrirVirementInterne,
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.white),
                                  label: const Text('Virement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.white38),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // SECTION COMPTES & CAISSES (CAROUSEL HORIZONTAL)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'COMPTES & CAISSES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (_selectedCaisseFilter != null)
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedCaisseFilter = null);
                              _loadData();
                            },
                            child: const Text('Voir tout', style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _caisses.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final caisse = _caisses[index];
                          final isSelected = _selectedCaisseFilter == caisse.id;
                          return CaisseCard(
                            caisse: caisse,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                if (_selectedCaisseFilter == caisse.id) {
                                  _selectedCaisseFilter = null;
                                } else {
                                  _selectedCaisseFilter = caisse.id;
                                }
                              });
                              _loadData();
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 26),

                    // SECTION HISTORIQUE DES MOUVEMENTS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedCaisseFilter != null
                                ? 'OPÉRATIONS : ${_caisses.firstWhere((c) => c.id == _selectedCaisseFilter).nom.toUpperCase()}'
                                : 'DERNIÈRES OPÉRATIONS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_mouvements.length} lignes',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
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

                    // LISTE DES TRANSACTIONS
                    if (_mouvements.isEmpty)
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
                            Icon(Icons.receipt_long_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Aucune opération enregistrée',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Cliquez sur "+ Opération" pour enregistrer un encaissement ou une dépense.',
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
                        itemCount: _mouvements.length,
                        itemBuilder: (context, index) {
                          return MouvementItem(mouvement: _mouvements[index]);
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
      // BARRE D'ACTIONS FLOTTANTE DU BAS (Inspirée de la maquette "FILTER" / "NOUVEAU")
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (canTransfert) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ouvrirVirementInterne,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.black),
                    label: const Text(
                      'VIREMENT INTERNE',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _ouvrirNouveauMouvement,
                  icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                  label: const Text(
                    'OPÉRATION CAISSE',
                    style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                  ),
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

  Widget _buildSummaryMiniBadge({
    required String title,
    double? amount,
    String? valueText,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valueText ?? (amount != null ? currencyFormatter.format(amount) : '-'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
