import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/network_error_classifier.dart';
import '../../data/local/offline_sync_queue_store.dart';
import '../../domain/entities/user_reading_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/value_objects/flashcard_answer.dart';

class OfflineSyncStatus {
  const OfflineSyncStatus({
    required this.pendingReadingCount,
    required this.pendingWordEventCount,
    required this.isOfflineLikely,
    required this.isFlushing,
    required this.lastFlushAtMillis,
    required this.droppedCount,
  });

  const OfflineSyncStatus.initial()
      : pendingReadingCount = 0,
        pendingWordEventCount = 0,
        isOfflineLikely = false,
        isFlushing = false,
        lastFlushAtMillis = null,
        droppedCount = 0;

  final int pendingReadingCount;
  final int pendingWordEventCount;
  final bool isOfflineLikely;
  final bool isFlushing;
  final int? lastFlushAtMillis;
  final int droppedCount;

  int get pendingTotal => pendingReadingCount + pendingWordEventCount;

  OfflineSyncStatus copyWith({
    int? pendingReadingCount,
    int? pendingWordEventCount,
    bool? isOfflineLikely,
    bool? isFlushing,
    int? lastFlushAtMillis,
    bool clearLastFlushAtMillis = false,
    int? droppedCount,
  }) {
    return OfflineSyncStatus(
      pendingReadingCount: pendingReadingCount ?? this.pendingReadingCount,
      pendingWordEventCount:
          pendingWordEventCount ?? this.pendingWordEventCount,
      isOfflineLikely: isOfflineLikely ?? this.isOfflineLikely,
      isFlushing: isFlushing ?? this.isFlushing,
      lastFlushAtMillis: clearLastFlushAtMillis
          ? null
          : (lastFlushAtMillis ?? this.lastFlushAtMillis),
      droppedCount: droppedCount ?? this.droppedCount,
    );
  }
}

abstract class OfflineSyncCoordinator {
  Future<void> enqueueReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  });

  Future<void> enqueueWordFlashcard({
    required String wordId,
    required FlashcardAnswer answer,
  });

  Future<void> enqueueWordTest({
    required String wordId,
    required bool isCorrect,
  });

  Future<void> flushPending({bool silent = true, bool force = false});

  Future<OfflineReadingProgressEntry?> getQueuedReadingProgress(
    String passageId,
  );

  Future<Map<String, OfflineReadingProgressEntry>> getQueuedReadingMap(
    List<String> passageIds,
  );

  Future<int> getQueuedReadSentenceCountToday();

  Future<int> getQueuedWordEventCountToday();
}

class OfflineSyncController extends StateNotifier<OfflineSyncStatus>
    implements OfflineSyncCoordinator {
  OfflineSyncController({
    required OfflineSyncQueueStore queueStore,
    required ReadingRepository readingRemote,
    required ProgressRepository progressRemote,
  })  : _queueStore = queueStore,
        _readingRemote = readingRemote,
        _progressRemote = progressRemote,
        super(const OfflineSyncStatus.initial()) {
    refreshStatus();
  }

  final OfflineSyncQueueStore _queueStore;
  final ReadingRepository _readingRemote;
  final ProgressRepository _progressRemote;

  bool _flushInFlight = false;
  int? _lastFlushAttemptMillis;
  static const int _flushDebounceMillis = 10000;

  Future<void> refreshStatus() async {
    final OfflineSyncSnapshot snapshot = await _queueStore.loadSnapshot();
    state = state.copyWith(
      pendingReadingCount: snapshot.pendingReadingCount,
      pendingWordEventCount: snapshot.pendingWordEventCount,
      droppedCount: snapshot.droppedCount,
      lastFlushAtMillis: snapshot.lastFlushAtMillis,
      isOfflineLikely: snapshot.pendingTotal > 0 || state.isOfflineLikely,
    );
  }

  @override
  Future<void> enqueueReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {
    await _queueStore.upsertReadingProgress(
      passageId: passageId,
      lastIdx: lastIdx,
      completed: completed,
    );
    await refreshStatus();
    state = state.copyWith(isOfflineLikely: true);
    unawaited(flushPending(silent: true));
  }

  @override
  Future<void> enqueueWordFlashcard({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {
    await _queueStore.enqueueFlashcardEvent(wordId: wordId, answer: answer);
    await refreshStatus();
    state = state.copyWith(isOfflineLikely: true);
    unawaited(flushPending(silent: true));
  }

  @override
  Future<void> enqueueWordTest({
    required String wordId,
    required bool isCorrect,
  }) async {
    await _queueStore.enqueueTestEvent(wordId: wordId, isCorrect: isCorrect);
    await refreshStatus();
    state = state.copyWith(isOfflineLikely: true);
    unawaited(flushPending(silent: true));
  }

  @override
  Future<void> flushPending({bool silent = true, bool force = false}) async {
    if (_flushInFlight) {
      return;
    }
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        _lastFlushAttemptMillis != null &&
        now - _lastFlushAttemptMillis! < _flushDebounceMillis) {
      return;
    }

    _lastFlushAttemptMillis = now;
    _flushInFlight = true;
    state = state.copyWith(isFlushing: true);

    try {
      OfflineSyncSnapshot snapshot = await _queueStore.loadSnapshot();
      if (snapshot.pendingTotal == 0) {
        state = state.copyWith(
          isFlushing: false,
          isOfflineLikely: false,
        );
        return;
      }

      final List<OfflineReadingProgressEntry> readingEntries =
          snapshot.readingByPassage.values.toList(growable: false)
            ..sort((OfflineReadingProgressEntry a, OfflineReadingProgressEntry b) {
              return a.updatedAtMillis.compareTo(b.updatedAtMillis);
            });

      bool shouldStop = false;
      for (final OfflineReadingProgressEntry entry in readingEntries) {
        try {
          await _readingRemote.upsertUserReadingProgress(
            passageId: entry.passageId,
            lastIdx: entry.lastIdx,
            completed: entry.completed,
          );
          await _queueStore.removeReadingProgress(entry.passageId);
        } catch (error) {
          if (_isRetryable(error)) {
            shouldStop = true;
            break;
          }
          await _queueStore.removeReadingProgress(entry.passageId);
        }
      }

      if (!shouldStop) {
        snapshot = await _queueStore.loadSnapshot();
        final List<OfflineWordProgressEvent> events = snapshot.wordEvents;
        for (final OfflineWordProgressEvent event in events) {
          try {
            if (event.type == OfflineWordEventType.flashcard) {
              if (event.answer == null) {
                await _queueStore.removeWordEventById(event.id);
                continue;
              }
              await _progressRemote.applyFlashcardResult(
                wordId: event.wordId,
                answer: event.answer!,
              );
            } else {
              if (event.isCorrect == null) {
                await _queueStore.removeWordEventById(event.id);
                continue;
              }
              await _progressRemote.applyTestResult(
                wordId: event.wordId,
                isCorrect: event.isCorrect!,
              );
            }
            await _queueStore.removeWordEventById(event.id);
          } catch (error) {
            if (_isRetryable(error)) {
              shouldStop = true;
              break;
            }
            await _queueStore.removeWordEventById(event.id);
          }
        }
      }

      await _queueStore.setLastFlushNow();
      await refreshStatus();
      state = state.copyWith(
        isFlushing: false,
        isOfflineLikely: state.pendingTotal > 0 || shouldStop,
      );
    } catch (error) {
      state = state.copyWith(
        isFlushing: false,
        isOfflineLikely: true,
      );
      if (!silent) {
        rethrow;
      }
    } finally {
      _flushInFlight = false;
    }
  }

  bool _isRetryable(Object error) {
    return NetworkErrorClassifier.isNetworkLikeError(error) ||
        NetworkErrorClassifier.isAuthTransientError(error);
  }

  @override
  Future<OfflineReadingProgressEntry?> getQueuedReadingProgress(
    String passageId,
  ) async {
    final String key = passageId.trim();
    if (key.isEmpty) {
      return null;
    }
    final OfflineSyncSnapshot snapshot = await _queueStore.loadSnapshot();
    return snapshot.readingByPassage[key];
  }

  @override
  Future<Map<String, OfflineReadingProgressEntry>> getQueuedReadingMap(
    List<String> passageIds,
  ) async {
    final OfflineSyncSnapshot snapshot = await _queueStore.loadSnapshot();
    if (passageIds.isEmpty) {
      return snapshot.readingByPassage;
    }
    final Set<String> filter = passageIds.map((String e) => e.trim()).toSet();
    final Map<String, OfflineReadingProgressEntry> mapped =
        <String, OfflineReadingProgressEntry>{};
    for (final MapEntry<String, OfflineReadingProgressEntry> entry
        in snapshot.readingByPassage.entries) {
      if (filter.contains(entry.key)) {
        mapped[entry.key] = entry.value;
      }
    }
    return mapped;
  }

  @override
  Future<int> getQueuedReadSentenceCountToday() {
    return _queueStore.getQueuedReadSentenceCountToday();
  }

  @override
  Future<int> getQueuedWordEventCountToday() {
    return _queueStore.getQueuedWordEventCountToday();
  }

  UserReadingProgress queuedEntryToProgress(OfflineReadingProgressEntry entry) {
    return UserReadingProgress(
      userId: 'offline',
      passageId: entry.passageId,
      completed: entry.completed,
      lastIdx: entry.lastIdx,
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(entry.updatedAtMillis),
    );
  }
}
