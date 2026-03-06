import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/reading_resume_item.dart';
import '../../domain/entities/sentence_translation.dart';
import '../../domain/entities/user_reading_progress.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/value_objects/paged_result.dart';
import '../local/app_content_local_datasource.dart';
import 'supabase_reading_repository.dart';

class HybridReadingRepository implements ReadingRepository {
  HybridReadingRepository({
    required AppContentLocalDataSource localDataSource,
    required SupabaseReadingRepository remoteDataSource,
  })  : _local = localDataSource,
        _remote = remoteDataSource;

  final AppContentLocalDataSource _local;
  final SupabaseReadingRepository _remote;

  @override
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  }) {
    return _local.getPassagesByPack(
      packId: packId,
      levels: levels,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<PagedResult<ReadingPassage>> getReadingFeed({
    String? category,
    String? level,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _remote.getReadingFeed(
        category: category,
        level: level,
        limit: limit,
        offset: offset,
      );
    } catch (_) {
      final List<ReadingPassage> all = <ReadingPassage>[];
      final List<String> packIds =
          (await _local.getPacksWithWordCount()).map((e) => e.id).toList();
      for (final String packId in packIds) {
        final page = await _local.getPassagesByPack(
          packId: packId,
          levels: null,
          limit: 250,
          offset: 0,
        );
        all.addAll(page.items);
      }

      final String cleanCategory = (category ?? '').trim().toLowerCase();
      final String cleanLevel = (level ?? '').trim().toUpperCase();
      final List<ReadingPassage> filtered = all.where((ReadingPassage item) {
        final bool categoryOk = cleanCategory.isEmpty ||
            (item.category ?? '').trim().toLowerCase() == cleanCategory;
        final bool levelOk = cleanLevel.isEmpty ||
            (item.level ?? '').trim().toUpperCase() == cleanLevel;
        return categoryOk && levelOk;
      }).toList()
        ..sort((ReadingPassage a, ReadingPassage b) {
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

      final int safeOffset = offset < 0 ? 0 : offset;
      final int end = (safeOffset + limit + 1) > filtered.length
          ? filtered.length
          : (safeOffset + limit + 1);
      if (safeOffset >= filtered.length) {
        return const PagedResult<ReadingPassage>(
          items: <ReadingPassage>[],
          hasMore: false,
          nextOffset: 0,
        );
      }

      final List<ReadingPassage> window = filtered.sublist(safeOffset, end);
      final bool hasMore = window.length > limit;
      final List<ReadingPassage> items =
          hasMore ? window.take(limit).toList(growable: false) : window;
      return PagedResult<ReadingPassage>(
        items: items,
        hasMore: hasMore,
        nextOffset: safeOffset + items.length,
      );
    }
  }

  @override
  Future<List<PassageSentence>> getSentences({required String passageId}) {
    return _local.getSentences(passageId: passageId);
  }

  @override
  Future<SentenceTranslation?> getCachedTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
  }) async {
    try {
      return await _remote.getCachedTranslation(
        sentenceId: sentenceId,
        provider: provider,
        targetLang: targetLang,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
    required String translatedText,
  }) {
    return _remote.saveTranslation(
      sentenceId: sentenceId,
      provider: provider,
      targetLang: targetLang,
      translatedText: translatedText,
    );
  }

  @override
  Future<UserReadingProgress?> getUserReadingProgress({
    required String passageId,
  }) async {
    try {
      return await _remote.getUserReadingProgress(passageId: passageId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) {
    return _remote.upsertUserReadingProgress(
      passageId: passageId,
      lastIdx: lastIdx,
      completed: completed,
    );
  }

  @override
  Future<Map<String, UserReadingProgress>> getProgressMapForPassages(
    List<String> passageIds,
  ) async {
    try {
      return await _remote.getProgressMapForPassages(passageIds);
    } catch (_) {
      return const <String, UserReadingProgress>{};
    }
  }

  @override
  Future<int> getTodayReadSentenceCount() async {
    try {
      return await _remote.getTodayReadSentenceCount();
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<ReadingResumeItem?> getLatestIncompleteReading() async {
    try {
      return await _remote.getLatestIncompleteReading();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  }) {
    return _local.getPassageWords(
      passageId: passageId,
      limit: limit,
    );
  }

  @override
  Future<void> toggleBookmark(String passageId) {
    return _remote.toggleBookmark(passageId);
  }

  @override
  Future<void> toggleFavorite(String passageId) {
    return _remote.toggleFavorite(passageId);
  }

  @override
  Future<PagedResult<ReadingPassage>> getBookmarkedPassages({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _remote.getBookmarkedPassages(limit: limit, offset: offset);
    } catch (_) {
      return const PagedResult<ReadingPassage>(
        items: <ReadingPassage>[],
        hasMore: false,
        nextOffset: 0,
      );
    }
  }

  @override
  Future<PagedResult<ReadingPassage>> getFavoritePassages({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      return await _remote.getFavoritePassages(limit: limit, offset: offset);
    } catch (_) {
      return const PagedResult<ReadingPassage>(
        items: <ReadingPassage>[],
        hasMore: false,
        nextOffset: 0,
      );
    }
  }

  @override
  Future<bool> isPassageBookmarked(String passageId) async {
    try {
      return await _remote.isPassageBookmarked(passageId);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isPassageFavorited(String passageId) async {
    try {
      return await _remote.isPassageFavorited(passageId);
    } catch (_) {
      return false;
    }
  }
}
