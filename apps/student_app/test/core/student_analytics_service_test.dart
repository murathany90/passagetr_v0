import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/student_analytics_service.dart';

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<AppResult<void>> enqueue(OutboxEvent event) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<List<GrammarProgress>> fetchGrammarProgress() async {
    return const <GrammarProgress>[
      GrammarProgress(
        moduleId: 1,
        pageId: 4,
        lastPageNo: 4,
        completedPages: 4,
        completed: true,
      ),
    ];
  }

  @override
  Future<List<ReadingProgress>> fetchReadingProgress() async {
    return const <ReadingProgress>[
      ReadingProgress(
        passageId: 'reading-silent-ocean',
        completed: true,
        lastIndex: 18,
      ),
    ];
  }

  @override
  Future<List<WordProgress>> fetchWordProgress() async {
    return const <WordProgress>[
      WordProgress(wordId: 'word-a', mastery: 40, seenCount: 8),
      WordProgress(wordId: 'word-b', mastery: 70, seenCount: 5),
    ];
  }
}

void main() {
  group('StudentAnalyticsService', () {
    final service = StudentAnalyticsService(
      config: AppConfig.fromEnvironment(
        appName: 'PASSAGETR Test',
        platformMode: PlatformMode.mobile,
      ),
      progressRepository: _FakeProgressRepository(),
    );

    test('loadDailyStats produces seven fallback records', () async {
      final stats = await service.loadDailyStats(
        accessContext: AccessContext.anonymous(),
      );

      expect(stats, hasLength(7));
      expect(stats.last.streakCount, greaterThanOrEqualTo(1));
      expect(stats.last.wordsStudied, greaterThanOrEqualTo(8));
    });

    test('buildSnapshot aggregates weekly totals and trend', () async {
      final stats = await service.loadDailyStats(
        accessContext: AccessContext.anonymous(),
      );
      final snapshot = service.buildSnapshot(stats);

      expect(snapshot.weeklyTrend, hasLength(7));
      expect(snapshot.weeklyWords, greaterThan(0));
      expect(snapshot.todayGoalProgress, greaterThan(0));
      expect(snapshot.streakDays, greaterThanOrEqualTo(1));
    });
  });
}
