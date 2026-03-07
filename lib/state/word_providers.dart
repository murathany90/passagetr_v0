import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/provider_cache.dart';
import '../core/services/translation_service.dart';
import '../core/utils/lru_cache.dart';
import '../core/utils/word_selection_utils.dart';
import '../data/local/app_content_local_datasource.dart';
import '../data/repositories/local_word_repository.dart';
import '../data/repositories/supabase_word_repository.dart';
import '../domain/entities/dictionary_entry.dart';
import '../domain/entities/dictionary_lookup_result.dart';
import '../domain/entities/tag_count.dart';
import '../domain/entities/word_item.dart';
import '../domain/entities/word_level_progress_summary.dart';
import '../domain/entities/word_level_summary.dart';
import '../domain/repositories/dictionary_repository.dart';
import '../domain/repositories/word_repository.dart';
import '../domain/value_objects/paged_result.dart';
import 'auth_providers.dart';
import 'content_providers.dart';
import 'progress_providers.dart';

final Provider<WordRepository> wordRepositoryProvider =
    Provider<WordRepository>((Ref ref) {
  final bool useLocalStaticContent = ref.watch(
    effectiveUseLocalStaticContentProvider,
  );
  if (useLocalStaticContent) {
    final AppContentLocalDataSource local = ref.watch(
      appContentLocalDataSourceProvider,
    );
    return LocalWordRepository(local);
  }
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseWordRepository(client);
});

final AutoDisposeFutureProvider<List<WordLevelSummary>> wordLevelsProvider =
    FutureProvider.autoDispose<List<WordLevelSummary>>((Ref ref) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(minutes: 5));
  }
  final WordRepository repository = ref.watch(wordRepositoryProvider);
  return repository.getLevelsWithWordCount();
});

final AutoDisposeFutureProvider<List<WordLevelProgressSummary>>
    wordLevelProgressProvider =
    FutureProvider.autoDispose<List<WordLevelProgressSummary>>((Ref ref) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(minutes: 5));
  }
  final List<WordLevelSummary> levels =
      await ref.watch(wordLevelsProvider.future);
  final progressRepository = ref.watch(progressRepositoryProvider);
  final Map<String, int> studiedCounts =
      await progressRepository.getStudiedWordCountByLevel(
    levels: levels.map((WordLevelSummary level) => level.level).toList(),
  );

  return levels
      .map(
        (WordLevelSummary level) => WordLevelProgressSummary(
          level: level.level,
          wordCount: level.wordCount,
          studiedWordCount: studiedCounts[level.level] ?? 0,
        ),
      )
      .toList(growable: false);
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
    FutureProvider.autoDispose.family<List<TagCount>, WordLevelTagRequest>(
  (Ref ref, WordLevelTagRequest request) async {
    if (ref.watch(isWebPlatformProvider)) {
      ref.cacheFor(const Duration(minutes: 2));
    }
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
    FutureProvider.autoDispose.family<PagedResult<WordItem>, WordLevelListRequest>(
  (Ref ref, WordLevelListRequest request) async {
    if (ref.watch(isWebPlatformProvider)) {
      ref.cacheFor(const Duration(minutes: 2));
    }
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

class DistinctPosRequest {
  const DistinctPosRequest({
    this.packId,
    this.level,
  });

  final String? packId;
  final String? level;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is DistinctPosRequest &&
            other.packId == packId &&
            other.level == level);
  }

  @override
  int get hashCode => Object.hash(packId, level);
}

final distinctPosValuesProvider =
    FutureProvider.autoDispose.family<List<String>, DistinctPosRequest>(
  (Ref ref, DistinctPosRequest request) async {
    if (ref.watch(isWebPlatformProvider)) {
      ref.cacheFor(const Duration(minutes: 2));
    }
    final WordRepository repository = ref.watch(wordRepositoryProvider);
    return repository.getDistinctPosValues(
      packId: request.packId,
      level: request.level,
    );
  },
);

// ---------------------------------------------------------------------------
// Word Quick View
// ---------------------------------------------------------------------------

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

  static final LruCache<String, String> _translationCache =
      LruCache<String, String>(maxSize: 500);

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
        _translationCache.put(key, text);
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
      final String? cached = _translationCache.get(key);
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
        _translationCache.put(key, text);
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
        _translationCache.put(key, text);
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
