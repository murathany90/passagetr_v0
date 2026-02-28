import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_session_service.dart';
import '../core/config/app_config.dart';
import '../core/services/translation_service.dart';
import '../data/repositories/supabase_pack_repository.dart';
import '../data/repositories/supabase_progress_repository.dart';
import '../data/repositories/supabase_reading_repository.dart';
import '../data/repositories/supabase_word_repository.dart';
import '../domain/entities/pack.dart';
import '../domain/entities/passage_sentence.dart';
import '../domain/entities/home_dashboard_data.dart';
import '../domain/entities/reading_passage.dart';
import '../domain/entities/reading_resume_item.dart';
import '../domain/entities/sentence_translation.dart';
import '../domain/entities/user_reading_progress.dart';
import '../domain/entities/word_item.dart';
import '../domain/repositories/pack_repository.dart';
import '../domain/repositories/progress_repository.dart';
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

final Provider<PackRepository> packRepositoryProvider =
    Provider<PackRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabasePackRepository(client);
});

final Provider<WordRepository> wordRepositoryProvider =
    Provider<WordRepository>((Ref ref) {
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
  return SupabaseReadingRepository(client);
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

class ReadingListRequest {
  const ReadingListRequest({
    required this.packId,
    this.limit = 20,
    this.offset = 0,
  });

  final String packId;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReadingListRequest &&
            other.packId == packId &&
            other.limit == limit &&
            other.offset == offset);
  }

  @override
  int get hashCode => Object.hash(packId, limit, offset);
}

final readingListProvider =
    FutureProvider.family<PagedResult<ReadingPassage>, ReadingListRequest>(
  (Ref ref, ReadingListRequest request) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getPassagesByPack(
      packId: request.packId,
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
    this.error,
  });

  final bool loading;
  final WordItem? wordItem;
  final String? translatedText;
  final String? error;

  factory WordQuickViewState.initial() {
    return const WordQuickViewState(loading: true);
  }

  WordQuickViewState copyWith({
    bool? loading,
    WordItem? wordItem,
    String? translatedText,
    String? error,
    bool clearWordItem = false,
    bool clearTranslatedText = false,
    bool clearError = false,
  }) {
    return WordQuickViewState(
      loading: loading ?? this.loading,
      wordItem: clearWordItem ? null : (wordItem ?? this.wordItem),
      translatedText:
          clearTranslatedText ? null : (translatedText ?? this.translatedText),
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
    );

    try {
      final WordRepository wordRepository = ref.read(wordRepositoryProvider);
      final TranslationService translationService = ref.read(
        translationServiceProvider,
      );

      final WordItem? found = await wordRepository.getWordByEnWord(
        packId: request.packId,
        enWord: request.word,
      );

      if (found != null) {
        state = state.copyWith(
          loading: false,
          wordItem: found,
          clearError: true,
          clearTranslatedText: true,
        );
        return;
      }

      final String key = request.word.trim().toLowerCase();
      final String? cached = _translationCache[key];
      if (cached != null && cached.trim().isNotEmpty) {
        state = state.copyWith(
          loading: false,
          translatedText: cached,
          clearError: true,
          clearWordItem: true,
        );
        return;
      }

      if (!translationService.isConfigured) {
        state = state.copyWith(
          loading: false,
          error: 'Ceviri su an alinamadi.',
          clearWordItem: true,
          clearTranslatedText: true,
        );
        return;
      }

      final String translated = await translationService.translateEnToTr(
        request.word,
      );
      _translationCache[key] = translated;

      state = state.copyWith(
        loading: false,
        translatedText: translated,
        clearError: true,
        clearWordItem: true,
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
        clearWordItem: true,
        clearTranslatedText: true,
      );
    }
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
    return repository.getPassageWords(passageId: passageId, limit: 20);
  },
);

final homeDashboardProvider =
    FutureProvider<HomeDashboardData>((Ref ref) async {
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
        final List<WordItem> randomPool = await wordRepository.getSessionBatch(
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
});
