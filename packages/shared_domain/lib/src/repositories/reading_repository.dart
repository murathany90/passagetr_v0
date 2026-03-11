import '../entities/reading_passage.dart';
import '../entities/reading_sentence.dart';

abstract interface class ReadingRepository {
  Future<List<ReadingPassage>> fetchReadings();
  Future<List<ReadingSentence>> fetchReadingSections(String passageId);
  Future<String?> fetchSentenceTranslation(String passageId, int idx);
}
