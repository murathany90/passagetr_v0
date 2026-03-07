import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/provider_cache.dart';
import '../domain/repositories/progress_repository.dart';
import 'auth_providers.dart';
import 'content_providers.dart';
import 'pack_providers.dart';
import 'progress_providers.dart';

/// Provides the count of weak words for the default pack.
/// Returns 0 when no packs exist or an error occurs.
final AutoDisposeFutureProvider<int> weakWordCountProvider =
    FutureProvider.autoDispose<int>((Ref ref) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(minutes: 1));
  }
  // Wait for auth before making progress queries.
  await ref.watch(authBootstrapProvider.future);
  final packs = await ref.watch(packListProvider.future);
  if (packs.isEmpty) {
    return 0;
  }

  final ProgressRepository progress = ref.watch(progressRepositoryProvider);
  final List<String> ids = await progress.getWeakWordIds(
    packId: packs.first.id,
    limit: 99,
  );
  return ids.length;
});
