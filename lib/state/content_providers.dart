import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/services/translation_service.dart';
import '../data/local/app_content_local_database.dart';
import '../data/local/app_content_local_datasource.dart';
import '../data/local/dictionary_local_database.dart';
import '../data/local/dictionary_local_datasource.dart';
import '../data/remote/dictionary_supabase_datasource.dart';
import '../data/repositories/offline_dictionary_repository.dart';
import '../domain/entities/dictionary_bootstrap_state.dart';
import '../domain/repositories/dictionary_repository.dart';
import 'auth_providers.dart';
import 'offline_sync_providers.dart';
import 'translation_providers.dart';

final Provider<AppContentLocalDatabase> appContentLocalDatabaseProvider =
    Provider<AppContentLocalDatabase>((Ref ref) {
  final AppContentLocalDatabase database = AppContentLocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final Provider<AppContentLocalDataSource> appContentLocalDataSourceProvider =
    Provider<AppContentLocalDataSource>((Ref ref) {
  final AppContentLocalDatabase database = ref.watch(
    appContentLocalDatabaseProvider,
  );
  return AppContentLocalDataSource(database);
});

final FutureProvider<void> appContentBootstrapProvider =
    FutureProvider<void>((Ref ref) async {
  final AppContentLocalDataSource local = ref.watch(
    appContentLocalDataSourceProvider,
  );
  await local.ensureReady();
});

final FutureProvider<String> appContentDatasetVersionProvider =
    FutureProvider<String>((Ref ref) async {
  final AppContentLocalDataSource local = ref.watch(
    appContentLocalDataSourceProvider,
  );
  return local.getDatasetVersion();
});

final Provider<DictionaryLocalDatabase> dictionaryLocalDatabaseProvider =
    Provider<DictionaryLocalDatabase>((Ref ref) {
  final DictionaryLocalDatabase database = DictionaryLocalDatabase();
  ref.onDispose(database.close);
  return database;
});

final Provider<DictionaryLocalDataSource> dictionaryLocalDataSourceProvider =
    Provider<DictionaryLocalDataSource>((Ref ref) {
  final DictionaryLocalDatabase database = ref.watch(
    dictionaryLocalDatabaseProvider,
  );
  return DictionaryLocalDataSource(database);
});

final Provider<DictionarySupabaseDataSource>
    dictionarySupabaseDataSourceProvider =
    Provider<DictionarySupabaseDataSource>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return DictionarySupabaseDataSource(client);
});

final Provider<DictionaryRepository> dictionaryRepositoryProvider =
    Provider<DictionaryRepository>((Ref ref) {
  final DictionaryLocalDataSource local = ref.watch(
    dictionaryLocalDataSourceProvider,
  );
  final DictionarySupabaseDataSource remote = ref.watch(
    dictionarySupabaseDataSourceProvider,
  );
  final TranslationService translationService = ref.watch(
    translationServiceProvider,
  );
  return OfflineDictionaryRepository(
    localDataSource: local,
    remoteDataSource: remote,
    translationService: translationService,
  );
});

final FutureProvider<DictionaryBootstrapState> dictionaryAppBootstrapProvider =
    FutureProvider<DictionaryBootstrapState>((Ref ref) async {
  final DictionaryRepository repository =
      ref.watch(dictionaryRepositoryProvider);
  return repository.ensureBootstrapped();
});

final FutureProvider<void> appBootstrapProvider = FutureProvider<void>((
  Ref ref,
) async {
  if (AppConfig.useLocalStaticContent) {
    await ref.watch(appContentBootstrapProvider.future);
  }
  await ref.watch(dictionaryAppBootstrapProvider.future);
  await ref.watch(authBootstrapProvider.future);
  await ref
      .read(offlineSyncControllerProvider.notifier)
      .flushPending(silent: true);
});
