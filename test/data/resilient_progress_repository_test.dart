import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/services/offline_sync_controller.dart';
import 'package:passagetr/data/local/offline_sync_queue_store.dart';
import 'package:passagetr/data/repositories/resilient_progress_repository.dart';
import 'package:passagetr/domain/entities/user_word_progress.dart';
import 'package:passagetr/domain/repositories/progress_repository.dart';
import 'package:passagetr/domain/value_objects/flashcard_answer.dart';

void main() {
  test('queues flashcard result on network error without throwing', () async {
    final FakeProgressRepository base = FakeProgressRepository(
      flashcardError: const SocketException('offline'),
    );
    final FakeOfflineSyncCoordinator sync = FakeOfflineSyncCoordinator();
    final ResilientProgressRepository repository = ResilientProgressRepository(
      baseRepository: base,
      syncCoordinator: sync,
    );

    await repository.applyFlashcardResult(
      wordId: 'w1',
      answer: FlashcardAnswer.known,
    );

    expect(sync.enqueuedFlashcards, hasLength(1));
    expect(sync.enqueuedFlashcards.first.wordId, 'w1');
  });

  test('rethrows non-network progress errors', () async {
    final FakeProgressRepository base = FakeProgressRepository(
      testError: StateError('invalid payload'),
    );
    final FakeOfflineSyncCoordinator sync = FakeOfflineSyncCoordinator();
    final ResilientProgressRepository repository = ResilientProgressRepository(
      baseRepository: base,
      syncCoordinator: sync,
    );

    expect(
      () => repository.applyTestResult(wordId: 'w1', isCorrect: true),
      throwsA(isA<StateError>()),
    );
    expect(sync.enqueuedTests, isEmpty);
  });
}

class FakeProgressRepository implements ProgressRepository {
  FakeProgressRepository({
    this.flashcardError,
    this.testError,
  });

  final Object? flashcardError;
  final Object? testError;

  @override
  Future<void> applyFlashcardResult({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {
    if (flashcardError != null) {
      throw flashcardError!;
    }
  }

  @override
  Future<void> applyTestResult({
    required String wordId,
    required bool isCorrect,
  }) async {
    if (testError != null) {
      throw testError!;
    }
  }

  @override
  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  }) async {
    return const <String, UserWordProgress>{};
  }

  @override
  Future<int> getTodayWordCount() async => 0;

  @override
  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  }) async {
    return const <String>[];
  }
}

class FakeOfflineSyncCoordinator implements OfflineSyncCoordinator {
  final List<FlashcardQueueItem> enqueuedFlashcards = <FlashcardQueueItem>[];
  final List<TestQueueItem> enqueuedTests = <TestQueueItem>[];

  @override
  Future<void> enqueueReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {}

  @override
  Future<void> enqueueWordFlashcard({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {
    enqueuedFlashcards.add(FlashcardQueueItem(wordId: wordId, answer: answer));
  }

  @override
  Future<void> enqueueWordTest({
    required String wordId,
    required bool isCorrect,
  }) async {
    enqueuedTests.add(TestQueueItem(wordId: wordId, isCorrect: isCorrect));
  }

  @override
  Future<void> flushPending({bool silent = true}) async {}

  @override
  Future<Map<String, OfflineReadingProgressEntry>> getQueuedReadingMap(
    List<String> passageIds,
  ) async {
    return const <String, OfflineReadingProgressEntry>{};
  }

  @override
  Future<OfflineReadingProgressEntry?> getQueuedReadingProgress(
    String passageId,
  ) async =>
      null;

  @override
  Future<int> getQueuedReadSentenceCountToday() async => 0;

  @override
  Future<int> getQueuedWordEventCountToday() async => 0;
}

class FlashcardQueueItem {
  const FlashcardQueueItem({
    required this.wordId,
    required this.answer,
  });

  final String wordId;
  final FlashcardAnswer answer;
}

class TestQueueItem {
  const TestQueueItem({
    required this.wordId,
    required this.isCorrect,
  });

  final String wordId;
  final bool isCorrect;
}
