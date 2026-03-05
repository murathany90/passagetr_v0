import 'package:passagetr/core/services/translation_service.dart';
import 'package:passagetr/domain/entities/dictionary_bootstrap_state.dart';
import 'package:passagetr/domain/entities/dictionary_entry.dart';
import 'package:passagetr/domain/entities/dictionary_lookup_result.dart';
import 'package:passagetr/domain/entities/passage_sentence.dart';
import 'package:passagetr/domain/entities/reading_passage.dart';
import 'package:passagetr/domain/entities/reading_resume_item.dart';
import 'package:passagetr/domain/entities/sentence_translation.dart';
import 'package:passagetr/domain/entities/tag_count.dart';
import 'package:passagetr/domain/entities/user_reading_progress.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/domain/entities/word_level_summary.dart';
import 'package:passagetr/domain/repositories/dictionary_repository.dart';
import 'package:passagetr/domain/repositories/reading_repository.dart';
import 'package:passagetr/domain/repositories/word_repository.dart';
import 'package:passagetr/domain/value_objects/paged_result.dart';

class FakeTranslationService extends TranslationService {
  FakeTranslationService({
    this.configured = true,
    this.key = 'fake',
    this.translation = 'ceviri',
  });

  final bool configured;
  final String key;
  final String translation;

  @override
  bool get isConfigured => configured;

  @override
  String get providerKey => key;

  @override
  Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    return '$translation:$text';
  }
}

class FakeWordRepository implements WordRepository {
  FakeWordRepository({
    Map<String, WordItem>? globalWords,
    Map<String, WordItem>? packWords,
    List<WordItem>? globalIndex,
  })  : _globalWords = globalWords ?? <String, WordItem>{},
        _packWords = packWords ?? <String, WordItem>{},
        _globalIndex = globalIndex ?? <WordItem>[];

  final Map<String, WordItem> _globalWords;
  final Map<String, WordItem> _packWords;
  final List<WordItem> _globalIndex;

  String _norm(String value) => value.trim().toLowerCase();
  String _packKey(String packId, String word) =>
      '${_norm(packId)}|${_norm(word)}';

  @override
  Future<List<String>> getDistinctPosValues({
    String? packId,
    String? level,
  }) async {
    return const <String>['prep.', 'phr. v.', 'v.', 'n.', 'adj.', 'adv.'];
  }

  @override
  Future<WordItem?> getWordByEnWord({
    required String packId,
    required String enWord,
  }) async {
    return _packWords[_packKey(packId, enWord)];
  }

  @override
  Future<WordItem?> getWordByEnWordGlobal(String enWord) async {
    return _globalWords[_norm(enWord)];
  }

  @override
  Future<WordItem?> getWordById(String wordId) async {
    for (final WordItem item in _globalIndex) {
      if (item.id == wordId) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<List<WordItem>> getWordsByIds(List<String> wordIds) async {
    final Set<String> ids = wordIds.toSet();
    return _globalIndex.where((WordItem e) => ids.contains(e.id)).toList();
  }

  @override
  Future<PagedResult<WordItem>> getWordsByPack(
    String packId, {
    String? query,
    String? pos,
    String? tag,
    int limit = 50,
    int offset = 0,
  }) async {
    final List<WordItem> all = _packWords.entries
        .where((MapEntry<String, WordItem> entry) {
          return entry.key.startsWith('${_norm(packId)}|');
        })
        .map((MapEntry<String, WordItem> e) => e.value)
        .toList();
    final int end =
        (offset + limit) > all.length ? all.length : (offset + limit);
    if (offset >= all.length) {
      return const PagedResult<WordItem>(
          items: <WordItem>[], hasMore: false, nextOffset: 0);
    }
    return PagedResult<WordItem>(
      items: all.sublist(offset, end),
      hasMore: end < all.length,
      nextOffset: end,
    );
  }

  @override
  Future<List<WordItem>> getSessionBatch(
    String packId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final PagedResult<WordItem> result = await getWordsByPack(
      packId,
      limit: limit,
      offset: offset,
    );
    return result.items;
  }

  @override
  Future<List<WordItem>> getGlobalWordIndex({int limit = 7000}) async {
    if (_globalIndex.length <= limit) {
      return _globalIndex;
    }
    return _globalIndex.take(limit).toList(growable: false);
  }

  @override
  Future<List<WordLevelSummary>> getLevelsWithWordCount() async {
    return const <WordLevelSummary>[];
  }

  @override
  Future<List<TagCount>> getTagsByLevel(
    String level, {
    String? search,
  }) async {
    return const <TagCount>[];
  }

  @override
  Future<PagedResult<WordItem>> getWordsByLevel({
    required String level,
    String? tag,
    String? query,
    String? pos,
    int limit = 50,
    int offset = 0,
  }) async {
    return const PagedResult<WordItem>(
      items: <WordItem>[],
      hasMore: false,
      nextOffset: 0,
    );
  }
}

class FakeDictionaryRepository implements DictionaryRepository {
  FakeDictionaryRepository({
    this.lookupResult = const DictionaryLookupResult(
      entries: <DictionaryEntry>[],
      fallbackTranslatedText: null,
      fromServerCache: false,
      fromDeepL: false,
      error: null,
    ),
    this.localResults = const <DictionaryEntry>[],
  });

  final DictionaryLookupResult lookupResult;
  final List<DictionaryEntry> localResults;

  @override
  Future<DictionaryBootstrapState> ensureBootstrapped({
    bool forceRefresh = false,
  }) async {
    return const DictionaryBootstrapState(
      status: DictionaryBootstrapStatus.ready,
      datasetVersion: 'test',
      batchId: null,
      rowCount: 1,
      downloadedCount: 1,
      lastSeqId: 1,
      updatedAt: null,
    );
  }

  @override
  Future<DictionaryBootstrapState> getBootstrapState() async {
    return const DictionaryBootstrapState(
      status: DictionaryBootstrapStatus.ready,
      datasetVersion: 'test',
      batchId: null,
      rowCount: 1,
      downloadedCount: 1,
      lastSeqId: 1,
      updatedAt: null,
    );
  }

  @override
  Future<List<DictionaryEntry>> searchLocal({
    required String query,
    int limit = 30,
  }) async {
    return localResults.take(limit).toList(growable: false);
  }

  @override
  Future<DictionaryLookupResult> lookup({
    required String query,
    String sourceLang = 'en',
    String targetLang = 'tr',
  }) async {
    return lookupResult;
  }
}

class FakeReadingRepository implements ReadingRepository {
  FakeReadingRepository({
    this.sentences = const <PassageSentence>[],
    this.passageWords = const <WordItem>[],
    this.translationMap = const <String, SentenceTranslation>{},
    UserReadingProgress? progress,
  }) : _progress = progress;

  final List<PassageSentence> sentences;
  final List<WordItem> passageWords;
  final Map<String, SentenceTranslation> translationMap;
  UserReadingProgress? _progress;

  @override
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<List<PassageSentence>> getSentences({
    required String passageId,
  }) async {
    return sentences;
  }

  @override
  Future<SentenceTranslation?> getCachedTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
  }) async {
    return translationMap['$sentenceId|$provider|$targetLang'];
  }

  @override
  Future<void> saveTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
    required String translatedText,
  }) async {}

  @override
  Future<UserReadingProgress?> getUserReadingProgress({
    required String passageId,
  }) async {
    return _progress;
  }

  @override
  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {
    _progress = UserReadingProgress(
      userId: 'test-user',
      passageId: passageId,
      completed: completed,
      lastIdx: lastIdx,
      lastSeenAt: DateTime.now(),
    );
  }

  @override
  Future<Map<String, UserReadingProgress>> getProgressMapForPassages(
    List<String> passageIds,
  ) async {
    final UserReadingProgress? p = _progress;
    if (p == null || !passageIds.contains(p.passageId)) {
      return <String, UserReadingProgress>{};
    }
    return <String, UserReadingProgress>{p.passageId: p};
  }

  @override
  Future<int> getTodayReadSentenceCount() async {
    return 0;
  }

  @override
  Future<ReadingResumeItem?> getLatestIncompleteReading() async {
    return null;
  }

  @override
  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  }) async {
    if (passageWords.length <= limit) {
      return passageWords;
    }
    return passageWords.take(limit).toList(growable: false);
  }
}

