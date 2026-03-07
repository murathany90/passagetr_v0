import '../entities/user_word_progress.dart';
import '../value_objects/flashcard_answer.dart';

abstract class ProgressRepository {
  Future<void> applyFlashcardResult({
    required String wordId,
    required FlashcardAnswer answer,
  });

  Future<void> applyTestResult({
    required String wordId,
    required bool isCorrect,
  });

  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  });

  Future<Map<String, int>> getStudiedWordCountByLevel({
    required List<String> levels,
  });

  Future<int> getTodayWordCount();

  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  });
}
