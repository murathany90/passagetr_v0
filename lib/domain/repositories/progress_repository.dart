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
}
