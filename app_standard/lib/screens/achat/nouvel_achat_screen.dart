import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/article.dart';
import '../../models/caisse.dart';
import '../../models/fournisseur.dart';
import '../../models/journal_caisse.dart';
import '../../models/mode_paiement.dart';
import '../../services/achat_service.dart';
import '../../services/caisse_service.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import '../caisse/widgets/ouvrir_caisse_dialog.dart';
import 'widgets/nouveau_fournisseur_dialog.dart';

class NouvelAchatScreen extends StatefulWidget {
  const NouvelAchatScreen({super.key});

  @override
  State<NouvelAchatScreen> createState() => _NouvelAchatScreenState();
}

class _NouvelAchatScreenState extends State<NouvelAchatScreen> {
  final AchatService _achatService = AchatService();
  final StockService _stockService = StockService();
  final CaisseService _caisseService = CaisseService();

  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  List<Fournisseur> _fournisseurs = [];
  List<Article> _articles = [];
  List<Caisse> _caisses = [];
  List<ModePaiement> _modesPaiement = [];
  JournalCaisse? _journalOuvert;

  int? _selectedFournisseurId;
  int? _selectedArticleId;
  final TextEditingController _quantiteController = TextEditingController(text: '1');
  final TextEditingController _prixUnitaireController = TextEditingController();
  final TextEditingController _remarquesController = TextEditingController();

  final List<LigneAchatInput> _panier = [];
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
    _remarquesController.dispose();
    super.dispose();
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    try {
      final fournisseurs = await _achatService.getFournisseurs();
      final articles = await _stockService.getArticles();
      final caisses = await _caisseService.getCaisses();
      final modes = await _caisseService.getModesPaiement();
      final journal = await _caisseService.getJournalOuvert();

      if (mounted) {
        setState(() {
          _fournisseurs = fournisseurs;
          _articles = articles;
          _caisses = caisses;
          _modesPaiement = modes;
          _journalOuvert = journal;

          if (fournisseurs.isNotEmpty) {
            _selectedFournisseurId = fournisseurs.first.id;
          }
          if (articles.isNotEmpty) {
            _selectedArticleId = articles.first.id;
            _prixUnitaireController.text = articles.first.prixAchatEstime.toStringAsFixed(0);
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

    if (qte <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une quantité valide')),
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
        LigneAchatInput(
          idArticle: article.id,
          designation: article.designation,
          quantite: qte,
          prixUnitaire: prix,
        ),
      );
      _quantiteController.text = '1';
    });
  }

  double get _totalPanier {
    return _panier.fold(0.0, (sum, item) => sum + item.montantTotal);
  }

  void _creerFournisseur() {
    showDialog(
      context: context,
      builder: (context) => NouveauFournisseurDialog(
        onSupplierCreated: (newId) async {
          final updated = await _achatService.getFournisseurs();
          if (mounted) {
            setState(() {
              _fournisseurs = updated;
              _selectedFournisseurId = newId;
            });
          }
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

  Future<void> _validerAchat() async {
    if (_journalOuvert == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Achat impossible : Aucun journal de caisse n\'est ouvert. Veuillez d\'abord ouvrir la session de caisse.'),
        ),
      );
      return;
    }
    if (_selectedFournisseurId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un fournisseur')),
      );
      return;
    }
    if (_panier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter au moins un article à la commande')),
      );
      return;
    }
    if (_payeImmediatement && _selectedCaisseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner la caisse à débiter')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _achatService.enregistrerAchat(
        idFournisseur: _selectedFournisseurId!,
        articlesAchetes: _panier,
        payeImmediatement: _payeImmediatement,
        idCaisse: _selectedCaisseId,
        idModePaiement: _selectedModePaiementId,
        remarques: _remarquesController.text.trim().isNotEmpty ? _remarquesController.text.trim() : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.darkCard,
            content: Text(
              _payeImmediatement
                  ? 'Achat comptant validé : Stock réapprovisionné et caisse débitée de ${currencyFormatter.format(_totalPanier)}'
                  : 'Achat à crédit validé : Stock réapprovisionné et dette enregistrée',
            ),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'NOUVEL ACHAT FOURNISSEUR',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
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
                                  'Aucun achat ne peut être enregistré sans session de caisse ouverte.',
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

                  // 1. SÉLECTION DU FOURNISSEUR
                  _buildSectionTitle('1. FOURNISSEUR / GROSSISTE'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _selectedFournisseurId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Sélectionner le fournisseur *'),
                            items: _fournisseurs.map((f) {
                              return DropdownMenuItem<int>(
                                value: f.id,
                                child: Text(
                                  f.raisonSociale,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedFournisseurId = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.outlined(
                          tooltip: 'Créer un fournisseur',
                          icon: const Icon(Icons.add_rounded, color: Colors.black),
                          style: IconButton.styleFrom(
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(14),
                          ),
                          onPressed: _creerFournisseur,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. AJOUT D'ARTICLES AU PANIER
                  _buildSectionTitle('2. ARTICLES ACHETÉS (RÉAPPROVISIONNEMENT)'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_articles.isEmpty)
                          const Text(
                            'Aucun article dans le catalogue. Créez d\'abord un produit dans le module Stocks.',
                            style: TextStyle(color: AppTheme.danger, fontSize: 13),
                          )
                        else ...[
                          DropdownButtonFormField<int>(
                            initialValue: _selectedArticleId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Article à acheter'),
                            items: _articles.map((art) {
                              return DropdownMenuItem<int>(
                                value: art.id,
                                child: Text(
                                  '${art.designation} (${art.reference})',
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
                                  _prixUnitaireController.text = art.prixAchatEstime.toStringAsFixed(0);
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
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
                                child: TextFormField(
                                  controller: _prixUnitaireController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Prix unitaire achat *',
                                    suffixText: 'Ar',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _ajouterArticleAuPanier,
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: Colors.black),
                            label: const Text('Ajouter cet article à l\'achat', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. RÉCAPITULATIF DES ARTICLES DU PANIER
                  if (_panier.isNotEmpty) ...[
                    _buildSectionTitle('PANIER DE COMMANDE (${_panier.length} article(s))'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          ..._panier.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: idx < _panier.length - 1 ? Border(bottom: BorderSide(color: Colors.grey.shade100)) : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.designation,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${item.quantite.toStringAsFixed(0)} pcs x ${currencyFormatter.format(item.prixUnitaire)}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        currencyFormatter.format(item.montantTotal),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.danger, size: 20),
                                        onPressed: () => setState(() => _panier.removeAt(idx)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL À PAYER', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    currencyFormatter.format(_totalPanier),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 4. MODALITÉ DE RÈGLEMENT & IMPACT CAISSE
                  _buildSectionTitle('3. RÈGLEMENT & IMPACT CAISSE'),
                  const SizedBox(height: 8),
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
                        // Toggle Comptant vs Dette
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _payeImmediatement = true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: _payeImmediatement ? Colors.black : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Comptant (Débit Caisse)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _payeImmediatement ? Colors.white : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _payeImmediatement = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                    decoration: BoxDecoration(
                                      color: !_payeImmediatement ? AppTheme.danger : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'À Crédit (Dette Fournisseur)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: !_payeImmediatement ? Colors.white : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_payeImmediatement) ...[
                          // Choix Caisse
                          DropdownButtonFormField<int>(
                            initialValue: _selectedCaisseId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Compte ou Tiroir-Caisse à débiter *'),
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
                          const SizedBox(height: 12),
                          // Choix Mode Paiement
                          DropdownButtonFormField<int>(
                            initialValue: _selectedModePaiementId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Moyen de paiement'),
                            items: _modesPaiement.map((mp) {
                              return DropdownMenuItem<int>(
                                value: mp.id,
                                child: Text(
                                  mp.libelle,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedModePaiementId = val);
                            },
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ce montant sera enregistré dans le carnet de dettes fournisseurs. Votre caisse ne sera pas débitée maintenant.',
                                    style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSubmitting || _panier.isEmpty ? null : _validerAchat,
            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            label: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'VALIDER L\'ACHAT • ${currencyFormatter.format(_totalPanier)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: AppTheme.textPrimary,
      ),
    );
  }
}
