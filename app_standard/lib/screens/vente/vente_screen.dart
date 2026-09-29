import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/caisse.dart';
import '../../models/commande_vente.dart';
import '../../models/mode_paiement.dart';
import '../../services/auth_service.dart';
import '../../services/caisse_service.dart';
import '../../services/vente_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/access_denied_screen.dart';
import '../../widgets/date_filter_bar.dart';
import '../../widgets/sync_button.dart';
import '../../widgets/user_avatar_button.dart';
import 'nouvelle_vente_screen.dart';
import 'widgets/commande_vente_card.dart';
import 'widgets/encaisser_creance_dialog.dart';
import 'widgets/nouveau_client_dialog.dart';

class VenteScreen extends StatefulWidget {
  const VenteScreen({super.key});

  @override
  State<VenteScreen> createState() => _VenteScreenState();
}

class _VenteScreenState extends State<VenteScreen> {
  final VenteService _venteService = VenteService();
  final CaisseService _caisseService = CaisseService();

  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  List<CommandeVente> _commandes = [];
  List<Caisse> _caisses = [];
  List<ModePaiement> _modesPaiement = [];
  VenteSummary? _summary;

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
      final summary = await _venteService.getVenteSummary();
      final commandes = await _venteService.getCommandesVente(
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

  void _ouvrirNouvelleVente() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NouvelleVenteScreen()),
    ).then((_) => _loadData());
  }

  void _ouvrirNouveauClient() {
    showDialog(
      context: context,
      builder: (context) => NouveauClientDialog(
        onClientCreated: (_) => _loadData(),
      ),
    );
  }

  void _ouvrirEncaissementCreance(CommandeVente commande) {
    showDialog(
      context: context,
      builder: (context) => EncaisserCreanceDialog(
        commande: commande,
        caisses: _caisses,
        modesPaiement: _modesPaiement,
        onSuccess: _loadData,
      ),
    );
  }

  void _afficherDetailsCommande(CommandeVente commande) async {
    final lignes = await _venteService.getLignesCommande(commande.id);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            commande.numeroCommande,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Client : ${commande.clientNom ?? "Client Comptoir"} • ${commande.dateCommande}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'ARTICLES VENDUS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.textSecondary, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: lignes.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                    itemBuilder: (context, index) {
                      final l = lignes[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l.articleDesignation ?? 'Article',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${l.quantite.toStringAsFixed(0)} x ${currencyFormatter.format(l.prixUnitaire)}${l.tauxRemise > 0 ? " (-${l.tauxRemise}%)" : ""}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        trailing: Text(
                          currencyFormatter.format(l.montantTtc),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total TTC', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      currencyFormatter.format(commande.montantTtc),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
                if (!commande.estPaye) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reste à encaisser', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.danger)),
                      Text(
                        currencyFormatter.format(commande.resteAPayer),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.danger),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user != null && !user.profil.canAccessVente) {
      return const AccessDeniedScreen(
        moduleName: 'Ventes & Facturation',
        profilsRequis: 'Caissier, Gérant, Administrateur',
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'VENTES & FACTURATION',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Nouveau Client',
            icon: const Icon(Icons.person_add_alt_1_outlined, size: 22),
            onPressed: _ouvrirNouveauClient,
          ),
          IconButton(
            tooltip: 'Nouvelle Vente',
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 22),
            onPressed: _ouvrirNouvelleVente,
          ),
          const SyncButton(),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CARTE NOIRE DU PATRON : CHIFFRE D'AFFAIRES & MARGE & CRÉANCES
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
                              const Expanded(
                                child: Text(
                                  'CHIFFRE D\'AFFAIRES VENTES',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_summary?.nombreVentes ?? 0} vente(s)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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
                              currencyFormatter.format(_summary?.totalVentesMois ?? 0),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Créances clients dues', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        currencyFormatter.format(_summary?.totalCreancesClients ?? 0),
                                        style: TextStyle(
                                          color: (_summary?.totalCreancesClients ?? 0) > 0 ? const Color(0xFFFCA5A5) : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Marge brute estimée', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '+${currencyFormatter.format(_summary?.totalMargeBrute ?? 0)}',
                                        style: const TextStyle(
                                          color: Color(0xFF86EFAC),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Bouton d'action directe Nouvelle Vente
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _ouvrirNouvelleVente,
                              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Colors.black),
                              label: const Text(
                                'NOUVELLE VENTE (CAISSE ENREGISTREUSE)',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // FILTRE ONGLETS (TOUTES LES VENTES vs CRÉANCES SEULEMENT)
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Toutes les ventes'),
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
                                'Créances clients',
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

                    // FILTRE PAR DATE OBLIGATOIRE
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

                    // LISTE DES COMMANDES DE VENTE
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
                            Icon(Icons.point_of_sale_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _onlyUnpaid ? 'Aucune créance client en cours !' : 'Aucune vente enregistrée',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Effectuez une vente pour décrémenter le stock et encaisser les fonds en caisse.',
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
                          return CommandeVenteCard(
                            commande: cmd,
                            onTap: () => _afficherDetailsCommande(cmd),
                            onEncaisser: () => _ouvrirEncaissementCreance(cmd),
                          );
                        },
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }
}
