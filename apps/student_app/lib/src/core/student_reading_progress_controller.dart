import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class StudentReadingProgressController
    extends StateNotifier<AsyncValue<Map<String, ReadingProgress>>> {
  StudentReadingProgressController({
    required ProgressRepository progressRepository,
    required AccessContext accessContext,
    DateTime Function()? now,
  }) : _progressRepository = progressRepository,
       _accessContext = accessContext,
       _now = now ?? _defaultNow,
       super(const AsyncValue.loading()) {
    load();
  }

  final ProgressRepository _progressRepository;
  final AccessContext _accessContext;
  final DateTime Function() _now;

  Future<void> load() async {
    if ((state.valueOrNull ?? const <String, ReadingProgress>{}).isEmpty) {
      state = const AsyncValue.loading();
    }

    state = await AsyncValue.guard(() async {
      final progressList = await _progressRepository.fetchReadingProgress();
      final latestState =
          state.valueOrNull ?? const <String, ReadingProgress>{};

      final Map<String, ReadingProgress> nextMap = {
        for (final item in progressList) item.passageId: item,
      };

      return <String, ReadingProgress>{...nextMap, ...latestState};
    });
  }

  Future<AppResult<void>> recordReadingProgress({
    required String readingId,
    required int sentenceIndex,
    bool completed = false,
  }) async {
    final currentState = state.valueOrNull ?? const <String, ReadingProgress>{};
    final existing = currentState[readingId];

    // Yalnizca ileriye donuk ilerlemeyi veya tamamlama durumunu kaydet
    if (existing != null) {
      if (completed && existing.completed) return const AppSuccess(null);
      if (!completed && existing.lastIndex >= sentenceIndex)
        return const AppSuccess(null);
    }

    final nextProgress = ReadingProgress(
      passageId: readingId,
      completed: completed,
      lastIndex: sentenceIndex,
    );

    // Optimistik guncelleme
    state = AsyncValue.data(<String, ReadingProgress>{
      ...currentState,
      readingId: nextProgress,
    });

    if (!_accessContext.isAuthenticated || _accessContext.isAnonymous) {
      return const AppSuccess<void>(null);
    }

    return _progressRepository.enqueue(
      OutboxEvent(
        eventId: 'reading-$readingId-${_now().microsecondsSinceEpoch}',
        scope: SyncScope.progress,
        entityType: 'user_reading_progress',
        entityId: readingId,
        operation: OutboxOperation.event,
        payloadJson: jsonEncode(<String, dynamic>{
          'passage_id': readingId,
          'completed': completed,
          'last_idx': sentenceIndex,
        }),
      ),
    );
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
