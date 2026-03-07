import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../core/services/translation_service.dart';
import '../data/local/app_content_local_database.dart';
import '../data/local/app_content_local_datasource.dart';
import '../data/local/dictionary_local_database.dart';
import '../data/local/dictionary_local_datasource.dart';
import '../data/local/local_database_runtime_info.dart';
import '../data/remote/dictionary_supabase_datasource.dart';
import '../data/repositories/offline_dictionary_repository.dart';
import '../data/repositories/web_remote_dictionary_repository.dart';
import '../domain/entities/dictionary_bootstrap_state.dart';
import '../domain/repositories/dictionary_repository.dart';
import 'auth_providers.dart';
import 'translation_providers.dart';

enum ContentHydrationStatus {
  idle,
  loading,
  ready,
  failed,
}

class ContentHydrationState {
  const ContentHydrationState({
    required this.status,
    required this.progress,
    required this.message,
    this.warningMessage,
    this.errorMessage,
  });

  const ContentHydrationState.initial()
      : status = ContentHydrationStatus.idle,
        progress = 0,
        message = 'Hazir degil',
        warningMessage = null,
        errorMessage = null;

  final ContentHydrationStatus status;
  final double progress;
  final String message;
  final String? warningMessage;
  final String? errorMessage;

  bool get isReady => status == ContentHydrationStatus.ready;
  bool get isLoading => status == ContentHydrationStatus.loading;
  bool get hasError => status == ContentHydrationStatus.failed;

  ContentHydrationState copyWith({
    ContentHydrationStatus? status,
    double? progress,
    String? message,
    String? warningMessage,
    String? errorMessage,
    bool clearWarning = false,
    bool clearError = false,
  }) {
    return ContentHydrationState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      warningMessage:
          clearWarning ? null : (warningMessage ?? this.warningMessage),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

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
  final bool useLocalStaticContent = ref.watch(
    effectiveUseLocalStaticContentProvider,
  );
  if (!useLocalStaticContent) {
    return 'remote-web';
  }
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
  final DictionarySupabaseDataSource remote = ref.watch(
    dictionarySupabaseDataSourceProvider,
  );
  final TranslationService translationService = ref.watch(
    translationServiceProvider,
  );
  final bool useLocalStaticContent = ref.watch(
    effectiveUseLocalStaticContentProvider,
  );

  if (!useLocalStaticContent) {
    return WebRemoteDictionaryRepository(
      remoteDataSource: remote,
      translationService: translationService,
    );
  }

  final DictionaryLocalDataSource local = ref.watch(
    dictionaryLocalDataSourceProvider,
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

final Provider<bool> isWebPlatformProvider =
    Provider<bool>((Ref ref) => kIsWeb);

final StateProvider<bool?> localStaticContentOverrideProvider =
    StateProvider<bool?>((Ref ref) => null);

final Provider<bool> effectiveUseLocalStaticContentProvider =
    Provider<bool>((Ref ref) {
  if (ref.watch(isWebPlatformProvider)) {
    final bool? overrideValue = ref.watch(localStaticContentOverrideProvider);
    return overrideValue ?? false;
  }
  final bool? overrideValue = ref.watch(localStaticContentOverrideProvider);
  return overrideValue ?? AppConfig.useLocalStaticContent;
});

final Provider<bool> shouldUseContentHydrationProvider = Provider<bool>((
  Ref ref,
) {
  return ref.watch(isWebPlatformProvider) &&
      ref.watch(effectiveUseLocalStaticContentProvider);
});

final FutureProvider<void> coreBootstrapProvider = FutureProvider<void>((
  Ref ref,
) async {
  await ref.watch(authBootstrapProvider.future);
});

final FutureProvider<void> appBootstrapProvider = coreBootstrapProvider;

final StateNotifierProvider<ContentHydrationController, ContentHydrationState>
    contentHydrationControllerProvider =
    StateNotifierProvider<ContentHydrationController, ContentHydrationState>((
  Ref ref,
) {
  return ContentHydrationController(ref);
});

class ContentHydrationController extends StateNotifier<ContentHydrationState> {
  ContentHydrationController(this._ref)
      : super(const ContentHydrationState.initial());

  final Ref _ref;
  Future<void>? _pending;

  Future<void> ensureHydrated() {
    if (!_ref.read(shouldUseContentHydrationProvider)) {
      state = const ContentHydrationState(
        status: ContentHydrationStatus.ready,
        progress: 1,
        message: 'Hazir',
      );
      return Future<void>.value();
    }

    return _pending ??= _hydrate();
  }

  Future<void> retry() {
    _pending = null;
    _ref.read(localStaticContentOverrideProvider.notifier).state = null;
    _ref.invalidate(appContentBootstrapProvider);
    _ref.invalidate(dictionaryAppBootstrapProvider);
    _ref.invalidate(appContentLocalDataSourceProvider);
    _ref.invalidate(appContentLocalDatabaseProvider);
    _ref.invalidate(dictionaryLocalDataSourceProvider);
    _ref.invalidate(dictionaryLocalDatabaseProvider);
    _ref.invalidate(dictionaryRepositoryProvider);
    state = const ContentHydrationState.initial();
    return ensureHydrated();
  }

  Future<void> _hydrate() async {
    state = const ContentHydrationState(
      status: ContentHydrationStatus.loading,
      progress: 0.08,
      message: 'Yerel icerik hazirlaniyor',
    );

    try {
      await _ref.read(appContentBootstrapProvider.future);
      final LocalDatabaseRuntimeInfo appRuntimeInfo =
          await getAppContentLocalDatabaseRuntimeInfo();

      state = ContentHydrationState(
        status: ContentHydrationStatus.loading,
        progress: 0.55,
        message: 'Sozluk verisi hazirlaniyor',
        warningMessage: appRuntimeInfo.warningMessage,
      );

      await _ref.read(dictionaryAppBootstrapProvider.future);
      final LocalDatabaseRuntimeInfo dictionaryRuntimeInfo =
          await getDictionaryLocalDatabaseRuntimeInfo();

      state = ContentHydrationState(
        status: ContentHydrationStatus.ready,
        progress: 1,
        message: 'Hazir',
        warningMessage: _mergeWarnings(
          appRuntimeInfo.warningMessage,
          dictionaryRuntimeInfo.warningMessage,
        ),
      );
    } catch (error) {
      if (_ref.read(isWebPlatformProvider)) {
        _ref.read(localStaticContentOverrideProvider.notifier).state = false;
        state = const ContentHydrationState(
          status: ContentHydrationStatus.ready,
          progress: 1,
          message: 'Hazir',
          warningMessage:
              'Yerel web verisi acilamadi. Cevrimici veri kullaniliyor.',
        );
        return;
      }
      state = ContentHydrationState(
        status: ContentHydrationStatus.failed,
        progress: 0,
        message: 'Yerel icerik hazirlanamadi',
        errorMessage: error.toString(),
      );
    } finally {
      _pending = null;
    }
  }

  String? _mergeWarnings(String? first, String? second) {
    final List<String> values = <String>[
      if (first != null && first.trim().isNotEmpty) first.trim(),
      if (second != null && second.trim().isNotEmpty) second.trim(),
    ];
    if (values.isEmpty) {
      return null;
    }
    return values.toSet().join('\n');
  }
}
