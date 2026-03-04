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
}
