import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

import 'student_access_controller.dart';
import 'student_analytics_models.dart';
import 'student_analytics_service.dart';
import 'student_grammar_progress_controller.dart';
import 'student_reading_engagement_controller.dart';
import 'student_translation_controller.dart';
import 'student_word_progress_controller.dart';

final studentAppConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment(
    appName: 'PASSAGETR Student',
    platformMode: kIsWeb ? PlatformMode.web : PlatformMode.mobile,
  );
});

final studentThemeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.system,
);

final studentAccessProvider =
    StateNotifierProvider<StudentAccessController, AccessContext>(
      (ref) => StudentAccessController(
        authRepository: ref.watch(studentAuthRepositoryProvider),
        initialAccessContext: AccessContext.preview(
          role: AppRole.user,
          plan: EntitlementPlan.free,
          isAnonymous: true,
        ),
      ),
    );

final studentAuthRepositoryProvider = Provider<FoundationAuthRepository>((ref) {
  final repository = FoundationAuthRepository(
    config: ref.watch(studentAppConfigProvider),
    fallbackAccessContext: AccessContext.preview(
      role: AppRole.user,
      plan: EntitlementPlan.free,
      isAnonymous: true,
    ),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final studentSyncRemoteClientProvider = Provider<SyncRemoteClient>((ref) {
  return SupabaseSyncRemoteClient(config: ref.watch(studentAppConfigProvider));
});

final studentSyncConnectivityMonitorProvider =
    Provider<SyncConnectivityMonitor>((ref) {
      final monitor =
          kIsWeb || !ref.watch(studentAppConfigProvider).supabaseEnabled
          ? const PreviewSyncConnectivityMonitor()
          : PlatformSyncConnectivityMonitor();
      ref.onDispose(() => monitor.dispose());
      return monitor;
    });

final studentAppDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final studentBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(studentAccessProvider.notifier).restoreSession();
  if (kIsWeb) {
    return;
  }

  final syncRepository = ref.read(studentSyncRepositoryProvider);
  await syncRepository.syncIfStale(SyncScope.content);
  await syncRepository.syncIfStale(SyncScope.progress);
});

final studentPackRepositoryProvider = Provider<PackRepository>(
  (ref) => FoundationPackRepository(
    database: kIsWeb ? null : ref.watch(studentAppDatabaseProvider),
    config: ref.watch(studentAppConfigProvider),
  ),
);

final studentReadingRepositoryProvider = Provider<ReadingRepository>(
  (ref) => FoundationReadingRepository(
    database: kIsWeb ? null : ref.watch(studentAppDatabaseProvider),
    config: ref.watch(studentAppConfigProvider),
  ),
);

final studentGrammarRepositoryProvider = Provider<GrammarRepository>(
  (ref) => FoundationGrammarRepository(
    database: kIsWeb ? null : ref.watch(studentAppDatabaseProvider),
    config: ref.watch(studentAppConfigProvider),
  ),
);

final studentWordRepositoryProvider = Provider<WordRepository>(
  (ref) => FoundationWordRepository(
    database: kIsWeb ? null : ref.watch(studentAppDatabaseProvider),
    config: ref.watch(studentAppConfigProvider),
  ),
);

final studentSyncRepositoryProvider = Provider<SyncRepository>(
  (ref) => kIsWeb || !ref.watch(studentAppConfigProvider).supabaseEnabled
      ? const FoundationSyncRepository.preview()
      : FoundationSyncRepository(
          database: ref.watch(studentAppDatabaseProvider),
          remoteClient: ref.watch(studentSyncRemoteClientProvider),
        ),
);

final studentProgressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => kIsWeb || !ref.watch(studentAppConfigProvider).supabaseEnabled
      ? const FoundationProgressRepository.preview()
      : FoundationProgressRepository(
          database: ref.watch(studentAppDatabaseProvider),
        ),
);

final studentWordProgressProvider =
    StateNotifierProvider<
      StudentWordProgressController,
      AsyncValue<Map<String, WordProgress>>
    >(
      (ref) => StudentWordProgressController(
        progressRepository: ref.watch(studentProgressRepositoryProvider),
        accessContext: ref.watch(studentAccessProvider),
      ),
    );

final studentGrammarProgressProvider =
    StateNotifierProvider<
      StudentGrammarProgressController,
      AsyncValue<Map<int, GrammarProgress>>
    >(
      (ref) => StudentGrammarProgressController(
        progressRepository: ref.watch(studentProgressRepositoryProvider),
      ),
    );

final studentReadingEngagementProvider =
    StateNotifierProvider<
      StudentReadingEngagementController,
      Map<String, ReadingEngagementState>
    >(
      (ref) => StudentReadingEngagementController(
        progressRepository: ref.watch(studentProgressRepositoryProvider),
      ),
    );

final studentTranslationProvider =
    StateNotifierProvider<StudentTranslationController, Map<String, String>>((
      ref,
    ) {
      return StudentTranslationController();
    });

final studentReadingProgressProvider =
    FutureProvider<Map<String, ReadingProgress>>((ref) async {
      final items = await ref
          .watch(studentProgressRepositoryProvider)
          .fetchReadingProgress();
      return <String, ReadingProgress>{
        for (final item in items) item.passageId: item,
      };
    });

final studentPacksProvider = FutureProvider<List<ContentPack>>((ref) {
  return ref.watch(studentPackRepositoryProvider).fetchPacks();
});

final studentReadingsProvider = FutureProvider<List<ReadingPassage>>((ref) {
  return ref.watch(studentReadingRepositoryProvider).fetchReadings();
});

final studentGrammarModulesProvider = FutureProvider<List<GrammarModule>>((
  ref,
) {
  return ref.watch(studentGrammarRepositoryProvider).fetchModules();
});

final studentWordsProvider = FutureProvider<List<WordEntry>>((ref) {
  return ref.watch(studentWordRepositoryProvider).fetchWords();
});

final studentAnalyticsServiceProvider = Provider<StudentAnalyticsService>(
  (ref) => StudentAnalyticsService(
    config: ref.watch(studentAppConfigProvider),
    progressRepository: ref.watch(studentProgressRepositoryProvider),
  ),
);

final studentDailyStatsProvider = FutureProvider<List<StudentDailyStat>>((ref) {
  return ref
      .watch(studentAnalyticsServiceProvider)
      .loadDailyStats(accessContext: ref.watch(studentAccessProvider));
});

final studentAnalyticsSnapshotProvider =
    FutureProvider<StudentAnalyticsSnapshot>((ref) async {
      final stats = await ref.watch(studentDailyStatsProvider.future);
      return ref.watch(studentAnalyticsServiceProvider).buildSnapshot(stats);
    });

final studentStreakDaysProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(data: (snapshot) => snapshot.streakDays, orElse: () => 7);
});

final studentReviewWordCountProvider = Provider<int>((ref) {
  final progress = ref.watch(studentWordProgressProvider).valueOrNull;
  if (progress == null || progress.isEmpty) {
    return 12;
  }

  return progress.values.where((item) => item.mastery < 60).length;
});

final studentContinueReadingIdProvider = Provider<String?>((ref) {
  final readings = ref.watch(studentReadingsProvider).valueOrNull;
  final progress = ref.watch(studentReadingProgressProvider).valueOrNull;
  if (readings == null || readings.isEmpty) {
    return null;
  }

  if (progress != null && progress.isNotEmpty) {
    for (final reading in readings) {
      final p = progress[reading.id];
      if (p != null && !p.completed) {
        return reading.id;
      }
    }
  }

  return readings.first.id;
});

final studentContinueProgressProvider = Provider<int>((ref) {
  final readingId = ref.watch(studentContinueReadingIdProvider);
  if (readingId == null) {
    return 0;
  }

  final progress = ref.watch(studentReadingProgressProvider).valueOrNull;
  final current = progress?[readingId];
  if (current == null) {
    return 0;
  }

  final percent = (current.lastIndex * 4).clamp(0, 100);
  return current.completed ? 100 : percent;
});

final studentTodayWordCountProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(data: (snapshot) => snapshot.todayWords, orElse: () => 0);
});

final studentTodaySentenceCountProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(
        data: (snapshot) =>
            snapshot.todayReadings + (snapshot.todayGrammar * 2),
        orElse: () => 0,
      );
});

final studentWeeklyTrendProvider = Provider<List<double>>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(
        data: (snapshot) => snapshot.weeklyTrend,
        orElse: () => const <double>[0.32, 0.26, 0.51, 0.43, 0.59, 0.82, 0.71],
      );
});

final studentGoalProgressProvider = Provider<double>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(
        data: (snapshot) => snapshot.todayGoalProgress,
        orElse: () => 0.58,
      );
});

final studentCompletedGoalDaysProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(
        data: (snapshot) => snapshot.completedGoalDays,
        orElse: () => 4,
      );
});

const _fallbackPackProgress = <String, int>{};

final studentPackProgressProvider = Provider<Map<String, int>>((ref) {
  final words = ref.watch(studentWordsProvider).valueOrNull;
  final progress = ref.watch(studentWordProgressProvider).valueOrNull;
  if (words == null || progress == null || progress.isEmpty) {
    return _fallbackPackProgress;
  }

  final groupedMasteries = <String, List<int>>{};
  for (final word in words) {
    groupedMasteries.putIfAbsent(word.packId, () => <int>[]);
    groupedMasteries[word.packId]!.add(progress[word.id]?.mastery ?? 0);
  }

  final resolved = <String, int>{};
  for (final entry in groupedMasteries.entries) {
    if (entry.value.isEmpty) {
      continue;
    }
    final total = entry.value.fold<int>(0, (sum, item) => sum + item);
    resolved[entry.key] = (total / entry.value.length).round();
  }

  return resolved;
});
