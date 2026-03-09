import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/student_word_progress_controller.dart';

void main() {
  group('StudentWordProgressController', () {
    test('loads cached progress from repository', () async {
      final repository = _FakeProgressRepository(
        seedProgress: const <WordProgress>[
          WordProgress(wordId: 'word-a', mastery: 40, seenCount: 5),
        ],
      );

      final controller = StudentWordProgressController(
        progressRepository: repository,
      );

      await Future<void>.delayed(Duration.zero);

      expect(controller.state.valueOrNull?['word-a']?.mastery, 40);

      controller.dispose();
    });

    test(
      'recordFlashcardResult updates local state and enqueues event',
      () async {
        final repository = _FakeProgressRepository();
        final controller = StudentWordProgressController(
          progressRepository: repository,
          now: () => DateTime.utc(2026, 3, 9, 11, 0),
        );

        await controller.recordFlashcardResult(
          word: const WordEntry(
            id: 'word-a',
            packId: 'pack-yds-001',
            enWord: 'allocate',
            trMeaning: 'tahsis etmek',
            pos: 'v.',
          ),
          answer: WordStudyAnswer.known,
        );

        final updated = controller.state.valueOrNull?['word-a'];
        expect(updated?.mastery, 12);
        expect(updated?.seenCount, 1);
        expect(repository.enqueuedEvents, hasLength(1));

        final payload =
            jsonDecode(repository.enqueuedEvents.single.payloadJson)
                as Map<String, dynamic>;
        expect(payload['answer'], 'known');
        expect(payload['mastery_delta'], 12);
        expect(payload['correct_count_delta'], 1);

        controller.dispose();
      },
    );

    test('recordTestAttempt enqueues summary event', () async {
      final repository = _FakeProgressRepository();
      final controller = StudentWordProgressController(
        progressRepository: repository,
        now: () => DateTime.utc(2026, 3, 9, 11, 15),
      );

      final result = await controller.recordTestAttempt(
        sourceType: 'mini_test',
        sourceId: 'attempt-1',
        score: 80,
        correctCount: 4,
        wrongCount: 1,
        payload: const <String, dynamic>{'question_count': 5},
      );

      expect(result, isA<AppSuccess<void>>());
      expect(repository.enqueuedEvents.single.entityType, 'user_test_attempts');
      expect(repository.enqueuedEvents.single.entityId, 'attempt-1');

      controller.dispose();
    });
  });
}

class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository({List<WordProgress>? seedProgress})
    : _seedProgress = seedProgress ?? const <WordProgress>[];

  final List<WordProgress> _seedProgress;
  final List<OutboxEvent> enqueuedEvents = <OutboxEvent>[];

  @override
  Future<AppResult<void>> enqueue(OutboxEvent event) async {
    enqueuedEvents.add(event);
    return const AppSuccess<void>(null);
  }

  @override
  Future<List<ReadingProgress>> fetchReadingProgress() async =>
      const <ReadingProgress>[];

  @override
  Future<List<WordProgress>> fetchWordProgress() async => _seedProgress;

  @override
  Future<List<GrammarProgress>> fetchGrammarProgress() async =>
      const <GrammarProgress>[];
}
