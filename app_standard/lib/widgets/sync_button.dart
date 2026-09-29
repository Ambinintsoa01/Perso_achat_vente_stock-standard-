import 'package:flutter/material.dart';
import '../screens/sync/supabase_sync_dialog.dart';
import '../services/supabase_sync_service.dart';

class SyncButton extends StatelessWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SupabaseSyncService.instance,
      builder: (context, _) {
        final syncService = SupabaseSyncService.instance;
        final isSyncing = syncService.isSyncing;
        final lastSuccess = syncService.lastSyncSuccess;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Tooltip(
            message: isSyncing
                ? 'Synchronisation Supabase en cours...'
                : 'Synchroniser avec Supabase',
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  barrierDismissible: !isSyncing,
                  builder: (_) => const SupabaseSyncDialog(),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSyncing
                      ? Colors.black.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSyncing ? Colors.black54 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (isSyncing)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        else
                          const Icon(
                            Icons.cloud_sync_outlined,
                            size: 18,
                            color: Colors.black87,
                          ),
                        if (!isSyncing && lastSuccess != null)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: lastSuccess ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isSyncing ? 'Synchro...' : 'Sync',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
