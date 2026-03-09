import '../entities/reading_passage.dart';

abstract interface class ReadingRepository {
  Future<List<ReadingPassage>> fetchReadings();
}
