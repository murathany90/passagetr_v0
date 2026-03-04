import '../entities/passage_sentence.dart';
import '../entities/reading_passage.dart';
import '../entities/reading_resume_item.dart';
import '../entities/sentence_translation.dart';
import '../entities/user_reading_progress.dart';
import '../entities/word_item.dart';
import '../value_objects/paged_result.dart';

abstract class ReadingRepository {
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  });

  Future<List<PassageSentence>> getSentences({
    required String passageId,
  });

  Future<SentenceTranslation?> getCachedTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
  });

  Future<void> saveTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
    required String translatedText,
  });

  Future<UserReadingProgress?> getUserReadingProgress({
    required String passageId,
  });

  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  });

  Future<Map<String, UserReadingProgress>> getProgressMapForPassages(
    List<String> passageIds,
  );

  Future<int> getTodayReadSentenceCount();

  Future<ReadingResumeItem?> getLatestIncompleteReading();

  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  });
}
