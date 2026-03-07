import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions/app_exceptions.dart';
import '../core/utils/network_error_classifier.dart';
import '../core/utils/provider_cache.dart';
import '../domain/entities/home_dashboard_data.dart';
import '../domain/entities/pack.dart';
import '../domain/entities/reading_resume_item.dart';
import '../domain/entities/word_item.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/repositories/reading_repository.dart';
import '../domain/repositories/word_repository.dart';
import 'auth_providers.dart';
import 'content_providers.dart';
import 'pack_providers.dart';
import 'progress_providers.dart';
import 'reading_providers.dart';
import 'word_providers.dart';

const HomeMetricsData _offlineMetricsFallback = HomeMetricsData(
  todayWordCount: 0,
  todayReadSentenceCount: 0,
  todaySolvedQuestionText: 'Cevrimdisi',
);

final AutoDisposeFutureProvider<HomeMetricsData> homeMetricsProvider =
    FutureProvider.autoDispose<HomeMetricsData>((Ref ref) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(seconds: 45));
  }

  Future<HomeMetricsData> loadOperation() async {
    final ProgressRepository progressRepository = ref.watch(
      progressRepositoryProvider,
    );
    final ReadingRepository readingRepository =
        ref.watch(readingRepositoryProvider);

    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      progressRepository.getTodayWordCount(),
      readingRepository.getTodayReadSentenceCount(),
    ]);

    return HomeMetricsData(
      todayWordCount: results[0] as int,
      todayReadSentenceCount: results[1] as int,
      todaySolvedQuestionText: 'Yakinda',
    );
  }

  try {
    await ref.watch(authBootstrapProvider.future);
  } catch (_) {
    return _offlineMetricsFallback;
  }

  try {
    return await loadOperation();
  } catch (error) {
    if (error is! AuthMissingException) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        return _offlineMetricsFallback;
      }
      rethrow;
    }
    try {
      await ref.read(authSessionServiceProvider).ensureAnonymousSession();
      return await loadOperation();
    } catch (_) {
      return _offlineMetricsFallback;
    }
  }
});

final AutoDisposeFutureProvider<QuickStartSuggestion> homeQuickStartProvider =
    FutureProvider.autoDispose<QuickStartSuggestion>((Ref ref) async {
  if (ref.watch(isWebPlatformProvider)) {
    ref.cacheFor(const Duration(seconds: 45));
  }

  try {
    await ref.watch(authBootstrapProvider.future);
  } catch (_) {
    return const QuickStartSuggestion(type: QuickStartType.unavailable);
  }

  final ReadingRepository readingRepository =
      ref.watch(readingRepositoryProvider);
  final ProgressRepository progressRepository = ref.watch(
    progressRepositoryProvider,
  );
  final WordRepository wordRepository = ref.watch(wordRepositoryProvider);

  try {
    final Future<ReadingResumeItem?> resumeFuture =
        readingRepository.getLatestIncompleteReading();
    final Future<List<Pack>> packsFuture = ref.watch(packListProvider.future);

    final ReadingResumeItem? resumeItem = await resumeFuture;
    final List<Pack> packs = await packsFuture;

    if (resumeItem != null) {
      final Pack? resumePack = packs.cast<Pack?>().firstWhere(
            (Pack? item) => item?.id == resumeItem.passage.packId,
            orElse: () => null,
          );
      return QuickStartSuggestion(
        type: QuickStartType.resumeReading,
        pack: resumePack,
        resumeItem: resumeItem,
      );
    }

    if (packs.isEmpty) {
      return const QuickStartSuggestion(type: QuickStartType.unavailable);
    }

    final Pack defaultPack = packs.first;
    final List<String> weakIds = await progressRepository.getWeakWordIds(
      packId: defaultPack.id,
      limit: 10,
    );
    if (weakIds.isNotEmpty) {
      return QuickStartSuggestion(
        type: QuickStartType.weakWords,
        pack: defaultPack,
        wordIds: weakIds.take(10).toList(growable: false),
      );
    }

    final List<WordItem> randomPool = await wordRepository.getSessionBatch(
      defaultPack.id,
      limit: 50,
    );
    randomPool.shuffle();
    final List<String> randomIds = randomPool
        .take(10)
        .map((WordItem item) => item.id)
        .toList(growable: false);
    if (randomIds.isNotEmpty) {
      return QuickStartSuggestion(
        type: QuickStartType.randomWords,
        pack: defaultPack,
        wordIds: randomIds,
      );
    }
  } catch (error) {
    if (!NetworkErrorClassifier.isNetworkLikeError(error) &&
        !NetworkErrorClassifier.isAuthTransientError(error) &&
        error is! AuthMissingException) {
      rethrow;
    }
  }

  return const QuickStartSuggestion(type: QuickStartType.unavailable);
});

final AutoDisposeFutureProvider<HomeDashboardData> homeDashboardProvider =
    FutureProvider.autoDispose<HomeDashboardData>((Ref ref) async {
  final List<Object> results = await Future.wait<Object>(<Future<Object>>[
    ref.watch(homeMetricsProvider.future),
    ref.watch(homeQuickStartProvider.future),
  ]);
  final HomeMetricsData metrics = results[0] as HomeMetricsData;
  final QuickStartSuggestion quickStart = results[1] as QuickStartSuggestion;
  return HomeDashboardData(
    todayWordCount: metrics.todayWordCount,
    todayReadSentenceCount: metrics.todayReadSentenceCount,
    todaySolvedQuestionText: metrics.todaySolvedQuestionText,
    quickStart: quickStart,
  );
});
