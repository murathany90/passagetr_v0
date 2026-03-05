import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/offline_sync_controller.dart';
import '../data/local/offline_sync_queue_store.dart';
import 'remote_repository_providers.dart';

final Provider<OfflineSyncQueueStore> offlineSyncQueueStoreProvider =
    Provider<OfflineSyncQueueStore>((Ref ref) {
  return OfflineSyncQueueStore();
});

final StateNotifierProvider<OfflineSyncController, OfflineSyncStatus>
    offlineSyncControllerProvider =
    StateNotifierProvider<OfflineSyncController, OfflineSyncStatus>(
  (Ref ref) {
    return OfflineSyncController(
      queueStore: ref.watch(offlineSyncQueueStoreProvider),
      readingRemote: ref.watch(supabaseReadingRepositoryProvider),
      progressRemote: ref.watch(supabaseProgressRepositoryProvider),
    );
  },
);

final Provider<OfflineSyncStatus> offlineSyncStatusProvider =
    Provider<OfflineSyncStatus>((Ref ref) {
  return ref.watch(offlineSyncControllerProvider);
});

