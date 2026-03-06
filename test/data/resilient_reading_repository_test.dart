import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/services/offline_sync_controller.dart';
import 'package:passagetr/data/local/offline_sync_queue_store.dart';
import 'package:passagetr/data/repositories/resilient_reading_repository.dart';
import 'package:passagetr/domain/entities/passage_sentence.dart';
import 'package:passagetr/domain/entities/reading_passage.dart';
import 'package:passagetr/domain/entities/reading_resume_item.dart';
import 'package:passagetr/domain/entities/sentence_translation.dart';
import 'package:passagetr/domain/entities/user_reading_progress.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/domain/repositories/reading_repository.dart';
import 'package:passagetr/domain/value_objects/flashcard_answer.dart';
import 'package:passagetr/domain/value_objects/paged_result.dart';

void main() {
  test('queues reading progress on network error and does not throw', () async {
    final FakeReadingRepository base = FakeReadingRepository(
      upsertError: const SocketException('offline'),
    );
    final FakeOfflineSyncCoordinator sync = FakeOfflineSyncCoordinator();
    final ResilientReadingRepository repository = ResilientReadingRepository(
      baseRepository: base,
      syncCoordinator: sync,
    );

    await repository.upsertUserReadingProgress(
      passageId: 'p1',
      lastIdx: 3,
      completed: false,
    );

    expect(sync.enqueuedReading, hasLength(1));
    expect(sync.enqueuedReading.first.passageId, 'p1');
  });

  test('merges queued reading progress over remote value', () async {
    final FakeReadingRepository base = FakeReadingRepository(
      progress: const UserReadingProgress(
        userId: 'u1',
        passageId: 'p1',
        completed: false,
        lastIdx: 2,
        lastSeenAt: null,
      ),
    );
    final FakeOfflineSyncCoordinator sync = FakeOfflineSyncCoordinator(
      queuedProgress: const OfflineReadingProgressEntry(
        passageId: 'p1',
        lastIdx: 4,
        completed: true,
        updatedAtMillis: 100,
      ),
    );
    final ResilientReadingRepository repository = ResilientReadingRepository(
      baseRepository: base,
      syncCoordinator: sync,
    );

    final UserReadingProgress? merged =
        await repository.getUserReadingProgress(passageId: 'p1');

    expect(merged, isNotNull);
    expect(merged!.lastIdx, 4);
    expect(merged.completed, isTrue);
  });
}

class FakeReadingRepository implements ReadingRepository {
  FakeReadingRepository({
    this.upsertError,
    this.progress,
  });

  final Object? upsertError;
  final UserReadingProgress? progress;

  @override
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<PagedResult<ReadingPassage>> getReadingFeed({
    String? category,
    String? level,
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<List<PassageSentence>> getSentences(
      {required String passageId}) async {
    return const <PassageSentence>[];
  }

  @override
  Future<SentenceTranslation?> getCachedTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
  }) async {
    return null;
  }

  @override
  Future<void> saveTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
    required String translatedText,
  }) async {}

  @override
  Future<UserReadingProgress?> getUserReadingProgress({
    required String passageId,
  }) async {
    return progress;
  }

  @override
  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {
    if (upsertError != null) {
      throw upsertError!;
    }
  }

  @override
  Future<Map<String, UserReadingProgress>> getProgressMapForPassages(
    List<String> passageIds,
  ) async {
    return const <String, UserReadingProgress>{};
  }

  @override
  Future<int> getTodayReadSentenceCount() async => 0;

  @override
  Future<ReadingResumeItem?> getLatestIncompleteReading() async => null;

  @override
  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  }) async {
    return const <WordItem>[];
  }

  @override
  Future<void> toggleBookmark(String passageId) async {}

  @override
  Future<void> toggleFavorite(String passageId) async {}

  @override
  Future<PagedResult<ReadingPassage>> getBookmarkedPassages({
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<PagedResult<ReadingPassage>> getFavoritePassages({
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<bool> isPassageBookmarked(String passageId) async => false;

  @override
  Future<bool> isPassageFavorited(String passageId) async => false;
}

class FakeOfflineSyncCoordinator implements OfflineSyncCoordinator {
  FakeOfflineSyncCoordinator({
    this.queuedProgress,
  });

  final OfflineReadingProgressEntry? queuedProgress;
  final List<OfflineReadingProgressEntry> enqueuedReading =
      <OfflineReadingProgressEntry>[];

  @override
  Future<void> enqueueReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {
    enqueuedReading.add(
      OfflineReadingProgressEntry(
        passageId: passageId,
        lastIdx: lastIdx,
        completed: completed,
        updatedAtMillis: 1,
      ),
    );
  }

  @override
  Future<void> enqueueWordFlashcard({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {}

  @override
  Future<void> enqueueWordTest({
    required String wordId,
    required bool isCorrect,
  }) async {}

  @override
  Future<void> flushPending({
    bool silent = true,
    bool force = false,
  }) async {}

  @override
  Future<Map<String, OfflineReadingProgressEntry>> getQueuedReadingMap(
    List<String> passageIds,
  ) async {
    if (queuedProgress == null) {
      return const <String, OfflineReadingProgressEntry>{};
    }
    return <String, OfflineReadingProgressEntry>{
      queuedProgress!.passageId: queuedProgress!,
    };
  }

  @override
  Future<OfflineReadingProgressEntry?> getQueuedReadingProgress(
    String passageId,
  ) async {
    return queuedProgress;
  }

  @override
  Future<int> getQueuedReadSentenceCountToday() async => 0;

  @override
  Future<int> getQueuedWordEventCountToday() async => 0;
}
