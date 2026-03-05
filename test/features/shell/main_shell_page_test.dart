import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/services/offline_sync_controller.dart';
import 'package:passagetr/data/local/offline_sync_queue_store.dart';
import 'package:passagetr/domain/entities/home_dashboard_data.dart';
import 'package:passagetr/domain/entities/passage_sentence.dart';
import 'package:passagetr/domain/entities/reading_passage.dart';
import 'package:passagetr/domain/entities/reading_resume_item.dart';
import 'package:passagetr/domain/entities/sentence_translation.dart';
import 'package:passagetr/domain/entities/user_reading_progress.dart';
import 'package:passagetr/domain/entities/user_word_progress.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/domain/repositories/progress_repository.dart';
import 'package:passagetr/domain/repositories/reading_repository.dart';
import 'package:passagetr/domain/value_objects/flashcard_answer.dart';
import 'package:passagetr/domain/value_objects/paged_result.dart';
import 'package:passagetr/features/shell/main_shell_page.dart';
import 'package:passagetr/state/auth_providers.dart';
import 'package:passagetr/state/dashboard_providers.dart';
import 'package:passagetr/state/nav_badge_providers.dart';
import 'package:passagetr/state/offline_sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> configureViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('MainShellPage shows 5 tabs without Sozluk tab', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);

    final OfflineSyncController controller = OfflineSyncController(
      queueStore: OfflineSyncQueueStore(),
      readingRemote: _FakeReadingRepository(),
      progressRemote: _FakeProgressRepository(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authBootstrapProvider.overrideWith((Ref ref) async {}),
          weakWordCountProvider.overrideWith((Ref ref) async => 0),
          offlineSyncControllerProvider.overrideWith(
            (Ref ref) => controller,
          ),
          homeDashboardProvider.overrideWith((Ref ref) async {
            return const HomeDashboardData(
              todayWordCount: 0,
              todayReadSentenceCount: 0,
              todaySolvedQuestionText: 'Yakinda',
              quickStart: QuickStartSuggestion(
                type: QuickStartType.randomWords,
                wordIds: <String>['w1'],
              ),
            );
          }),
        ],
        child: const MaterialApp(
          home: MainShellPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Kelime'), findsOneWidget);
    expect(find.text('Okuma'), findsOneWidget);
    expect(find.text('Gramer'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Sozluk'), findsNothing);
  });
}

class _FakeReadingRepository implements ReadingRepository {
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
  Future<List<PassageSentence>> getSentences({required String passageId}) async {
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
    return null;
  }

  @override
  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {}

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
}

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<void> applyFlashcardResult({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {}

  @override
  Future<void> applyTestResult({
    required String wordId,
    required bool isCorrect,
  }) async {}

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
