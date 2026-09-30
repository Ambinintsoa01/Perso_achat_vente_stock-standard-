import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/article.dart';
import '../../models/caisse.dart';
import '../../models/client.dart';
import '../../models/journal_caisse.dart';
import '../../models/mode_paiement.dart';
import '../../services/auth_service.dart';
import '../../services/caisse_service.dart';
import '../../services/stock_service.dart';
import '../../services/vente_service.dart';
import '../../theme/app_theme.dart';
import '../caisse/widgets/ouvrir_caisse_dialog.dart';
import 'widgets/nouveau_client_dialog.dart';
import 'widgets/thermal_printer_config_dialog.dart';
import 'widgets/vente_succes_dialog.dart';

class NouvelleVenteScreen extends StatefulWidget {
  const NouvelleVenteScreen({super.key});

  @override
  State<NouvelleVenteScreen> createState() => _NouvelleVenteScreenState();
}

class _NouvelleVenteScreenState extends State<NouvelleVenteScreen> {
  final VenteService _venteService = VenteService();
  final StockService _stockService = StockService();
  final CaisseService _caisseService = CaisseService();

  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  List<Client> _clients = [];
  List<Article> _articles = [];
  List<Caisse> _caisses = [];
  List<ModePaiement> _modesPaiement = [];
  JournalCaisse? _journalOuvert;

  int? _selectedClientId;
  int? _selectedArticleId;
  final TextEditingController _quantiteController = TextEditingController(text: '1');
  final TextEditingController _prixUnitaireController = TextEditingController();
  final TextEditingController _remiseController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  final List<LigneVenteInput> _panier = [];
  bool _payeImmediatement = true;
  int? _selectedCaisseId;
  int? _selectedModePaiementId;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _prixUnitaireController.dispose();
    _remiseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final clients = await _venteService.getClients();
      final articles = await _stockService.getArticles();
      final caisses = await _caisseService.getCaisses();
      final modes = await _caisseService.getModesPaiement();
      final journal = await _caisseService.getJournalOuvert();

      if (mounted) {
        setState(() {
          _clients = clients;
          _articles = articles;
          _caisses = caisses;
          _modesPaiement = modes;
          _journalOuvert = journal;

          if (clients.isNotEmpty) {
            _selectedClientId = clients.first.id;
          }
          if (articles.isNotEmpty) {
            _selectedArticleId = articles.first.id;
            _prixUnitaireController.text = articles.first.prixVenteStandard.toStringAsFixed(0);
          }
          if (caisses.isNotEmpty) {
            _selectedCaisseId = caisses.first.id;
          }
          if (modes.isNotEmpty) {
            _selectedModePaiementId = modes.first.id;
          }
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

  void _ajouterArticleAuPanier() {
    if (_selectedArticleId == null) return;
    final article = _articles.firstWhere((a) => a.id == _selectedArticleId);
    final qte = double.tryParse(_quantiteController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    final prix = double.tryParse(_prixUnitaireController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    final remise = double.tryParse(_remiseController.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;

    if (qte <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une quantité supérieure à 0')),
      );
      return;
    }

    // Vérifier la quantité déjà présente dans le panier
    double qteDejaDansPanier = 0;
    for (var l in _panier) {
      if (l.idArticle == article.id) {
        qteDejaDansPanier += l.quantite;
      }
    }

    if ((qte + qteDejaDansPanier) > article.quantiteStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text(
            'Stock insuffisant pour "${article.designation}". En stock: ${article.quantiteStock.toStringAsFixed(0)}, Déjà au panier: ${qteDejaDansPanier.toStringAsFixed(0)}',
          ),
        ),
      );
      return;
    }

    if (prix < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le prix unitaire doit être positif')),
      );
      return;
    }

    setState(() {
      _panier.add(
        LigneVenteInput(
          idArticle: article.id,
          designation: article.designation,
          quantite: qte,
          prixUnitaire: prix,
          tauxRemise: remise,
        ),
      );
      _quantiteController.text = '1';
      _remiseController.text = '0';
    });
  }

  void _supprimerLigne(int index) {
    setState(() => _panier.removeAt(index));
  }

  void _ouvrirNouveauClient() {
    showDialog(
      context: context,
      builder: (context) => NouveauClientDialog(
        onClientCreated: (newId) async {
          final clients = await _venteService.getClients();
          setState(() {
            _clients = clients;
            _selectedClientId = newId;
          });
        },
      ),
    );
  }

  void _ouvrirCaisseSession() {
    showDialog(
      context: context,
      builder: (context) => OuvrirCaisseDialog(
        caisses: _caisses,
        onSuccess: () async {
          final j = await _caisseService.getJournalOuvert();
          if (mounted) setState(() => _journalOuvert = j);
        },
      ),
    );
  }

  Future<void> _validerVente() async {
    if (_journalOuvert == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Vente impossible : Aucun journal de caisse n\'est ouvert. Veuillez d\'abord ouvrir la session de caisse.'),
        ),
      );
      return;
    }
    if (_panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le panier est vide. Veuillez ajouter au moins un produit.')),
      );
      return;
    }
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un client')),
      );
      return;
    }
    if (_payeImmediatement && _selectedCaisseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un compte ou caisse pour l\'encaissement')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final idCommande = await _venteService.enregistrerVente(
        idClient: _selectedClientId!,
        articlesVendus: _panier,
        payeImmediatement: _payeImmediatement,
        idCaisse: _selectedCaisseId,
        idModePaiement: _selectedModePaiementId,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      final commande = await _venteService.getCommandeById(idCommande);
      final lignes = await _venteService.getLignesCommande(idCommande);
      Client? client;
      if (_selectedClientId != null) {
        client = await _venteService.getClientById(_selectedClientId!);
      }
      String? modeNom;
      if (_selectedModePaiementId != null) {
        final m = _modesPaiement.where((m) => m.id == _selectedModePaiementId).firstOrNull;
        modeNom = m?.libelle;
      }
      final currentUser = AuthService.instance.currentUser;
      final caissierNom = currentUser != null ? '${currentUser.prenom ?? ''} ${currentUser.nom}'.trim() : null;

      if (mounted) {
        if (commande != null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => VenteSuccesDialog(
              commande: commande,
              lignes: lignes,
              client: client,
              caissierNom: caissierNom,
              modePaiementNom: modeNom,
              onNouvelleVente: () {
                Navigator.pop(dialogCtx);
                _reinitialiserVente();
              },
              onFermer: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context, true);
              },
            ),
          );
        } else {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.darkCard,
              content: Text(
                _payeImmediatement
                    ? 'Vente enregistrée et encaissée avec succès !'
                    : 'Vente enregistrée à crédit (créance client) !',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _reinitialiserVente() {
    setState(() {
      _panier.clear();
      _quantiteController.text = '1';
      _remiseController.text = '0';
      _notesController.clear();
      if (_articles.isNotEmpty) {
        _prixUnitaireController.text = _articles.first.prixVenteStandard.toStringAsFixed(0);
      }
    });
    _loadDependencies();
  }

  @override
  Widget build(BuildContext context) {
    double totalPanier = 0;
    for (var l in _panier) {
      totalPanier += l.montantTotal;
    }

    Article? articleActuel;
    if (_selectedArticleId != null && _articles.isNotEmpty) {
      try {
        articleActuel = _articles.firstWhere((a) => a.id == _selectedArticleId);
      } catch (_) {
        articleActuel = null;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'NOUVELLE VENTE',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Paramètres Imprimante Thermique',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const ThermalPrinterConfigDialog(),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_journalOuvert == null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.danger.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded, color: AppTheme.danger, size: 22),
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
                                    color: AppTheme.danger,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Aucune vente ne peut être enregistrée sans session de caisse ouverte.',
                                  style: TextStyle(fontSize: 11, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _ouvrirCaisseSession,
                            icon: const Icon(Icons.wb_sunny_outlined, size: 14, color: Colors.white),
                            label: const Text(
                              'OUVRIR',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.danger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 1. CLIENT SECTION
                  _buildSectionHeader('1. CLIENT & FACTURATION'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedClientId,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Client sélectionné *'),
                                items: _clients.map((cli) {
                                  return DropdownMenuItem<int>(
                                    value: cli.id,
                                    child: Text(
                                      cli.nomComplet,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedClientId = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Ajouter un client',
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                              ),
                              onPressed: _ouvrirNouveauClient,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. AJOUTER DES ARTICLES AU PANIER
                  _buildSectionHeader('2. CHOIX DES ARTICLES'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dropdown Article
                        DropdownButtonFormField<int>(
                          initialValue: _selectedArticleId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Sélectionner l\'article *'),
                          items: _articles.map((art) {
                            return DropdownMenuItem<int>(
                              value: art.id,
                              child: Text(
                                '${art.designation} (Stock: ${art.quantiteStock.toStringAsFixed(0)})',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedArticleId = val;
                                final art = _articles.firstWhere((a) => a.id == val);
                                _prixUnitaireController.text = art.prixVenteStandard.toStringAsFixed(0);
                              });
                            }
                          },
                        ),

                        // Indicateur de stock disponible
                        if (articleActuel != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                articleActuel.quantiteStock > 0 ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                                size: 16,
                                color: articleActuel.quantiteStock > 0 ? AppTheme.success : AppTheme.danger,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Stock disponible : ${articleActuel.quantiteStock.toStringAsFixed(0)} unités (CUMP: ${currencyFormatter.format(articleActuel.coutMoyenUnitaire)})',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: articleActuel.quantiteStock > 0 ? AppTheme.success : AppTheme.danger,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Quantité et Prix unitaire
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: TextFormField(
                                controller: _quantiteController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Quantité *',
                                  hintText: '1',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _prixUnitaireController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Prix unitaire (Ar) *',
                                  suffixText: 'Ar',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Remise optionnelle
                        TextFormField(
                          controller: _remiseController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Remise (%)',
                            suffixText: '%',
                            hintText: '0',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bouton Ajouter
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _ajouterArticleAuPanier,
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Colors.black),
                            label: const Text(
                              'AJOUTER AU PANIER',
                              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. PANIER / LISTE DES ARTICLES VENDUS
                  _buildSectionHeader('3. ARTICLES DANS LE PANIER (${_panier.length})'),
                  const SizedBox(height: 10),
                  if (_panier.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            'Aucun article dans le panier',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _panier.length,
                        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        itemBuilder: (context, index) {
                          final item = _panier[index];
                          return ListTile(
                            title: Text(
                              item.designation,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            subtitle: Text(
                              '${item.quantite.toStringAsFixed(0)} x ${currencyFormatter.format(item.prixUnitaire)}${item.tauxRemise > 0 ? " (-${item.tauxRemise}%)" : ""}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currencyFormatter.format(item.montantTotal),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 20),
                                  onPressed: () => _supprimerLigne(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // 4. MODALITÉS DE PAIEMENT
                  _buildSectionHeader('4. RÈGLEMENT & TRÉSORERIE'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Radio boutons Comptant / Crédit
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Comptant (Payé immédiatement)'),
                                selected: _payeImmediatement,
                                selectedColor: Colors.black,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _payeImmediatement ? Colors.white : AppTheme.textPrimary,
                                ),
                                onSelected: (val) => setState(() => _payeImmediatement = true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('À crédit (Différé)'),
                                selected: !_payeImmediatement,
                                selectedColor: AppTheme.danger,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: !_payeImmediatement ? Colors.white : AppTheme.textPrimary,
                                ),
                                onSelected: (val) => setState(() => _payeImmediatement = false),
                              ),
                            ),
                          ],
                        ),

                        if (_payeImmediatement) ...[
                          const SizedBox(height: 16),
                          // Caisse encaissante
                          DropdownButtonFormField<int>(
                            initialValue: _selectedCaisseId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Compte / Caisse qui reçoit le paiement *'),
                            items: _caisses.map((c) {
                              return DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(
                                  '${c.nom} (${currencyFormatter.format(c.soldeActuel)})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCaisseId = val);
                            },
                          ),
                          const SizedBox(height: 14),

                          // Mode de paiement
                          DropdownButtonFormField<int>(
                            initialValue: _selectedModePaiementId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Moyen de règlement *'),
                            items: _modesPaiement.map((mp) {
                              return DropdownMenuItem<int>(
                                value: mp.id,
                                child: Text(mp.libelle, overflow: TextOverflow.ellipsis, maxLines: 1),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedModePaiementId = val);
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppTheme.danger, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'La vente créera une créance au nom du client. Le stock sera immédiatement déduit.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes / Remarques (Optionnel)',
                            hintText: 'ex: Livraison offerte, client fidèle',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 5. CARTE TOTAUX ET VALIDATION
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL À PAYER',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currencyFormatter.format(totalPanier),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _validerVente,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Text(
                                    'VALIDER LA VENTE',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
