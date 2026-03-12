import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/student_grammar_progress_controller.dart';
import 'package:student_app/src/core/student_reading_engagement_controller.dart';
import 'package:student_app/src/core/student_translation_controller.dart';

void main() {
  group('StudentReadingEngagementController', () {
    test(
      'toggleBookmark updates local state and enqueues bookmark event',
      () async {
        final repository = _Phase4FakeProgressRepository();
        final controller = StudentReadingEngagementController(
          progressRepository: repository,
          now: () => DateTime.utc(2026, 3, 9, 12, 0),
        );

        await controller.toggleBookmark('reading-silent-ocean');

        expect(controller.state['reading-silent-ocean']?.isBookmarked, isFalse);
        expect(
          repository.enqueuedEvents.single.entityType,
          'user_reading_bookmarks',
        );
      },
    );
  });

  group('StudentTranslationController', () {
    test('loadTranslation caches section translation', () async {
      final controller = StudentTranslationController(
        readingRepository: const _FakeReadingRepository(),
      );

      final first = await controller.loadTranslation(
        readingId: 'reading-silent-ocean',
        sectionIndex: 0,
      );
      final second = await controller.loadTranslation(
        readingId: 'reading-silent-ocean',
        sectionIndex: 0,
      );

      expect(first, isNotEmpty);
      expect(second, first);
      expect(
        controller.cachedTranslation('reading-silent-ocean', 0),
        equals(first),
      );
    });

    test(
      'loadTranslation returns short fallback when seed is missing',
      () async {
        final controller = StudentTranslationController(
          readingRepository: const _FakeReadingRepository(),
        );

        final result = await controller.loadTranslation(
          readingId: 'missing-reading',
          sectionIndex: 9,
        );

        expect(result, 'Cumle cevirisi bulunamadi.');
      },
    );
  });

  group('StudentGrammarProgressController', () {
    test(
      'recordProgress updates local snapshot and enqueues grammar event',
      () async {
        final repository = _Phase4FakeProgressRepository();
        final controller = StudentGrammarProgressController(
          progressRepository: repository,
          now: () => DateTime.utc(2026, 3, 9, 12, 15),
        );

        await controller.recordProgress(
          moduleId: 2,
          pageId: 109,
          lastPageNo: 9,
          completedPages: 9,
          completed: false,
        );

        expect(controller.state, isA<AsyncData<Map<int, GrammarProgress>>>());
        final state = controller.state as AsyncData<Map<int, GrammarProgress>>;
        expect(state.value[2]?.lastPageNo, 9);
        final payload =
            jsonDecode(repository.enqueuedEvents.single.payloadJson)
                as Map<String, dynamic>;
        expect(payload['module_id'], 2);
        expect(payload['page_id'], 109);
        expect(payload['last_page_no'], 9);
      },
    );
  });
}

class _Phase4FakeProgressRepository implements ProgressRepository {
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
  Future<List<GrammarProgress>> fetchGrammarProgress() async =>
      const <GrammarProgress>[
        GrammarProgress(
          moduleId: 2,
          pageId: 108,
          lastPageNo: 8,
          completedPages: 8,
          completed: false,
        ),
      ];

  @override
  Future<List<WordProgress>> fetchWordProgress() async =>
      const <WordProgress>[];
}

class _FakeReadingRepository implements ReadingRepository {
  const _FakeReadingRepository();

  @override
  Future<List<ReadingPassage>> fetchReadings() async =>
      const <ReadingPassage>[];

  @override
  Future<List<ReadingSentence>> fetchReadingSections(String passageId) async {
    return const <ReadingSentence>[];
  }

  @override
  Future<List<ReadingFocusWord>> fetchFocusWords(String passageId) async {
    return const <ReadingFocusWord>[];
  }

  @override
  Future<String?> fetchSentenceTranslation(String passageId, int idx) async {
    return null;
  }
}
