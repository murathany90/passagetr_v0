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
    test('load hydrates bookmark and favorite state from repository', () async {
      final repository = _FakeReadingEngagementRepository(
        seedEngagements: const <ReadingEngagement>[
          ReadingEngagement(
            passageId: 'reading-silent-ocean',
            isBookmarked: true,
            isFavorite: false,
            bookmarkedAt: null,
          ),
          ReadingEngagement(
            passageId: 'reading-coffee-shops',
            isBookmarked: false,
            isFavorite: true,
            favoritedAt: null,
          ),
        ],
      );
      final controller = StudentReadingEngagementController(
        engagementRepository: repository,
        syncRepository: const _FakeSyncRepository(),
        accessContext: _identifiedAccessContext(),
        isWeb: true,
      );

      await Future<void>.delayed(Duration.zero);

      expect(controller.state['reading-silent-ocean']?.isBookmarked, isTrue);
      expect(controller.state['reading-coffee-shops']?.isFavorite, isTrue);
    });

    test(
      'toggleBookmark updates local state and writes bookmark intent',
      () async {
        final repository = _FakeReadingEngagementRepository(
          seedEngagements: const <ReadingEngagement>[
            ReadingEngagement(
              passageId: 'reading-silent-ocean',
              isBookmarked: true,
              isFavorite: false,
            ),
          ],
        );
        final controller = StudentReadingEngagementController(
          engagementRepository: repository,
          syncRepository: const _FakeSyncRepository(),
          accessContext: _identifiedAccessContext(),
          now: () => DateTime.utc(2026, 3, 9, 12, 0),
          isWeb: true,
        );

        await Future<void>.delayed(Duration.zero);
        await controller.toggleBookmark('reading-silent-ocean');

        expect(controller.state.containsKey('reading-silent-ocean'), isFalse);
        expect(repository.bookmarkWrites.single, (
          'reading-silent-ocean',
          false,
        ));
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

class _FakeReadingEngagementRepository implements ReadingEngagementRepository {
  _FakeReadingEngagementRepository({
    List<ReadingEngagement>? seedEngagements,
    this.bookmarkResult = const AppSuccess<void>(null),
    this.favoriteResult = const AppSuccess<void>(null),
  }) : _seedEngagements = seedEngagements ?? const <ReadingEngagement>[];

  final List<ReadingEngagement> _seedEngagements;
  final AppResult<void> bookmarkResult;
  final AppResult<void> favoriteResult;
  final List<(String, bool)> bookmarkWrites = <(String, bool)>[];
  final List<(String, bool)> favoriteWrites = <(String, bool)>[];

  @override
  Future<List<ReadingEngagement>> fetchAll() async => _seedEngagements;

  @override
  Future<AppResult<void>> setBookmark(
    String passageId,
    bool isBookmarked,
  ) async {
    bookmarkWrites.add((passageId, isBookmarked));
    return bookmarkResult;
  }

  @override
  Future<AppResult<void>> setFavorite(String passageId, bool isFavorite) async {
    favoriteWrites.add((passageId, isFavorite));
    return favoriteResult;
  }
}

class _FakeSyncRepository implements SyncRepository {
  const _FakeSyncRepository();

  @override
  Future<AppResult<void>> syncIfStale(SyncScope scope) async =>
      const AppSuccess<void>(null);

  @override
  Future<AppResult<void>> syncNow(SyncScope scope) async =>
      const AppSuccess<void>(null);
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

AccessContext _identifiedAccessContext() {
  return AccessContext.fromSession(
    AuthSession(
      user: const AuthUser(
        id: 'test-user',
        email: 'test@passagetr.dev',
        isAnonymous: false,
      ),
      claims: const <String, String>{'app_role': 'user', 'plan': 'free'},
    ),
  );
}
