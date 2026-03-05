import 'dart:async';

import '../../core/services/offline_sync_controller.dart';
import '../../core/utils/network_error_classifier.dart';
import '../../domain/entities/user_word_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/value_objects/flashcard_answer.dart';

class ResilientProgressRepository implements ProgressRepository {
  ResilientProgressRepository({
    required ProgressRepository baseRepository,
    required OfflineSyncCoordinator syncCoordinator,
  })  : _base = baseRepository,
        _sync = syncCoordinator;

  final ProgressRepository _base;
  final OfflineSyncCoordinator _sync;

  @override
  Future<void> applyFlashcardResult({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {
    try {
      await _base.applyFlashcardResult(wordId: wordId, answer: answer);
      unawaited(_sync.flushPending(silent: true));
    } catch (error) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        await _sync.enqueueWordFlashcard(wordId: wordId, answer: answer);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> applyTestResult({
    required String wordId,
    required bool isCorrect,
  }) async {
    try {
      await _base.applyTestResult(wordId: wordId, isCorrect: isCorrect);
      unawaited(_sync.flushPending(silent: true));
    } catch (error) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        await _sync.enqueueWordTest(wordId: wordId, isCorrect: isCorrect);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  }) async {
    try {
      return await _base.getProgressMap(wordIds: wordIds);
    } catch (error) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        return const <String, UserWordProgress>{};
      }
      rethrow;
    }
  }

  @override
  Future<int> getTodayWordCount() async {
    try {
      return await _base.getTodayWordCount();
    } catch (error) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        return _sync.getQueuedWordEventCountToday();
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  }) async {
    try {
      return await _base.getWeakWordIds(packId: packId, limit: limit);
    } catch (error) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        return const <String>[];
      }
      rethrow;
    }
  }
}
