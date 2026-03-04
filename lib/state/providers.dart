import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_session_service.dart';
import '../core/config/app_config.dart';
import '../core/services/translation_service.dart';
import '../core/utils/word_selection_utils.dart';
import '../data/local/app_content_local_database.dart';
import '../data/local/app_content_local_datasource.dart';
import '../data/local/dictionary_local_database.dart';
import '../data/local/dictionary_local_datasource.dart';
import '../data/remote/dictionary_supabase_datasource.dart';
import '../data/repositories/hybrid_reading_repository.dart';
import '../data/repositories/local_pack_repository.dart';
import '../data/repositories/local_word_repository.dart';
import '../data/repositories/offline_dictionary_repository.dart';
import '../data/repositories/supabase_grammar_repository.dart';
import '../data/repositories/supabase_pack_repository.dart';
import '../data/repositories/supabase_progress_repository.dart';
import '../data/repositories/supabase_reading_repository.dart';
import '../data/repositories/supabase_word_repository.dart';
import '../domain/entities/dictionary_bootstrap_state.dart';
import '../domain/entities/dictionary_entry.dart';
import '../domain/entities/dictionary_lookup_result.dart';
import '../domain/entities/grammar_module.dart';
import '../domain/entities/grammar_page.dart';
import '../domain/entities/grammar_page_detail.dart';
import '../domain/entities/pack.dart';
import '../domain/entities/passage_sentence.dart';
import '../domain/entities/home_dashboard_data.dart';
import '../domain/entities/reading_passage.dart';
import '../domain/entities/reading_resume_item.dart';
import '../domain/entities/sentence_translation.dart';
import '../domain/entities/tag_count.dart';
import '../domain/entities/user_reading_progress.dart';
import '../domain/entities/word_item.dart';
import '../domain/entities/word_level_summary.dart';
import '../domain/repositories/dictionary_repository.dart';
import '../domain/repositories/pack_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/repositories/grammar_repository.dart';
import '../domain/repositories/reading_repository.dart';
import '../domain/repositories/word_repository.dart';
import '../domain/value_objects/paged_result.dart';

final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) {
  return Supabase.instance.client;
});

final Provider<AuthSessionService> authSessionServiceProvider =
    Provider<AuthSessionService>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return AuthSessionService(client);
});

final FutureProvider<void> authBootstrapProvider = FutureProvider<void>((
  Ref ref,
) async {
  await ref.watch(authSessionServiceProvider).ensureAnonymousSession();
});

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

final Provider<PackRepository> packRepositoryProvider =
    Provider<PackRepository>((Ref ref) {
  if (AppConfig.useLocalStaticContent) {
    final AppContentLocalDataSource local = ref.watch(
      appContentLocalDataSourceProvider,
    );
    return LocalPackRepository(local);
  }
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabasePackRepository(client);
});

final Provider<WordRepository> wordRepositoryProvider =
    Provider<WordRepository>((Ref ref) {
  if (AppConfig.useLocalStaticContent) {
    final AppContentLocalDataSource local = ref.watch(
      appContentLocalDataSourceProvider,
    );
    return LocalWordRepository(local);
  }
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseWordRepository(client);
});

final Provider<ProgressRepository> progressRepositoryProvider =
    Provider<ProgressRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseProgressRepository(client);
});

final Provider<ReadingRepository> readingRepositoryProvider =
    Provider<ReadingRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  if (AppConfig.useLocalStaticContent) {
    final AppContentLocalDataSource local = ref.watch(
      appContentLocalDataSourceProvider,
    );
    return HybridReadingRepository(
      localDataSource: local,
      remoteDataSource: SupabaseReadingRepository(client),
    );
  }
  return SupabaseReadingRepository(client);
});

final Provider<GrammarRepository> grammarRepositoryProvider =
    Provider<GrammarRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseGrammarRepository(client);
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
});

final Provider<TranslationService> translationServiceProvider =
    Provider<TranslationService>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  final TranslationProvider provider =
      TranslationProvider.fromRaw(AppConfig.translateProvider);

  switch (provider) {
    case TranslationProvider.libre:
      return LibreTranslateService(
        endpoint: AppConfig.translateEndpoint,
        apiKey: AppConfig.translateApiKey,
      );
    case TranslationProvider.google:
      return GoogleCloudTranslateService(
        endpoint: AppConfig.translateEndpoint,
        apiKey: AppConfig.translateApiKey,
      );
    case TranslationProvider.deepl:
      return DeeplEdgeFunctionTranslationService(client: client);
  }
});

final FutureProvider<List<Pack>> packListProvider = FutureProvider<List<Pack>>((
  Ref ref,
) async {
  final PackRepository repository = ref.watch(packRepositoryProvider);
  return repository.getPacksWithWordCount();
});

final FutureProvider<List<WordLevelSummary>> wordLevelsProvider =
    FutureProvider<List<WordLevelSummary>>((Ref ref) async {
  final WordRepository repository = ref.watch(wordRepositoryProvider);
  return repository.getLevelsWithWordCount();
});

class WordLevelTagRequest {
  const WordLevelTagRequest({
    required this.level,
    this.search,
  });

  final String level;
  final String? search;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is WordLevelTagRequest &&
            other.level == level &&
            other.search == search);
  }

  @override
  int get hashCode => Object.hash(level, search);
}

final wordLevelTagsProvider =
    FutureProvider.family<List<TagCount>, WordLevelTagRequest>(
  (Ref ref, WordLevelTagRequest request) async {
    final WordRepository repository = ref.watch(wordRepositoryProvider);
    return repository.getTagsByLevel(
      request.level,
      search: request.search,
    );
  },
);

class WordLevelListRequest {
  const WordLevelListRequest({
    required this.level,
    this.query,
    this.pos,
    this.tag,
    this.limit = 50,
    this.offset = 0,
  });

  final String level;
  final String? query;
  final String? pos;
  final String? tag;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is WordLevelListRequest &&
            other.level == level &&
            other.query == query &&
            other.pos == pos &&
            other.tag == tag &&
            other.limit == limit &&
            other.offset == offset);
  }

  @override
  int get hashCode => Object.hash(level, query, pos, tag, limit, offset);
}

final wordLevelWordsProvider =
    FutureProvider.family<PagedResult<WordItem>, WordLevelListRequest>(
  (Ref ref, WordLevelListRequest request) async {
    final WordRepository repository = ref.watch(wordRepositoryProvider);
    return repository.getWordsByLevel(
      level: request.level,
      tag: request.tag,
      query: request.query,
      pos: request.pos,
      limit: request.limit,
      offset: request.offset,
    );
  },
);

final FutureProvider<List<GrammarModule>> grammarModulesProvider =
    FutureProvider<List<GrammarModule>>((Ref ref) async {
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getModules();
});

final grammarPagesProvider =
    FutureProvider.family<List<GrammarPage>, int>((Ref ref, int modulId) async {
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getPagesByModule(modulId: modulId);
});

final grammarPageDetailProvider =
    FutureProvider.family<GrammarPageDetail, int>((Ref ref, int sayfaId) async {
  final GrammarRepository repository = ref.watch(grammarRepositoryProvider);
  return repository.getPageDetail(sayfaId: sayfaId);
});

class ReadingListRequest {
  const ReadingListRequest({
    required this.packId,
    this.selectedLevels = const <String>{},
    this.limit = 20,
    this.offset = 0,
  });

  final String packId;
  final Set<String> selectedLevels;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReadingListRequest &&
            other.packId == packId &&
            _setEquals(other.selectedLevels, selectedLevels) &&
            other.limit == limit &&
            other.offset == offset);
  }

  @override
  int get hashCode => Object.hash(
        packId,
        Object.hashAll(selectedLevels.toList()..sort()),
        limit,
        offset,
      );
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final String item in a) {
    if (!b.contains(item)) {
      return false;
    }
  }
  return true;
}

final readingListProvider =
    FutureProvider.family<PagedResult<ReadingPassage>, ReadingListRequest>(
  (Ref ref, ReadingListRequest request) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getPassagesByPack(
      packId: request.packId,
      levels: request.selectedLevels,
      limit: request.limit,
      offset: request.offset,
    );
  },
);

final readingDetailProvider =
    FutureProvider.family<List<PassageSentence>, String>(
  (Ref ref, String passageId) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getSentences(passageId: passageId);
  },
);

class SentenceTranslationLookup {
  const SentenceTranslationLookup({
    required this.sentenceId,
    required this.provider,
    this.targetLang = 'tr',
  });

  final String sentenceId;
  final String provider;
  final String targetLang;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SentenceTranslationLookup &&
            other.sentenceId == sentenceId &&
            other.provider == provider &&
            other.targetLang == targetLang);
  }

  @override
  int get hashCode => Object.hash(sentenceId, provider, targetLang);
}

final sentenceTranslationControllerProvider =
    FutureProvider.family<SentenceTranslation?, SentenceTranslationLookup>(
  (Ref ref, SentenceTranslationLookup lookup) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getCachedTranslation(
      sentenceId: lookup.sentenceId,
      provider: lookup.provider,
      targetLang: lookup.targetLang,
    );
  },
);

class WordQuickViewRequest {
  const WordQuickViewRequest({
    required this.packId,
    required this.word,
  });

  final String packId;
  final String word;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is WordQuickViewRequest &&
            other.packId == packId &&
            other.word == word);
  }

  @override
  int get hashCode => Object.hash(packId, word);
}

class WordQuickViewState {
  const WordQuickViewState({
    required this.loading,
    this.wordItem,
    this.translatedText,
    this.sourceLabel,
    this.error,
  });

  final bool loading;
  final WordItem? wordItem;
  final String? translatedText;
  final String? sourceLabel;
  final String? error;

  factory WordQuickViewState.initial() {
    return const WordQuickViewState(loading: true);
  }

  WordQuickViewState copyWith({
    bool? loading,
    WordItem? wordItem,
    String? translatedText,
    String? sourceLabel,
    String? error,
    bool clearWordItem = false,
    bool clearTranslatedText = false,
    bool clearSourceLabel = false,
    bool clearError = false,
  }) {
    return WordQuickViewState(
      loading: loading ?? this.loading,
      wordItem: clearWordItem ? null : (wordItem ?? this.wordItem),
      translatedText:
          clearTranslatedText ? null : (translatedText ?? this.translatedText),
      sourceLabel: clearSourceLabel ? null : (sourceLabel ?? this.sourceLabel),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WordQuickViewController extends StateNotifier<WordQuickViewState> {
  WordQuickViewController({
    required this.ref,
    required this.request,
  }) : super(WordQuickViewState.initial()) {
    load();
  }

  final Ref ref;
  final WordQuickViewRequest request;

  static final Map<String, String> _translationCache = <String, String>{};

  Future<void> retry() => load();

  Future<void> load() async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      clearWordItem: true,
      clearTranslatedText: true,
      clearSourceLabel: true,
    );

    try {
      final WordRepository wordRepository = ref.read(wordRepositoryProvider);
      final DictionaryRepository dictionaryRepository = ref.read(
        dictionaryRepositoryProvider,
      );

      final String key = normalizeWordToken(request.word);
      if (key.isEmpty) {
        state = state.copyWith(
          loading: false,
          error: 'Kelime bos olamaz.',
          sourceLabel: 'Hata',
          clearWordItem: true,
          clearTranslatedText: true,
        );
        return;
      }

      // 1) Kelime karti oncelikli: once aktif pack, sonra global kart havuzu.
      final WordItem? cardWord =
          await _findWordCard(wordRepository, request.packId, key);
      if (cardWord != null) {
        final bool fromPack = (cardWord.packId ?? '').trim() == request.packId;
        state = state.copyWith(
          loading: false,
          wordItem: cardWord,
          sourceLabel: fromPack ? 'Kelime karti' : 'Kelime karti (global)',
          clearError: true,
          clearTranslatedText: true,
        );
        return;
      }

      // 2) Local dictionary.
      final List<DictionaryEntry> localEntries =
          await dictionaryRepository.searchLocal(
        query: key,
        limit: 5,
      );
      if (localEntries.isNotEmpty) {
        final String text = _buildDictionarySummary(localEntries);
        _translationCache[key] = text;
        state = state.copyWith(
          loading: false,
          translatedText: text,
          sourceLabel: 'Local sozluk',
          clearError: true,
          clearWordItem: true,
        );
        return;
      }

      // 3) Lokal runtime cache.
      final String? cached = _translationCache[key];
      if (cached != null && cached.trim().isNotEmpty) {
        state = state.copyWith(
          loading: false,
          translatedText: cached,
          sourceLabel: 'Lokal cache',
          clearError: true,
          clearWordItem: true,
        );
        return;
      }

      // 4) Fallback zinciri: local fallback cache -> server cache -> DeepL.
      final lookup = await dictionaryRepository.lookup(query: key);
      if (lookup.hasLocalEntries) {
        final String text = _buildDictionarySummary(lookup.entries);
        _translationCache[key] = text;
        state = state.copyWith(
          loading: false,
          translatedText: text,
          sourceLabel: 'Local sozluk',
          clearError: true,
          clearWordItem: true,
        );
        return;
      }

      if (lookup.hasFallback) {
        final String text = lookup.fallbackTranslatedText!.trim();
        _translationCache[key] = text;
        state = state.copyWith(
          loading: false,
          translatedText: text,
          sourceLabel: _resolveLookupSourceLabel(lookup),
          clearError: true,
          clearWordItem: true,
        );
        return;
      }

      if (lookup.hasError) {
        state = state.copyWith(
          loading: false,
          error: lookup.error!,
          sourceLabel: 'Hata',
          clearWordItem: true,
          clearTranslatedText: true,
        );
        return;
      }

      state = state.copyWith(
        loading: false,
        error: 'Sonuc bulunamadi.',
        sourceLabel: 'Sonuc yok',
        clearWordItem: true,
        clearTranslatedText: true,
      );
    } catch (error) {
      String message;
      if (error is TranslationException) {
        message = error.message;
      } else {
        message = 'Ceviri su an alinamadi.';
      }
      state = state.copyWith(
        loading: false,
        error: message,
        sourceLabel: 'Hata',
        clearWordItem: true,
        clearTranslatedText: true,
      );
    }
  }

  Future<WordItem?> _findWordCard(
    WordRepository wordRepository,
    String packId,
    String normalizedWord,
  ) async {
    final WordItem? exactInPack = await wordRepository.getWordByEnWord(
      packId: packId,
      enWord: normalizedWord,
    );
    if (exactInPack != null) {
      return exactInPack;
    }

    return wordRepository.getWordByEnWordGlobal(normalizedWord);
  }

  String _resolveLookupSourceLabel(DictionaryLookupResult lookup) {
    if (lookup.fromServerCache == true) {
      return 'Sunucu cache';
    }
    if (lookup.fromDeepL == true) {
      return 'DeepL sozluk';
    }
    return 'Lokal cache';
  }

  String _buildDictionarySummary(List<DictionaryEntry> entries) {
    final Iterable<DictionaryEntry> topEntries = entries.take(3);
    return topEntries.map((DictionaryEntry entry) {
      final String pos = (entry.pos ?? '').trim();
      if (pos.isEmpty) {
        return entry.trMeaning;
      }
      return '$pos | ${entry.trMeaning}';
    }).join('\n');
  }
}

final wordQuickViewControllerProvider = StateNotifierProvider.autoDispose
    .family<WordQuickViewController, WordQuickViewState, WordQuickViewRequest>(
  (Ref ref, WordQuickViewRequest request) {
    return WordQuickViewController(ref: ref, request: request);
  },
);

final readingProgressProvider =
    FutureProvider.family<UserReadingProgress?, String>(
  (Ref ref, String passageId) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getUserReadingProgress(passageId: passageId);
  },
);

final passageWordsProvider = FutureProvider.family<List<WordItem>, String>(
  (Ref ref, String passageId) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getPassageWords(passageId: passageId, limit: 400);
  },
);

final homeDashboardProvider =
    FutureProvider<HomeDashboardData>((Ref ref) async {
  Future<HomeDashboardData> loadOperation() async {
    final ProgressRepository progressRepository = ref.watch(
      progressRepositoryProvider,
    );
    final ReadingRepository readingRepository =
        ref.watch(readingRepositoryProvider);
    final PackRepository packRepository = ref.watch(packRepositoryProvider);
    final WordRepository wordRepository = ref.watch(wordRepositoryProvider);

    final int todayWordCount = await progressRepository.getTodayWordCount();
    final int todayReadSentenceCount =
        await readingRepository.getTodayReadSentenceCount();

    QuickStartSuggestion quickStart = const QuickStartSuggestion(
      type: QuickStartType.unavailable,
    );

    final ReadingResumeItem? resumeItem =
        await readingRepository.getLatestIncompleteReading();

    if (resumeItem != null) {
      Pack? resumePack;
      final String? packId = resumeItem.passage.packId;
      if (packId != null && packId.isNotEmpty) {
        resumePack = await packRepository.getPackById(packId);
      }
      quickStart = QuickStartSuggestion(
        type: QuickStartType.resumeReading,
        pack: resumePack,
        resumeItem: resumeItem,
      );
    } else {
      final List<Pack> packs = await packRepository.getPacksWithWordCount();
      if (packs.isNotEmpty) {
        final Pack defaultPack = packs.first;
        final List<String> weakIds = await progressRepository.getWeakWordIds(
          packId: defaultPack.id,
          limit: 10,
        );
        if (weakIds.isNotEmpty) {
          quickStart = QuickStartSuggestion(
            type: QuickStartType.weakWords,
            pack: defaultPack,
            wordIds: weakIds.take(10).toList(growable: false),
          );
        } else {
          final List<WordItem> randomPool =
              await wordRepository.getSessionBatch(
            defaultPack.id,
            limit: 50,
          );
          randomPool.shuffle();
          final List<String> randomIds = randomPool
              .take(10)
              .map((WordItem e) => e.id)
              .toList(growable: false);
          if (randomIds.isNotEmpty) {
            quickStart = QuickStartSuggestion(
              type: QuickStartType.randomWords,
              pack: defaultPack,
              wordIds: randomIds,
            );
          }
        }
      }
    }

    return HomeDashboardData(
      todayWordCount: todayWordCount,
      todayReadSentenceCount: todayReadSentenceCount,
      todaySolvedQuestionText: 'Yakinda',
      quickStart: quickStart,
    );
  }

  await ref.watch(authBootstrapProvider.future);
  try {
    return await loadOperation();
  } catch (error) {
    if (!_isMissingAuthSessionError(error)) {
      rethrow;
    }
    await ref.read(authSessionServiceProvider).ensureAnonymousSession();
    return loadOperation();
  }
});

bool _isMissingAuthSessionError(Object error) {
  final String text = error.toString().toLowerCase();
  return text.contains('auth session yok') ||
      text.contains('anonymous giris') ||
      text.contains('unauthenticated');
}
