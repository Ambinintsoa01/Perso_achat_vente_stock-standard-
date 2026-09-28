import '../database/db_helper.dart';
import '../models/article.dart';
import '../models/categorie.dart';
import '../models/unite_mesure.dart';

class StockSummary {
  final int totalArticles;
  final double totalValeurAchat;
  final double totalValeurVente;
  final int articlesEnAlerte;
  final int articlesEnRupture;

  StockSummary({
    required this.totalArticles,
    required this.totalValeurAchat,
    required this.totalValeurVente,
    required this.articlesEnAlerte,
    required this.articlesEnRupture,
  });
}

class StockService {
  final DbHelper _dbHelper = DbHelper.instance;

  // Récupérer les catégories avec le nombre d'articles associés
  Future<List<Categorie>> getCategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        c.*,
        COUNT(a.id) as nombre_articles
      FROM categorie c
      LEFT JOIN article a ON c.id = a.id_categorie AND a.actif = 1
      WHERE c.actif = 1
      GROUP BY c.id
      ORDER BY c.nom ASC
    ''');
    return maps.map((m) => Categorie.fromMap(m)).toList();
  }

  // Ajouter une nouvelle catégorie
  Future<int> ajouterCategorie({
    required String code,
    required String nom,
    String? description,
    int? idParent,
  }) async {
    final db = await _dbHelper.database;
    return await db.insert('categorie', {
      'code': code.trim().toUpperCase(),
      'nom': nom.trim(),
      'description': description?.trim(),
      'id_parent': idParent,
      'actif': 1,
    });
  }

  // Récupérer les unités de mesure
  Future<List<UniteMesure>> getUnites() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unite_mesure',
      where: 'actif = 1',
      orderBy: 'nom ASC',
    );
    return maps.map((m) => UniteMesure.fromMap(m)).toList();
  }

  // Récupérer les articles avec leur stock actuel et filtres
  Future<List<Article>> getArticles({
    int? idCategorie,
    String? searchQuery,
    bool? onlyLowStock,
  }) async {
    final db = await _dbHelper.database;

    String whereClause = 'WHERE a.actif = 1';
    List<dynamic> args = [];

    if (idCategorie != null && idCategorie > 0) {
      whereClause += ' AND a.id_categorie = ?';
      args.add(idCategorie);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (a.designation LIKE ? OR a.reference LIKE ? OR a.code_barre LIKE ?)';
      final queryParam = '%${searchQuery.trim()}%';
      args.addAll([queryParam, queryParam, queryParam]);
    }

    final query = '''
      SELECT 
        a.*,
        c.nom as categorie_nom,
        u.code as unite_code,
        COALESCE(SUM(sd.quantite_reelle), 0.0) as quantite_reelle
      FROM article a
      LEFT JOIN categorie c ON a.id_categorie = c.id
      LEFT JOIN unite_mesure u ON a.id_unite = u.id
      LEFT JOIN stock_depot sd ON a.id = sd.id_article
      $whereClause
      GROUP BY a.id
      ORDER BY a.designation ASC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);
    final articles = maps.map((m) => Article.fromMap(m)).toList();

    if (onlyLowStock == true) {
      return articles.where((a) => a.isAlerteStock).toList();
    }

    return articles;
  }

  // Création d'un nouvel article avec possibilité de stock de départ
  Future<int> ajouterArticle({
    required String reference,
    String? codeBarre,
    required String designation,
    String? description,
    int? idCategorie,
    int? idUnite,
    double prixAchat = 0.0,
    double prixVente = 0.0,
    double tauxTva = 20.0,
    double seuilAlerte = 5.0,
    double stockInitial = 0.0,
    int idDepot = 1,
    int? idUtilisateur,
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. Insertion de l'article
      final idArticle = await txn.insert('article', {
        'reference': reference.trim().toUpperCase(),
        'code_barre': codeBarre?.trim().isNotEmpty == true ? codeBarre!.trim() : null,
        'designation': designation.trim(),
        'description': description?.trim(),
        'id_categorie': idCategorie,
        'id_unite': idUnite ?? 1,
        'prix_achat_estime': prixAchat,
        'cout_moyen_unitaire': prixAchat,
        'prix_vente_standard': prixVente,
        'taux_tva': tauxTva,
        'seuil_alerte_stock': seuilAlerte,
        'suivi_stock': 1,
        'actif': 1,
      });

      // 2. Initialisation du stock dépôt
      await txn.insert('stock_depot', {
        'id_depot': idDepot,
        'id_article': idArticle,
        'quantite_reelle': stockInitial,
        'quantite_reservee': 0.0,
        'quantite_en_commande': 0.0,
      });

      // 3. Si stock initial > 0, enregistrer le mouvement initial de stock
      if (stockInitial > 0) {
        await txn.insert('mouvement_stock', {
          'id_depot': idDepot,
          'id_article': idArticle,
          'id_type_mouvement': 3, // AJUSTEMENT_POSITIF (id 3 dans type_mouvement_stock)
          'id_utilisateur': idUtilisateur ?? 1,
          'quantite': stockInitial,
          'prix_unitaire': prixAchat,
          'stock_avant': 0.0,
          'stock_apres': stockInitial,
          'reference_document': 'INIT-${reference.trim().toUpperCase()}',
          'remarque': 'Stock initial de départ',
        });
      }

      return idArticle;
    });
  }

  // Ajustement manuel de stock (Entrée / Sortie / Inventaire)
  Future<void> ajusterStock({
    required int idArticle,
    required int idDepot,
    required double quantite,
    required int idTypeMouvement, // 1: Entrée Achat, 2: Sortie Vente, 3: Positif, 4: Négatif
    int? idUtilisateur,
    String? referenceDocument,
    String? remarque,
  }) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Lire le type de mouvement pour connaître le sens (+1 ou -1)
      final typeRows = await txn.query('type_mouvement_stock', where: 'id = ?', whereArgs: [idTypeMouvement]);
      if (typeRows.isEmpty) throw Exception('Type de mouvement introuvable');
      final sens = typeRows.first['sens'] as int;

      // 2. Lire le stock actuel
      final stockRows = await txn.query(
        'stock_depot',
        where: 'id_depot = ? AND id_article = ?',
        whereArgs: [idDepot, idArticle],
      );

      double stockAvant = 0.0;
      if (stockRows.isNotEmpty) {
        stockAvant = (stockRows.first['quantite_reelle'] as num).toDouble();
      }

      final stockApres = stockAvant + (sens * quantite);
      if (stockApres < 0) {
        throw Exception('Impossible d\'effectuer l\'opération : stock insuffisant ($stockAvant disponible)');
      }

      // 3. Mettre à jour le stock dépôt
      if (stockRows.isNotEmpty) {
        await txn.update(
          'stock_depot',
          {'quantite_reelle': stockApres, 'derniere_mise_a_jour': DateTime.now().toIso8601String()},
          where: 'id_depot = ? AND id_article = ?',
          whereArgs: [idDepot, idArticle],
        );
      } else {
        await txn.insert('stock_depot', {
          'id_depot': idDepot,
          'id_article': idArticle,
          'quantite_reelle': stockApres,
          'quantite_reservee': 0.0,
          'quantite_en_commande': 0.0,
        });
      }

      // 4. Insérer le mouvement de stock
      await txn.insert('mouvement_stock', {
        'id_depot': idDepot,
        'id_article': idArticle,
        'id_type_mouvement': idTypeMouvement,
        'id_utilisateur': idUtilisateur ?? 1,
        'quantite': quantite,
        'stock_avant': stockAvant,
        'stock_apres': stockApres,
        'reference_document': referenceDocument,
        'remarque': remarque,
      });
    });
  }

  // Calcul du résumé global du stock (Valeur totale, alertes, etc.)
  Future<StockSummary> getStockSummary() async {
    final articles = await getArticles();

    double valeurAchat = 0.0;
    double valeurVente = 0.0;
    int alerteCount = 0;
    int ruptureCount = 0;

    for (var a in articles) {
      valeurAchat += a.valeurStockAchat;
      valeurVente += a.valeurStockVente;
      if (a.isRupture) {
        ruptureCount++;
      } else if (a.isAlerteStock) {
        alerteCount++;
      }
    }

    return StockSummary(
      totalArticles: articles.length,
      totalValeurAchat: valeurAchat,
      totalValeurVente: valeurVente,
      articlesEnAlerte: alerteCount,
      articlesEnRupture: ruptureCount,
    );
  }
}
