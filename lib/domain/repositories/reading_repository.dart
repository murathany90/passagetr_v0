import '../entities/passage_sentence.dart';
import '../entities/reading_passage.dart';
import '../entities/sentence_translation.dart';
import '../value_objects/paged_result.dart';

abstract class ReadingRepository {
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
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
}
