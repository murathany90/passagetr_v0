import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

import 'student_access_controller.dart';
import 'student_analytics_models.dart';
import 'student_analytics_service.dart';
import 'student_content_refresh_controller.dart';
import 'student_grammar_progress_controller.dart';
import 'student_reading_engagement_controller.dart';
import 'student_reading_progress_controller.dart';
import 'tts/student_tts_controller.dart';
import 'tts/student_tts_engine.dart';
import 'student_translation_controller.dart';
import 'student_word_favorite_controller.dart';
import 'student_word_progress_controller.dart';

final studentAppConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment(
    appName: 'Passagetr',
    platformMode: kIsWeb ? PlatformMode.web : PlatformMode.mobile,
  );
});

final studentThemeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.system,
);

const _studentPlaceholderReading = ReadingPassage(
  id: 'reading-placeholder',
  title: 'Okuma Yüklenemedi',
  level: '-',
  category: '-',
);

@immutable
class StudentWordSummary {
  const StudentWordSummary({
    required this.studiedCount,
    required this.reviewCount,
    required this.totalCount,
  });

  const StudentWordSummary.empty()
    : studiedCount = 0,
      reviewCount = 0,
      totalCount = 0;

  final int studiedCount;
  final int reviewCount;
  final int totalCount;
}

@immutable
class StudentContinueReadingSummary {
  const StudentContinueReadingSummary({
    required this.reading,
    required this.progressPercent,
    required this.ctaLabel,
    required this.isCompleted,
  });

  const StudentContinueReadingSummary.placeholder()
    : reading = _studentPlaceholderReading,
      progressPercent = 0,
      ctaLabel = 'Okuma Kütüphanesini Aç',
      isCompleted = false;

  final ReadingPassage reading;
  final int progressPercent;
  final String ctaLabel;
  final bool isCompleted;

  bool get hasReading => reading.id != _studentPlaceholderReading.id;
}

final studentAccessProvider =
    StateNotifierProvider<StudentAccessController, AccessContext>(
      (ref) => StudentAccessController(
        authRepository: ref.watch(studentAuthRepositoryProvider),
        initialAccessContext: AccessContext.anonymous(),
      ),
    );

final studentAuthRepositoryProvider = Provider<FoundationAuthRepository>((ref) {
  final repository = FoundationAuthRepository(
    config: ref.watch(studentAppConfigProvider),
    fallbackAccessContext: AccessContext.anonymous(),
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
  // Web'de sync repository preview-noop döndürür; DB yazımı olmaz.
  // Yine de aynı akıştan geçirilir — gelecekteki web cache desteğine hazırlık.
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

final studentDictionaryRepositoryProvider = Provider<DictionaryRepository>(
  (ref) => FoundationDictionaryRepository(
    config: ref.watch(studentAppConfigProvider),
  ),
);

final studentTtsEngineProvider = Provider<StudentTtsEngine>((ref) {
  final engine = NativeStudentTtsEngine();
  ref.onDispose(() => engine.dispose());
  return engine;
});

final studentTtsControllerProvider =
    StateNotifierProvider<StudentTtsController, StudentTtsState>(
      (ref) =>
          StudentTtsController(engine: ref.watch(studentTtsEngineProvider)),
    );

final studentIsWordSpeakingProvider = Provider.family<bool, String>((
  ref,
  wordId,
) {
  final state = ref.watch(studentTtsControllerProvider);
  return state.isSpeaking &&
      state.activeTarget == StudentTtsTarget.word &&
      state.activeWordId == wordId;
});

final studentIsSentenceSpeakingProvider =
    Provider.family<bool, ({String readingId, int sentenceIndex})>((
      ref,
      target,
    ) {
      final state = ref.watch(studentTtsControllerProvider);
      return state.isSpeaking &&
          state.activeReadingId == target.readingId &&
          state.activeSentenceIndex == target.sentenceIndex;
    });

final studentIsPassageSpeakingProvider = Provider.family<bool, String>((
  ref,
  readingId,
) {
  final state = ref.watch(studentTtsControllerProvider);
  return state.isSpeaking &&
      state.activeTarget == StudentTtsTarget.passage &&
      state.activeReadingId == readingId;
});

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

final studentReadingEngagementRepositoryProvider =
    Provider<ReadingEngagementRepository>((ref) {
      final config = ref.watch(studentAppConfigProvider);
      final accessContext = ref.watch(studentAccessProvider);
      if (!config.supabaseEnabled) {
        return FoundationReadingEngagementRepository.preview(
          accessContext: accessContext,
        );
      }

      return FoundationReadingEngagementRepository(
        database: kIsWeb ? null : ref.watch(studentAppDatabaseProvider),
        progressRepository: kIsWeb
            ? null
            : ref.watch(studentProgressRepositoryProvider),
        config: config,
        accessContext: accessContext,
      );
    });

final studentWordFavoriteRepositoryProvider = Provider<WordFavoriteRepository>((
  ref,
) {
  final config = ref.watch(studentAppConfigProvider);
  final accessContext = ref.watch(studentAccessProvider);
  if (!config.supabaseEnabled) {
    return FoundationWordFavoriteRepository.preview(
      accessContext: accessContext,
    );
  }

  return FoundationWordFavoriteRepository(
    database: kIsWeb ? null : ref.watch(studentAppDatabaseProvider),
    progressRepository: kIsWeb
        ? null
        : ref.watch(studentProgressRepositoryProvider),
    config: config,
    accessContext: accessContext,
  );
});

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

final studentWordFavoritesProvider =
    StateNotifierProvider<
      StudentWordFavoriteController,
      Map<String, WordFavorite>
    >(
      (ref) => StudentWordFavoriteController(
        favoriteRepository: ref.watch(studentWordFavoriteRepositoryProvider),
        syncRepository: ref.watch(studentSyncRepositoryProvider),
        accessContext: ref.watch(studentAccessProvider),
      ),
    );

final studentWordFavoriteByIdProvider = Provider.family<WordFavorite, String>((
  ref,
  wordId,
) {
  return ref.watch(studentWordFavoritesProvider)[wordId] ??
      WordFavorite.empty(wordId: wordId);
});

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
      Map<String, ReadingEngagement>
    >(
      (ref) => StudentReadingEngagementController(
        engagementRepository: ref.watch(
          studentReadingEngagementRepositoryProvider,
        ),
        syncRepository: ref.watch(studentSyncRepositoryProvider),
        accessContext: ref.watch(studentAccessProvider),
      ),
    );

final studentReadingEngagementByIdProvider =
    Provider.family<ReadingEngagement, String>((ref, readingId) {
      return ref.watch(studentReadingEngagementProvider)[readingId] ??
          ReadingEngagement.empty(passageId: readingId);
    });

final studentTranslationProvider =
    StateNotifierProvider<StudentTranslationController, Map<String, String>>((
      ref,
    ) {
      return StudentTranslationController(
        readingRepository: ref.watch(studentReadingRepositoryProvider),
      );
    });

final studentReadingProgressProvider =
    StateNotifierProvider<
      StudentReadingProgressController,
      AsyncValue<Map<String, ReadingProgress>>
    >(
      (ref) => StudentReadingProgressController(
        progressRepository: ref.watch(studentProgressRepositoryProvider),
        accessContext: ref.watch(studentAccessProvider),
      ),
    );

final studentPacksProvider = FutureProvider<List<ContentPack>>((ref) {
  return ref.watch(studentPackRepositoryProvider).fetchPacks();
});

final studentReadingsProvider = FutureProvider<List<ReadingPassage>>((
  ref,
) async {
  final items = await ref
      .watch(studentReadingRepositoryProvider)
      .fetchReadings();
  final sorted = items.toList(growable: false);
  sorted.sort(_compareReadingPassages);
  return sorted;
});

final studentReadingSectionsProvider =
    FutureProvider.family<List<ReadingSentence>, String>((ref, readingId) {
      return ref
          .watch(studentReadingRepositoryProvider)
          .fetchReadingSections(readingId);
    });

final studentReadingFocusWordsProvider =
    FutureProvider.family<List<ReadingFocusWord>, String>((ref, readingId) {
      return ref
          .watch(studentReadingRepositoryProvider)
          .fetchFocusWords(readingId);
    });

final studentReadingQuestionsProvider =
    FutureProvider.family<List<ReadingQuestion>, String>((ref, readingId) {
      return ref
          .watch(studentReadingRepositoryProvider)
          .fetchQuestions(readingId);
    });

final studentReadingWordCardsProvider =
    FutureProvider.family<Map<String, WordEntry>, String>((
      ref,
      readingId,
    ) async {
      final focusWords = await ref.watch(
        studentReadingFocusWordsProvider(readingId).future,
      );
      final wordIds = focusWords
          .map((item) => item.wordId.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
      if (wordIds.isEmpty) {
        return const <String, WordEntry>{};
      }

      final items = await ref
          .watch(studentWordRepositoryProvider)
          .fetchWordsByIds(wordIds);
      return <String, WordEntry>{for (final item in items) item.id: item};
    });

final _readingNumericPrefixPattern = RegExp(r'^\d+');

int _compareReadingPassages(ReadingPassage left, ReadingPassage right) {
  final leftOrder = _readingTitleOrder(left.title);
  final rightOrder = _readingTitleOrder(right.title);

  final numberComparison = leftOrder.numericPrefix.compareTo(
    rightOrder.numericPrefix,
  );
  if (numberComparison != 0) {
    return numberComparison;
  }

  return leftOrder.normalizedTitle.compareTo(rightOrder.normalizedTitle);
}

_ReadingTitleOrder _readingTitleOrder(String title) {
  final normalizedTitle = title.trim().toLowerCase();
  final match = _readingNumericPrefixPattern.firstMatch(normalizedTitle);
  final numericPrefix = match == null
      ? 1 << 30
      : int.tryParse(match.group(0)!) ?? (1 << 30);

  return _ReadingTitleOrder(
    numericPrefix: numericPrefix,
    normalizedTitle: normalizedTitle,
  );
}

@immutable
class _ReadingTitleOrder {
  const _ReadingTitleOrder({
    required this.numericPrefix,
    required this.normalizedTitle,
  });

  final int numericPrefix;
  final String normalizedTitle;
}

final studentGrammarModulesProvider = FutureProvider<List<GrammarModule>>((
  ref,
) async {
  final items = await ref
      .watch(studentGrammarRepositoryProvider)
      .fetchModules();
  final sorted = items.toList(growable: false);
  sorted.sort((a, b) {
    final orderComparison = a.sortOrder.compareTo(b.sortOrder);
    if (orderComparison != 0) {
      return orderComparison;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
});

final studentGrammarModuleDetailProvider =
    FutureProvider.family<GrammarModuleDetail?, int>((ref, moduleId) {
      return ref
          .watch(studentGrammarRepositoryProvider)
          .fetchModuleDetail(moduleId);
    });

final studentWordsProvider = FutureProvider<List<WordEntry>>((ref) {
  return ref.watch(studentWordRepositoryProvider).fetchWords();
});

void invalidateStudentContentProviders(Ref ref) {
  ref.invalidate(studentPacksProvider);
  ref.invalidate(studentReadingsProvider);
  ref.read(studentReadingProgressProvider.notifier).load();
  ref.invalidate(studentReadingSectionsProvider);
  ref.invalidate(studentReadingFocusWordsProvider);
  ref.invalidate(studentReadingQuestionsProvider);
  ref.invalidate(studentReadingWordCardsProvider);
  ref.invalidate(studentGrammarModulesProvider);
  ref.invalidate(studentGrammarModuleDetailProvider);
  ref.invalidate(studentWordsProvider);
  ref.invalidate(studentWordSummaryProvider);
  ref.invalidate(studentReviewWordCountProvider);
  ref.invalidate(studentContinueReadingSummaryProvider);
  ref.invalidate(studentContinueReadingIdProvider);
  ref.invalidate(studentContinueProgressProvider);
  ref.invalidate(studentPackProgressProvider);
}

final studentContentRefreshControllerProvider =
    StateNotifierProvider<
      StudentContentRefreshController,
      StudentContentRefreshState
    >(
      (ref) => StudentContentRefreshController(
        syncRepository: ref.watch(studentSyncRepositoryProvider),
        invalidateContentProviders: () =>
            invalidateStudentContentProviders(ref),
      ),
    );

final studentDictionaryEntryProvider =
    FutureProvider.family<DictionaryEntry?, String>((ref, query) {
      return ref.watch(studentDictionaryRepositoryProvider).lookupWord(query);
    });

final studentAnalyticsServiceProvider = Provider<StudentAnalyticsService>(
  (ref) => StudentAnalyticsService(
    config: ref.watch(studentAppConfigProvider),
    progressRepository: ref.watch(studentProgressRepositoryProvider),
  ),
);

final studentDailyStatsProvider = FutureProvider<StudentAnalyticsLoadResult>((
  ref,
) {
  return ref
      .watch(studentAnalyticsServiceProvider)
      .loadDailyStats(accessContext: ref.watch(studentAccessProvider));
});

final studentAnalyticsSnapshotProvider =
    FutureProvider<StudentAnalyticsSnapshot>((ref) async {
      final result = await ref.watch(studentDailyStatsProvider.future);
      return ref.watch(studentAnalyticsServiceProvider).buildSnapshot(result);
    });

final studentWordSummaryProvider = Provider<StudentWordSummary>((ref) {
  final words = ref.watch(studentWordsProvider).valueOrNull;
  final progress = ref.watch(studentWordProgressProvider).valueOrNull;
  if ((words == null || words.isEmpty) &&
      (progress == null || progress.isEmpty)) {
    return const StudentWordSummary.empty();
  }

  final visibleWordIds = words == null
      ? progress?.keys.toSet() ?? const <String>{}
      : words.map((item) => item.id).toSet();
  final relevantProgress = progress == null
      ? const <WordProgress>[]
      : progress.entries
            .where((entry) => visibleWordIds.contains(entry.key))
            .map((entry) => entry.value)
            .toList(growable: false);

  return StudentWordSummary(
    studiedCount: relevantProgress.where((item) => item.seenCount > 0).length,
    reviewCount: relevantProgress.where((item) => item.mastery < 60).length,
    totalCount: words?.length ?? visibleWordIds.length,
  );
});

final studentStreakDaysProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(data: (snapshot) => snapshot.streakDays, orElse: () => 0);
});

final studentReviewWordCountProvider = Provider<int>((ref) {
  return ref.watch(studentWordSummaryProvider).reviewCount;
});

final studentContinueReadingSummaryProvider =
    Provider<StudentContinueReadingSummary>((ref) {
      final readings = ref.watch(studentReadingsProvider).valueOrNull;
      if (readings == null || readings.isEmpty) {
        return const StudentContinueReadingSummary.placeholder();
      }

      final progressMap =
          ref.watch(studentReadingProgressProvider).valueOrNull ??
          const <String, ReadingProgress>{};

      ReadingPassage? selectedReading;
      ReadingProgress? selectedProgress;

      for (final reading in readings) {
        final progress = progressMap[reading.id];
        if (hasReadingStarted(progress) && !(progress?.completed ?? false)) {
          selectedReading = reading;
          selectedProgress = progress;
          break;
        }
      }

      selectedReading ??= _selectFirstUnstartedReading(readings, progressMap);
      selectedProgress = progressMap[selectedReading?.id];
      final resolvedReading = selectedReading ?? readings.first;
      selectedProgress ??= progressMap[resolvedReading.id];

      final progressPercent = calculateReadingProgressPercent(selectedProgress);
      final isCompleted = selectedProgress?.completed ?? progressPercent >= 100;
      return StudentContinueReadingSummary(
        reading: resolvedReading,
        progressPercent: progressPercent,
        ctaLabel: isCompleted ? 'Gözden Geçir' : 'Kaldığın Yerden Devam Et',
        isCompleted: isCompleted,
      );
    });

ReadingPassage? _selectFirstUnstartedReading(
  List<ReadingPassage> readings,
  Map<String, ReadingProgress> progressMap,
) {
  for (final reading in readings) {
    final progress = progressMap[reading.id];
    if (progress == null ||
        (!hasReadingStarted(progress) && !progress.completed)) {
      return reading;
    }
  }

  return null;
}

bool hasReadingStarted(ReadingProgress? progress) {
  if (progress == null) {
    return false;
  }

  return progress.completed || calculateReadingProgressPercent(progress) > 0;
}

int calculateReadingProgressPercent(ReadingProgress? progress) {
  if (progress == null) {
    return 0;
  }

  if (progress.completed) {
    return 100;
  }

  return (progress.lastIndex * 4).clamp(0, 100);
}

final studentContinueReadingIdProvider = Provider<String?>((ref) {
  final summary = ref.watch(studentContinueReadingSummaryProvider);
  if (!summary.hasReading) {
    return null;
  }

  return summary.reading.id;
});

final studentContinueProgressProvider = Provider<int>((ref) {
  return ref.watch(studentContinueReadingSummaryProvider).progressPercent;
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

final studentWeeklyWordCountProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(data: (snapshot) => snapshot.weeklyWords, orElse: () => 0);
});

final studentWeeklySessionCountProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(data: (snapshot) => snapshot.weeklySessions, orElse: () => 0);
});

final studentWeeklyTrendProvider = Provider<List<double>>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(
        data: (snapshot) => snapshot.weeklyTrend,
        orElse: () => List<double>.filled(7, 0.0),
      );
});

final studentGoalProgressProvider = Provider<double>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(
        data: (snapshot) => snapshot.todayGoalProgress,
        orElse: () => 0.0,
      );
});

final studentCompletedGoalDaysProvider = Provider<int>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(
        data: (snapshot) => snapshot.completedGoalDays,
        orElse: () => 0,
      );
});

final studentAnalyticsEstimatedProvider = Provider<bool>((ref) {
  return ref
      .watch(studentAnalyticsSnapshotProvider)
      .maybeWhen(data: (snapshot) => snapshot.isEstimated, orElse: () => false);
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

final studentWordOfTheDayProvider = Provider<WordEntry?>((ref) {
  final words = ref.watch(studentWordsProvider).valueOrNull;
  if (words == null || words.isEmpty) {
    return null;
  }

  // Gunluk degisen ama session suresince sabit kalan basit bir seed mantigi.
  // Gercek bir "seen/mastered" filtresi ile daha da iyilestirilebilir.
  final dayOfYear =
      DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
  final index = dayOfYear % words.length;
  return words[index];
});

final studentRecommendedReadingsProvider = Provider<List<ReadingPassage>>((ref) {
  final readings = ref.watch(studentReadingsProvider).valueOrNull ?? const [];
  if (readings.isEmpty) {
    return const [];
  }

  final progressMap =
      ref.watch(studentReadingProgressProvider).valueOrNull ??
      const <String, ReadingProgress>{};

  // Henuz tamamlanmamis olanlari filtrele
  final uncompleted =
      readings.where((r) {
        final p = progressMap[r.id];
        return p == null || !p.completed;
      }).toList();

  if (uncompleted.isEmpty) {
    return readings.take(3).toList();
  }

  // Karisik veya seviyeye gore onerilebilir; simdilik ilk 3 uygun olani aliyoruz
  return uncompleted.take(3).toList();
});
