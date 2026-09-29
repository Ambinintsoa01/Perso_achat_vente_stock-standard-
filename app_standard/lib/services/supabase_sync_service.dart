import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../database/db_helper.dart';

import 'auth_service.dart';

/// Direction de la synchronisation
enum SyncDirection {
  push,          // Envoi local (SQLite) -> Supabase (Tous, y compris Caissier)
  pull,          // Téléchargement Supabase -> local (SQLite) (Interdit au Caissier)
  bidirectional, // Envoi puis Téléchargement (Interdit au Caissier)
}

class SyncProgress {
  final String tableName;
  final int step;
  final int totalSteps;
  final double percentage;
  final String message;
  final SyncDirection direction;

  const SyncProgress({
    required this.tableName,
    required this.step,
    required this.totalSteps,
    required this.percentage,
    required this.message,
    this.direction = SyncDirection.push,
  });
}

class SyncResult {
  final bool isSuccess;
  final int totalRowsSynced;
  final int totalRowsPushed;
  final int totalRowsPulled;
  final SyncDirection direction;
  final Map<String, int> rowsPerTable;
  final Map<String, String> errorsPerTable;
  final DateTime startedAt;
  final DateTime completedAt;
  final String? globalError;

  SyncResult({
    required this.isSuccess,
    required this.totalRowsSynced,
    this.totalRowsPushed = 0,
    this.totalRowsPulled = 0,
    this.direction = SyncDirection.push,
    required this.rowsPerTable,
    required this.errorsPerTable,
    required this.startedAt,
    required this.completedAt,
    this.globalError,
  });

  Duration get duration => completedAt.difference(startedAt);
}

class ConnectionTestResult {
  final bool isConnected;
  final bool tablesExist;
  final String message;

  const ConnectionTestResult({
    required this.isConnected,
    required this.tablesExist,
    required this.message,
  });

  bool get isSuccess => isConnected;
}

class SupabaseSyncService extends ChangeNotifier {
  static final SupabaseSyncService instance = SupabaseSyncService._();

  SupabaseSyncService._() {
    _loadStoredPreferences();
  }

  static const String _prefUrlKey = 'supabase_sync_url';
  static const String _prefAnonKey = 'supabase_sync_anon_key';
  static const String _prefLastSyncDateKey = 'supabase_sync_last_date';
  static const String _prefLastSyncSuccessKey = 'supabase_sync_last_success';
  static const String _prefLastSyncRowCountKey = 'supabase_sync_last_row_count';

  SupabaseClient? _client;
  bool _isSyncing = false;
  SyncProgress? _currentProgress;
  SyncResult? _lastResult;

  DateTime? _lastSyncDate;
  bool? _lastSyncSuccess;
  int _lastSyncRowCount = 0;
  String? _savedUrl;
  String? _savedAnonKey;

  bool get isSyncing => _isSyncing;
  SyncProgress? get currentProgress => _currentProgress;
  SyncResult? get lastResult => _lastResult;
  DateTime? get lastSyncDate => _lastSyncDate;
  bool? get lastSyncSuccess => _lastSyncSuccess;
  int get lastSyncRowCount => _lastSyncRowCount;
  String? get savedUrl => _savedUrl;
  String? get savedAnonKey => _savedAnonKey;

  /// Ordre hiérarchique strict des tables pour respecter les clés étrangères
  static const List<String> orderedTables = [
    // 1. Tables de référence indépendantes
    'profil',
    'statut',
    'mode_paiement',
    'type_caisse',
    'type_mouvement_stock',
    'type_mouvement_caisse',
    'type_client',
    'devise',
    'unite_mesure',
    'depot',

    // 2. Entités principales & Arborescences
    'categorie',
    'utilisateur',
    'fournisseur',
    'client',
    'caisse',
    'article',

    // 3. Situation des stocks
    'stock_depot',

    // 4. Session journalière de caisse
    'journal_caisse',
    'journal_caisse_ligne',

    // 5. Opérations, Mouvements & Facturations
    'mouvement_caisse',
    'transfert_caisse',
    'commande_achat',
    'commande_achat_ligne',
    'facture_fournisseur',
    'paiement_achat',
    'commande_vente',
    'commande_vente_ligne',
    'facture_client',
    'paiement_vente',
    'mouvement_stock',
  ];

  /// Colonnes de type BOOLEAN dans PostgreSQL (qui sont INTEGER dans SQLite)
  static const Map<String, Set<String>> booleanColumns = {
    'profil': {'actif'},
    'utilisateur': {'actif'},
    'mode_paiement': {'actif'},
    'type_mouvement_stock': {'actif'},
    'type_mouvement_caisse': {'actif'},
    'devise': {'actif'},
    'categorie': {'actif'},
    'unite_mesure': {'actif'},
    'depot': {'actif'},
    'article': {'actif', 'suivi_stock'},
    'fournisseur': {'actif'},
    'client': {'actif'},
    'caisse': {'actif'},
  };

  @visibleForTesting
  void setClientForTesting(SupabaseClient? client) {
    _client = client;
  }

  Future<void> _loadStoredPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedUrl = prefs.getString(_prefUrlKey) ?? SupabaseConfig.defaultUrl;
      _savedAnonKey = prefs.getString(_prefAnonKey) ?? SupabaseConfig.defaultAnonKey;

      final lastDateIso = prefs.getString(_prefLastSyncDateKey);
      if (lastDateIso != null) {
        _lastSyncDate = DateTime.tryParse(lastDateIso);
      }
      _lastSyncSuccess = prefs.getBool(_prefLastSyncSuccessKey);
      _lastSyncRowCount = prefs.getInt(_prefLastSyncRowCountKey) ?? 0;
      notifyListeners();
    } catch (e) {
      if (!e.toString().contains('MissingPluginException')) {
        debugPrint('SupabaseSyncService: Erreur lors du chargement des préférences: $e');
      }
    }
  }

  Future<bool> isConfigured() async {
    final url = await getUrl();
    final anonKey = await getAnonKey();
    return (url != null && url.trim().isNotEmpty) &&
        (anonKey != null && anonKey.trim().isNotEmpty);
  }

  Future<String?> getUrl() async {
    if (_savedUrl != null) return _savedUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedUrl = prefs.getString(_prefUrlKey) ?? SupabaseConfig.defaultUrl;
    } catch (_) {
      _savedUrl = SupabaseConfig.defaultUrl;
    }
    return _savedUrl;
  }

  Future<String?> getAnonKey() async {
    if (_savedAnonKey != null) return _savedAnonKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedAnonKey = prefs.getString(_prefAnonKey) ?? SupabaseConfig.defaultAnonKey;
    } catch (_) {
      _savedAnonKey = SupabaseConfig.defaultAnonKey;
    }
    return _savedAnonKey;
  }

  Future<void> saveConfig({
    required String url,
    required String anonKey,
  }) async {
    final cleanUrl = url.trim();
    final cleanAnonKey = anonKey.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUrlKey, cleanUrl);
    await prefs.setString(_prefAnonKey, cleanAnonKey);

    _savedUrl = cleanUrl;
    _savedAnonKey = cleanAnonKey;

    if (cleanUrl.isNotEmpty && cleanAnonKey.isNotEmpty) {
      _client = SupabaseClient(cleanUrl, cleanAnonKey);
    } else {
      _client = null;
    }

    notifyListeners();
  }

  Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUrlKey, '');
    await prefs.setString(_prefAnonKey, '');
    _savedUrl = '';
    _savedAnonKey = '';
    _client = null;
    notifyListeners();
  }

  Future<SupabaseClient> getOrInitClient() async {
    if (_client != null) return _client!;

    final url = await getUrl();
    final key = await getAnonKey();

    if (url == null || url.isEmpty || key == null || key.isEmpty) {
      throw Exception('Supabase non configuré : URL et clé Anon obligatoires.');
    }

    _client = SupabaseClient(url, key);
    return _client!;
  }

  /// Test de connectivité à Supabase
  Future<ConnectionTestResult> testConnection({String? customUrl, String? customKey}) async {
    try {
      final client = (customUrl != null && customKey != null)
          ? SupabaseClient(customUrl.trim(), customKey.trim())
          : await getOrInitClient();

      try {
        await client.from('statut').select('id').limit(1);
        return const ConnectionTestResult(
          isConnected: true,
          tablesExist: true,
          message: 'Connexion réussie ! Tables Supabase prêtes.',
        );
      } on PostgrestException catch (pe) {
        if (pe.code == 'PGRST205' ||
            pe.code == '42P01' ||
            pe.message.contains('does not exist') ||
            pe.message.contains('schema cache')) {
          return const ConnectionTestResult(
            isConnected: true,
            tablesExist: false,
            message: 'Connecté au projet Supabase !\nAttention : les tables ne sont pas encore créées dans Supabase. Veuillez exécuter le script SQL/tables.sql dans le menu SQL Editor.',
          );
        }
        return ConnectionTestResult(
          isConnected: false,
          tablesExist: false,
          message: 'Erreur Supabase : ${pe.message}',
        );
      }
    } catch (e) {
      debugPrint('SupabaseSyncService.testConnection: Erreur: $e');
      return ConnectionTestResult(
        isConnected: false,
        tablesExist: false,
        message: 'Échec de connexion : ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  /// Prépare une ligne SQLite pour PostgreSQL / Supabase
  Map<String, dynamic> sanitizeRow(String table, Map<String, dynamic> raw) {
    final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
    final boolCols = booleanColumns[table];
    if (boolCols != null) {
      for (final col in boolCols) {
        if (row.containsKey(col)) {
          final val = row[col];
          if (val != null) {
            row[col] = (val == 1 || val == true || val == '1');
          }
        }
      }
    }
    return row;
  }

  /// Prépare une ligne Supabase / PostgreSQL pour insertion dans SQLite local
  Map<String, dynamic> sanitizeRowForSqlite(String table, Map<String, dynamic> raw) {
    final Map<String, dynamic> row = Map<String, dynamic>.from(raw);
    row.forEach((key, value) {
      if (value is bool) {
        row[key] = value ? 1 : 0;
      }
    });
    return row;
  }

  /// Requête SQL pour charger les lignes d'une table avec l'ordre adéquat
  String getTableSelectQuery(String table) {
    if (table == 'categorie') {
      return 'SELECT * FROM categorie ORDER BY CASE WHEN id_parent IS NULL THEN 0 ELSE 1 END, id ASC';
    }
    return 'SELECT * FROM $table ORDER BY id ASC';
  }

  /// Exécution interne de l'envoi SQLite -> Supabase
  Future<SyncResult> _pushInternal({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final startedAt = DateTime.now();
    final Map<String, int> rowsPerTable = {};
    final Map<String, String> errorsPerTable = {};
    int totalRows = 0;
    String? globalError;

    try {
      final client = await getOrInitClient();
      final Database db = await DbHelper.instance.database;

      final tablesQuery = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );
      final existingTables = tablesQuery.map((r) => r['name'] as String).toSet();

      final List<String> tablesToSync = orderedTables
          .where((t) => existingTables.contains(t))
          .toList();

      final totalSteps = tablesToSync.length;

      for (int step = 0; step < totalSteps; step++) {
        final table = tablesToSync[step];
        final progressPct = (step + 1) / totalSteps;

        final progress = SyncProgress(
          tableName: table,
          step: step + 1,
          totalSteps: totalSteps,
          percentage: progressPct,
          direction: SyncDirection.push,
          message: 'Envoi de $table vers le Cloud (${step + 1}/$totalSteps)...',
        );

        _currentProgress = progress;
        onProgress?.call(progress);
        notifyListeners();

        try {
          final rows = await db.rawQuery(getTableSelectQuery(table));
          if (rows.isEmpty) {
            rowsPerTable[table] = 0;
            continue;
          }

          final sanitized = rows.map((r) => sanitizeRow(table, r)).toList();

          const int batchSize = 100;
          for (var i = 0; i < sanitized.length; i += batchSize) {
            final chunk = sanitized.sublist(
              i,
              min(i + batchSize, sanitized.length),
            );
            await client.from(table).upsert(chunk, onConflict: 'id');
          }

          rowsPerTable[table] = sanitized.length;
          totalRows += sanitized.length;
        } catch (e) {
          debugPrint('Erreur push table $table: $e');
          errorsPerTable[table] = e.toString();
        }
      }
    } catch (e) {
      debugPrint('Erreur globale push: $e');
      globalError = e.toString();
    }

    final completedAt = DateTime.now();
    final isSuccess = (globalError == null && errorsPerTable.isEmpty);

    return SyncResult(
      isSuccess: isSuccess,
      totalRowsSynced: totalRows,
      totalRowsPushed: totalRows,
      direction: SyncDirection.push,
      rowsPerTable: rowsPerTable,
      errorsPerTable: errorsPerTable,
      startedAt: startedAt,
      completedAt: completedAt,
      globalError: globalError,
    );
  }

  /// Exécution interne du téléchargement Supabase -> SQLite
  Future<SyncResult> _pullInternal({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    final startedAt = DateTime.now();
    final Map<String, int> rowsPerTable = {};
    final Map<String, String> errorsPerTable = {};
    int totalRows = 0;
    String? globalError;

    try {
      final client = await getOrInitClient();
      final Database db = await DbHelper.instance.database;

      // Désactiver temporairement les contraintes de clés étrangères pour l'insertion en masse
      await db.execute('PRAGMA foreign_keys = OFF;');

      final tablesQuery = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );
      final existingTables = tablesQuery.map((r) => r['name'] as String).toSet();

      final List<String> tablesToSync = orderedTables
          .where((t) => existingTables.contains(t))
          .toList();

      final totalSteps = tablesToSync.length;

      for (int step = 0; step < totalSteps; step++) {
        final table = tablesToSync[step];
        final progressPct = (step + 1) / totalSteps;

        final progress = SyncProgress(
          tableName: table,
          step: step + 1,
          totalSteps: totalSteps,
          percentage: progressPct,
          direction: SyncDirection.pull,
          message: 'Téléchargement de $table depuis le Cloud (${step + 1}/$totalSteps)...',
        );

        _currentProgress = progress;
        onProgress?.call(progress);
        notifyListeners();

        try {
          final columnsInfo = await db.rawQuery('PRAGMA table_info($table)');
          final validColumns = columnsInfo.map((r) => r['name'] as String).toSet();

          final response = await client.from(table).select();
          final List<dynamic> records = response as List<dynamic>;

          if (records.isEmpty) {
            rowsPerTable[table] = 0;
            continue;
          }

          final batch = db.batch();
          for (final item in records) {
            final row = sanitizeRowForSqlite(table, item as Map<String, dynamic>);
            row.removeWhere((col, _) => !validColumns.contains(col));
            batch.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);

          rowsPerTable[table] = records.length;
          totalRows += records.length;
        } catch (e) {
          debugPrint('Erreur pull table $table: $e');
          errorsPerTable[table] = e.toString();
        }
      }

      await db.execute('PRAGMA foreign_keys = ON;');
    } catch (e) {
      debugPrint('Erreur globale pull: $e');
      globalError = e.toString();
    }

    final completedAt = DateTime.now();
    final isSuccess = (globalError == null && errorsPerTable.isEmpty);

    return SyncResult(
      isSuccess: isSuccess,
      totalRowsSynced: totalRows,
      totalRowsPulled: totalRows,
      direction: SyncDirection.pull,
      rowsPerTable: rowsPerTable,
      errorsPerTable: errorsPerTable,
      startedAt: startedAt,
      completedAt: completedAt,
      globalError: globalError,
    );
  }

  /// Sauvegarde le résultat de synchronisation dans SharedPreferences
  Future<void> _persistSyncState(SyncResult result) async {
    _lastResult = result;
    _lastSyncDate = result.completedAt;
    _lastSyncSuccess = result.isSuccess;
    _lastSyncRowCount = result.totalRowsSynced;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastSyncDateKey, result.completedAt.toIso8601String());
      await prefs.setBool(_prefLastSyncSuccessKey, result.isSuccess);
      await prefs.setInt(_prefLastSyncRowCountKey, result.totalRowsSynced);
    } catch (e) {
      debugPrint('Erreur sauvegarde état synchro: $e');
    }
  }

  /// Envoi complet de toutes les tables SQLite vers Supabase (Push)
  /// Autorisé pour TOUS les profils (y compris Caissier)
  Future<SyncResult> pushAll({
    void Function(SyncProgress progress)? onProgress,
  }) async {
    if (_isSyncing) {
      throw Exception('Une synchronisation est déjà en cours.');
    }

    _isSyncing = true;
    _currentProgress = null;
    notifyListeners();

    try {
      final result = await _pushInternal(onProgress: onProgress);
      await _persistSyncState(result);
      return result;
    } finally {
      _isSyncing = false;
      _currentProgress = null;
      notifyListeners();
    }
  }

  /// Alias de compatibilité ascendante pour l'envoi complet
  Future<SyncResult> syncAll({
    void Function(SyncProgress progress)? onProgress,
  }) => pushAll(onProgress: onProgress);

  /// Téléchargement des données de Supabase vers SQLite local (Pull)
  /// RESTRICTION MÉTIER STRICTE : Le profil Caissier ne peut PAS effectuer de pull !
  Future<SyncResult> pullAll({
    void Function(SyncProgress progress)? onProgress,
    bool enforcePermissions = true,
  }) async {
    if (enforcePermissions) {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null && currentUser.isCaissier) {
        throw Exception(
          'Action non autorisée : Le profil Caissier est configuré pour l\'envoi uniquement (Push).',
        );
      }
    }

    if (_isSyncing) {
      throw Exception('Une synchronisation est déjà en cours.');
    }

    _isSyncing = true;
    _currentProgress = null;
    notifyListeners();

    try {
      final result = await _pullInternal(onProgress: onProgress);
      await _persistSyncState(result);
      return result;
    } finally {
      _isSyncing = false;
      _currentProgress = null;
      notifyListeners();
    }
  }

  /// Synchronisation bidirectionnelle : Envoi (Push) puis Téléchargement (Pull)
  /// RESTRICTION MÉTIER STRICTE : Le profil Caissier ne peut PAS effectuer de pull !
  Future<SyncResult> syncBidirectional({
    void Function(SyncProgress progress)? onProgress,
    bool enforcePermissions = true,
  }) async {
    if (enforcePermissions) {
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null && currentUser.isCaissier) {
        throw Exception(
          'Action non autorisée : Le profil Caissier est configuré pour l\'envoi uniquement (Push).',
        );
      }
    }

    if (_isSyncing) {
      throw Exception('Une synchronisation est déjà en cours.');
    }

    _isSyncing = true;
    _currentProgress = null;
    notifyListeners();

    try {
      final startedAt = DateTime.now();

      // 1. Envoi des modifications locales vers Supabase
      final pushResult = await _pushInternal(onProgress: onProgress);

      // 2. Téléchargement des nouveautés depuis Supabase
      final pullResult = await _pullInternal(onProgress: onProgress);

      final completedAt = DateTime.now();
      final combinedRows = <String, int>{};
      pushResult.rowsPerTable.forEach((k, v) => combinedRows[k] = v);
      pullResult.rowsPerTable.forEach((k, v) {
        combinedRows[k] = (combinedRows[k] ?? 0) + v;
      });

      final combinedErrors = <String, String>{};
      combinedErrors.addAll(pushResult.errorsPerTable);
      combinedErrors.addAll(pullResult.errorsPerTable);

      final isSuccess = pushResult.isSuccess && pullResult.isSuccess;
      final totalRows = pushResult.totalRowsSynced + pullResult.totalRowsSynced;

      final result = SyncResult(
        isSuccess: isSuccess,
        totalRowsSynced: totalRows,
        totalRowsPushed: pushResult.totalRowsSynced,
        totalRowsPulled: pullResult.totalRowsSynced,
        direction: SyncDirection.bidirectional,
        rowsPerTable: combinedRows,
        errorsPerTable: combinedErrors,
        startedAt: startedAt,
        completedAt: completedAt,
        globalError: pushResult.globalError ?? pullResult.globalError,
      );

      await _persistSyncState(result);
      return result;
    } finally {
      _isSyncing = false;
      _currentProgress = null;
      notifyListeners();
    }
  }
}
