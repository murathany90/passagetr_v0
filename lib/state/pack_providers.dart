import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/provider_cache.dart';
import '../data/local/app_content_local_datasource.dart';
import '../data/repositories/local_pack_repository.dart';
import '../data/repositories/supabase_pack_repository.dart';
import '../domain/entities/pack.dart';
import '../domain/repositories/pack_repository.dart';
import 'auth_providers.dart';
import 'content_providers.dart';

final Provider<PackRepository> packRepositoryProvider =
    Provider<PackRepository>((Ref ref) {
  final bool useLocalStaticContent = ref.watch(
    effectiveUseLocalStaticContentProvider,
  );
  if (useLocalStaticContent) {
    final AppContentLocalDataSource local = ref.watch(
      appContentLocalDataSourceProvider,
    );
    return LocalPackRepository(local);
  }
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabasePackRepository(client);
});

final AutoDisposeFutureProvider<List<Pack>> packListProvider =
    FutureProvider.autoDispose<List<Pack>>((Ref ref) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(minutes: 5));
  }
  final PackRepository repository = ref.watch(packRepositoryProvider);
  return repository.getPacksWithWordCount();
});
