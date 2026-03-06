import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/resilient_progress_repository.dart';
import '../domain/repositories/progress_repository.dart';
import 'offline_sync_providers.dart';
import 'remote_repository_providers.dart';

final Provider<ProgressRepository> progressRepositoryProvider =
    Provider<ProgressRepository>((Ref ref) {
  return ResilientProgressRepository(
    baseRepository: ref.watch(supabaseProgressRepositoryProvider),
    syncCoordinator: ref.watch(offlineSyncControllerProvider.notifier),
  );
});
