import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

enum WordStudyAnswer { known, unsure, unknown }

extension WordStudyAnswerPayload on WordStudyAnswer {
  String get payloadValue => switch (this) {
    WordStudyAnswer.known => 'known',
    WordStudyAnswer.unsure => 'unsure',
    WordStudyAnswer.unknown => 'unknown',
  };

  int get masteryDelta => switch (this) {
    WordStudyAnswer.known => 12,
    WordStudyAnswer.unsure => 3,
    WordStudyAnswer.unknown => -6,
  };

  int get correctCountDelta => this == WordStudyAnswer.known ? 1 : 0;
  int get wrongCountDelta => this == WordStudyAnswer.unknown ? 1 : 0;
}

class StudentWordProgressController
    extends StateNotifier<AsyncValue<Map<String, WordProgress>>> {
  StudentWordProgressController({
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
    if ((state.valueOrNull ?? const <String, WordProgress>{}).isEmpty) {
      state = const AsyncValue.loading();
    }

    state = await AsyncValue.guard(() async {
      final progress = await _progressRepository.fetchWordProgress();
      final latestState = state.valueOrNull ?? const <String, WordProgress>{};
      return <String, WordProgress>{..._toMap(progress), ...latestState};
    });
  }

  Future<AppResult<void>> recordFlashcardResult({
    required WordEntry word,
    required WordStudyAnswer answer,
  }) async {
    _applyOptimisticWordProgress(word: word, answer: answer);

    // Anonymous users see optimistic UI but data is not persisted
    if (!_accessContext.isAuthenticated || _accessContext.isAnonymous) {
      return const AppSuccess<void>(null);
    }

    return _progressRepository.enqueue(
      OutboxEvent(
        eventId: 'word-${word.id}-${_now().microsecondsSinceEpoch}',
        scope: SyncScope.progress,
        entityType: 'user_word_progress',
        entityId: word.id,
        operation: OutboxOperation.event,
        payloadJson: jsonEncode(<String, dynamic>{
          'word_id': word.id,
          'answer': answer.payloadValue,
          'seen_count_delta': 1,
          'correct_count_delta': answer.correctCountDelta,
          'wrong_count_delta': answer.wrongCountDelta,
          'mastery_delta': answer.masteryDelta,
        }),
      ),
    );
  }

  Future<AppResult<void>> recordMiniTestAnswer({
    required WordEntry word,
    required bool isCorrect,
  }) {
    return recordFlashcardResult(
      word: word,
      answer: isCorrect ? WordStudyAnswer.known : WordStudyAnswer.unknown,
    );
  }

  Future<AppResult<void>> recordTestAttempt({
    required String sourceType,
    required String sourceId,
    required int score,
    required int correctCount,
    required int wrongCount,
    required Map<String, dynamic> payload,
  }) {
    // Anonymous users cannot persist test attempts
    if (!_accessContext.isAuthenticated || _accessContext.isAnonymous) {
      return Future<AppResult<void>>.value(const AppSuccess<void>(null));
    }

    return _progressRepository.enqueue(
      OutboxEvent(
        eventId: 'test-$sourceId-${_now().microsecondsSinceEpoch}',
        scope: SyncScope.progress,
        entityType: 'user_test_attempts',
        entityId: sourceId,
        operation: OutboxOperation.event,
        payloadJson: jsonEncode(<String, dynamic>{
          'source_type': sourceType,
          'source_id': sourceId,
          'score': score,
          'correct_count': correctCount,
          'wrong_count': wrongCount,
          'payload_json': payload,
        }),
      ),
    );
  }

  void _applyOptimisticWordProgress({
    required WordEntry word,
    required WordStudyAnswer answer,
  }) {
    final currentState = state.valueOrNull ?? const <String, WordProgress>{};
    final existing =
        currentState[word.id] ??
        WordProgress(wordId: word.id, mastery: 0, seenCount: 0);

    final nextMastery = (existing.mastery + answer.masteryDelta).clamp(0, 100);
    state = AsyncValue.data(<String, WordProgress>{
      ...currentState,
      word.id: WordProgress(
        wordId: word.id,
        mastery: nextMastery.toInt(),
        seenCount: existing.seenCount + 1,
      ),
    });
  }

  Map<String, WordProgress> _toMap(List<WordProgress> progress) {
    return <String, WordProgress>{
      for (final item in progress) item.wordId: item,
    };
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
