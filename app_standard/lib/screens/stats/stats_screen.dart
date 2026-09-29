import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/article.dart';
import '../../models/categorie.dart';
import '../../models/stats_data.dart';
import '../../services/auth_service.dart';
import '../../services/stats_service.dart';
import '../../services/stock_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/access_denied_screen.dart';
import '../../widgets/date_filter_bar.dart';
import '../../widgets/user_avatar_button.dart';
import 'widgets/depenses_visualisation_chart.dart';
import 'widgets/patron_summary_cards.dart';
import 'widgets/stats_kpi_card.dart';
import 'widgets/vente_evolution_chart.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final StatsService _statsService = StatsService();
  final StockService _stockService = StockService();

  final currencyFormatter = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'Ar',
    decimalDigits: 0,
  );

  // Filtre global de date (par défaut: "Ce mois" en cours)
  late DateTime? _dateDebut;
  late DateTime? _dateFin;

  // Filtres spécifiques au graphe des ventes
  int? _selectedCategorieId;
  int? _selectedArticleId;

  // Données chargées
  StatsKpiSummary? _kpiSummary;
  DashboardPatronSummary? _patronSummary;
  List<VenteEvolutionPoint> _evolutionVentes = [];
  List<DepenseEvolutionPoint> _evolutionDepenses = [];
  List<DepenseRepartitionItem> _repartitionDepenses = [];
  List<Categorie> _categories = [];
  List<Article> _articles = [];

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateDebut = DateTime(now.year, now.month, 1);
    _dateFin = DateTime(now.year, now.month + 1, 0);

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final kpi = await _statsService.getKpiSummary(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      final patron = await _statsService.getDashboardPatron();

      final ventes = await _statsService.getEvolutionVentes(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        idCategorie: _selectedCategorieId,
        idArticle: _selectedArticleId,
      );

      final depenses = await _statsService.getEvolutionDepenses(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      final repartition = await _statsService.getRepartitionDepenses(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      final categories = await _stockService.getCategories();
      final articles = await _stockService.getArticles();

      if (mounted) {
        setState(() {
          _kpiSummary = kpi;
          _patronSummary = patron;
          _evolutionVentes = ventes;
          _evolutionDepenses = depenses;
          _repartitionDepenses = repartition;
          _categories = categories;
          _articles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _reloadVentesOnly() async {
    try {
      final ventes = await _statsService.getEvolutionVentes(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        idCategorie: _selectedCategorieId,
        idArticle: _selectedArticleId,
      );
      if (mounted) {
        setState(() => _evolutionVentes = ventes);
      }
    } catch (e) {
      // Ignorer
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user != null && !user.profil.canAccessStats) {
      return const AccessDeniedScreen(
        moduleName: 'Statistiques & Analyses',
        profilsRequis: 'Administrateur, Gérant',
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'STATISTIQUES & ANALYSES',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadData,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.danger),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadData,
                              child: const Text('Réessayer', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 0. Tableau de bord patron (4 cartes clés) selon access_controle.md
                    if (_patronSummary != null && (user == null || user.profil.canVoirTableauBordPatron)) ...[
                      PatronSummaryCards(
                        data: _patronSummary!,
                        currencyFormatter: currencyFormatter,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 1. Barre de filtre de date obligatoire (AGENTS.md)
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

                    // 2. Synthèse Globale (Valeur Stock, Entrées, Sorties)
                    StatsKpiCard(
                      summary: _kpiSummary ??
                          const StatsKpiSummary(
                            valeurStockActuel: 0.0,
                            valeurTotaleEntrees: 0.0,
                            valeurTotaleSorties: 0.0,
                            totalEncaissements: 0.0,
                            totalDecaissements: 0.0,
                            totalAchats: 0.0,
                            totalDepensesDiverses: 0.0,
                            totalVentes: 0.0,
                            totalArticles: 0,
                            totalQuantiteEnStock: 0.0,
                          ),
                      currencyFormatter: currencyFormatter,
                    ),
                    const SizedBox(height: 16),

                    // 3. Graphe d'évolution de vente filtrable par produit / catégorie
                    VenteEvolutionChart(
                      data: _evolutionVentes,
                      categories: _categories,
                      articles: _articles,
                      selectedCategorieId: _selectedCategorieId,
                      selectedArticleId: _selectedArticleId,
                      currencyFormatter: currencyFormatter,
                      onCategorieChanged: (catId) {
                        setState(() {
                          _selectedCategorieId = catId;
                          // Si l'article sélectionné n'appartient pas à la nouvelle catégorie, le réinitialiser
                          if (catId != null && _selectedArticleId != null) {
                            final article = _articles.firstWhere(
                              (a) => a.id == _selectedArticleId,
                              orElse: () => _articles.first,
                            );
                            if (article.idCategorie != catId) {
                              _selectedArticleId = null;
                            }
                          }
                        });
                        _reloadVentesOnly();
                      },
                      onArticleChanged: (artId) {
                        setState(() => _selectedArticleId = artId);
                        _reloadVentesOnly();
                      },
                    ),
                    const SizedBox(height: 16),

                    // 4. Graphe de visualisation des dépenses (Achat + Décaissement divers)
                    DepensesVisualisationChart(
                      evolutionData: _evolutionDepenses,
                      repartitionData: _repartitionDepenses,
                      currencyFormatter: currencyFormatter,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
