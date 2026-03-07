import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/provider_cache.dart';
import '../data/repositories/hybrid_grammar_repository.dart';
import '../data/repositories/supabase_grammar_repository.dart';
import '../domain/entities/grammar_module.dart';
import '../domain/entities/grammar_page.dart';
import '../domain/entities/grammar_page_detail.dart';
import '../domain/repositories/grammar_repository.dart';
import 'auth_providers.dart';
import 'content_providers.dart';

final Provider<GrammarRepository> grammarRepositoryProvider =
    Provider<GrammarRepository>((Ref ref) {
  final bool useLocalStaticContent = ref.watch(
    effectiveUseLocalStaticContentProvider,
  );
  if (useLocalStaticContent) {
    return HybridGrammarRepository(
      localDataSource: ref.watch(appContentLocalDataSourceProvider),
      remoteDataSource:
          SupabaseGrammarRepository(ref.watch(supabaseClientProvider)),
    );
  }
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseGrammarRepository(client);
});

final AutoDisposeFutureProvider<List<GrammarModule>> grammarModulesProvider =
    FutureProvider.autoDispose<List<GrammarModule>>((Ref ref) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(minutes: 5));
  }
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getModules();
});

final grammarPagesProvider =
    FutureProvider.autoDispose.family<List<GrammarPage>, int>((
  Ref ref,
  int modulId,
) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(minutes: 5));
  }
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getPagesByModule(modulId: modulId);
});

final grammarPageDetailProvider =
    FutureProvider.autoDispose.family<GrammarPageDetail, int>((
  Ref ref,
  int sayfaId,
) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(minutes: 2));
  }
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getPageDetail(sayfaId: sayfaId);
});
