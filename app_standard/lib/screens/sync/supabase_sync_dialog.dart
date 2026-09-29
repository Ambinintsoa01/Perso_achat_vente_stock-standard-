import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_sync_service.dart';
import 'supabase_config_dialog.dart';

class SupabaseSyncDialog extends StatefulWidget {
  const SupabaseSyncDialog({super.key});

  @override
  State<SupabaseSyncDialog> createState() => _SupabaseSyncDialogState();
}

class _SupabaseSyncDialogState extends State<SupabaseSyncDialog> {
  final SupabaseSyncService _syncService = SupabaseSyncService.instance;
  bool _isConfigured = false;
  String? _url;
  bool _showTableDetails = false;
  SyncDirection _selectedDirection = SyncDirection.bidirectional;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    if (user != null && user.isCaissier) {
      _selectedDirection = SyncDirection.push;
    }
    _checkConfig();
  }

  Future<void> _checkConfig() async {
    final configured = await _syncService.isConfigured();
    final url = await _syncService.getUrl();
    if (mounted) {
      setState(() {
        _isConfigured = configured;
        _url = url;
      });
    }
  }

  Future<void> _handleStartSync() async {
    final user = AuthService.instance.currentUser;
    final isCaissier = user?.isCaissier ?? false;
    final targetDirection = isCaissier ? SyncDirection.push : _selectedDirection;

    final configured = await _syncService.isConfigured();
    if (!configured) {
      if (!mounted) return;
      final configuredNow = await showDialog<bool>(
        context: context,
        builder: (_) => const SupabaseConfigDialog(),
      );
      if (configuredNow != true) return;
      await _checkConfig();
    }

    try {
      if (targetDirection == SyncDirection.push) {
        await _syncService.pushAll();
      } else if (targetDirection == SyncDirection.pull) {
        await _syncService.pullAll();
      } else {
        await _syncService.syncBidirectional();
      }
      await _checkConfig();
    } catch (e) {
      debugPrint('Sync dialog error: $e');
    }
  }

  Future<void> _handleOpenConfig() async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => const SupabaseConfigDialog(),
    );
    if (updated == true) {
      await _checkConfig();
    }
  }

  String _formatMaskedUrl(String? url) {
    if (url == null || url.isEmpty) return 'Non configuré';
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.length > 25) {
        return '${host.substring(0, 15)}...${host.substring(host.length - 8)}';
      }
      return host;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _syncService,
      builder: (context, _) {
        final isSyncing = _syncService.isSyncing;
        final progress = _syncService.currentProgress;
        final lastResult = _syncService.lastResult;
        final lastSyncDate = _syncService.lastSyncDate;
        final lastSyncSuccess = _syncService.lastSyncSuccess;
        final user = AuthService.instance.currentUser;
        final isCaissier = user?.isCaissier ?? false;

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.cloud_sync_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Synchronisation Supabase',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _isConfigured
                                  ? 'Cloud PostgreSQL connecté'
                                  : 'Configuration requise',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isConfigured ? Colors.green.shade700 : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Paramètres Supabase',
                        icon: const Icon(Icons.settings_outlined, size: 22, color: Colors.black87),
                        onPressed: isSyncing ? null : _handleOpenConfig,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black54),
                        onPressed: isSyncing ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Carte récapitulative
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dns_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatMaskedUrl(_url),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _isConfigured ? Colors.green.shade800 : Colors.orange.shade800,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _isConfigured ? 'PRÊT' : 'CONFIGURER',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DERNIÈRE SYNCHRO',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastSyncDate != null
                                      ? DateFormat('dd/MM/yyyy à HH:mm').format(lastSyncDate)
                                      : 'Jamais synchronisé',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            if (lastSyncSuccess != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: lastSyncSuccess
                                      ? Colors.green.withValues(alpha: 0.25)
                                      : Colors.red.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: lastSyncSuccess
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      lastSyncSuccess
                                          ? Icons.check_circle_rounded
                                          : Icons.error_rounded,
                                      color: lastSyncSuccess
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      lastSyncSuccess ? 'Succès' : 'Erreur',
                                      style: TextStyle(
                                        color: lastSyncSuccess
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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

                  // Sélecteur de mode ou Avertissement RBAC Caissier
                  if (isCaissier)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, size: 20, color: Colors.amber.shade900),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              // children: [
                              //   Text(
                              //     'Profil Caissier : Envoi uniquement (Push)',
                              //     style: TextStyle(
                              //       fontWeight: FontWeight.bold,
                              //       fontSize: 12,
                              //       color: Colors.amber.shade900,
                              //     ),
                              //   ),
                              //   const SizedBox(height: 2),
                              //   Text(
                              //     'Vos commandes et encaissements sont envoyés vers le Cloud. Le téléchargement depuis le Cloud est réservé à la gérance.',
                              //     style: TextStyle(
                              //       fontSize: 11,
                              //       color: Colors.amber.shade900,
                              //     ),
                              //   ),
                              // ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDirectionChip(
                              direction: SyncDirection.bidirectional,
                              title: 'Complète',
                              subtitle: 'Push + Pull',
                              icon: Icons.sync_rounded,
                              isSyncing: isSyncing,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildDirectionChip(
                              direction: SyncDirection.push,
                              title: 'Envoyer',
                              subtitle: 'Push Cloud',
                              icon: Icons.cloud_upload_outlined,
                              isSyncing: isSyncing,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildDirectionChip(
                              direction: SyncDirection.pull,
                              title: 'Recevoir',
                              subtitle: 'Pull Cloud',
                              icon: Icons.cloud_download_outlined,
                              isSyncing: isSyncing,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isSyncing) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                progress != null
                                    ? 'Table ${progress.step}/${progress.totalSteps}'
                                    : 'Initialisation...',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black87,
                                ),
                              ),
                              if (progress != null)
                                Text(
                                  '${(progress.percentage * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress?.percentage,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            progress?.message ?? 'Connexion au serveur...',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Résultat du dernier sync
                  if (!isSyncing && lastResult != null) ...[
                    if (!lastResult.isSuccess) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red.shade800),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lastResult.globalError ??
                                    'Des erreurs sont survenues sur ${lastResult.errorsPerTable.length} table(s).',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Résumé des enregistrements synchronisés
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 18, color: Colors.black87),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _formatSyncSummary(lastResult),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () {
                              setState(() => _showTableDetails = !_showTableDetails);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.black87,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _showTableDetails ? 'Masquer' : 'Détails',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Icon(
                                  _showTableDetails
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Détails par table
                    if (_showTableDetails) ...[
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: lastResult.rowsPerTable.length,
                            separatorBuilder: (context, index) => Divider(height: 6, color: Colors.grey.shade100),
                            itemBuilder: (context, i) {
                              final entry = lastResult.rowsPerTable.entries.elementAt(i);
                              final hasError = lastResult.errorsPerTable.containsKey(entry.key);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: hasError ? Colors.red.shade800 : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasError)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Erreur',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        '${entry.value} ligne(s)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],

                    // Actions inférieures
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: isSyncing ? null : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black54,
                            ),
                            child: const Text('Fermer'),
                          ),
                          ElevatedButton.icon(
                            onPressed: isSyncing ? null : _handleStartSync,
                            icon: isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(_getActionButtonIcon(isCaissier), size: 18),
                            label: Text(
                              _getActionButtonLabel(isSyncing, _isConfigured, isCaissier),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectionChip({
    required SyncDirection direction,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSyncing,
  }) {
    final isSelected = _selectedDirection == direction;
    return InkWell(
      onTap: isSyncing ? null : () => setState(() => _selectedDirection = direction),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
                color: isSelected ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSyncSummary(SyncResult res) {
    switch (res.direction) {
      case SyncDirection.push:
        return '${res.totalRowsSynced} enregistrement(s) envoyé(s)';
      case SyncDirection.pull:
        return '${res.totalRowsSynced} enregistrement(s) téléchargé(s)';
      case SyncDirection.bidirectional:
        return '${res.totalRowsSynced} enregistrement(s) synchronisé(s) (${res.totalRowsPushed} ↑, ${res.totalRowsPulled} ↓)';
    }
  }

  IconData _getActionButtonIcon(bool isCaissier) {
    if (isCaissier) return Icons.cloud_upload_rounded;
    switch (_selectedDirection) {
      case SyncDirection.bidirectional:
        return Icons.sync_rounded;
      case SyncDirection.push:
        return Icons.cloud_upload_rounded;
      case SyncDirection.pull:
        return Icons.cloud_download_rounded;
    }
  }

  String _getActionButtonLabel(bool isSyncing, bool isConfigured, bool isCaissier) {
    if (isSyncing) return 'Synchronisation...';
    if (!isConfigured) return 'Configurer & Synchroniser';
    if (isCaissier) return 'Envoyer ';
    switch (_selectedDirection) {
      case SyncDirection.bidirectional:
        return 'Synchroniser';
      case SyncDirection.push:
        return 'Envoyer';
      case SyncDirection.pull:
        return 'Télécharger';
    }
  }
}
