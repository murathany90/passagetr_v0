import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/exceptions/app_exceptions.dart';
import '../core/utils/network_error_classifier.dart';
import '../domain/entities/home_dashboard_data.dart';
import '../domain/entities/pack.dart';
import '../domain/entities/reading_resume_item.dart';
import '../domain/entities/word_item.dart';
import '../domain/repositories/pack_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/repositories/reading_repository.dart';
import '../domain/repositories/word_repository.dart';
import 'auth_providers.dart';
import 'pack_providers.dart';
import 'progress_providers.dart';
import 'reading_providers.dart';
import 'word_providers.dart';

final FutureProvider<HomeDashboardData> homeDashboardProvider =
    FutureProvider<HomeDashboardData>((Ref ref) async {
  Future<HomeDashboardData> loadOperation() async {
    final ProgressRepository progressRepository = ref.watch(
      progressRepositoryProvider,
    );
    final ReadingRepository readingRepository =
        ref.watch(readingRepositoryProvider);
    final PackRepository packRepository = ref.watch(packRepositoryProvider);
    final WordRepository wordRepository = ref.watch(wordRepositoryProvider);

    final int todayWordCount = await progressRepository.getTodayWordCount();
    final int todayReadSentenceCount =
        await readingRepository.getTodayReadSentenceCount();

    QuickStartSuggestion quickStart = const QuickStartSuggestion(
      type: QuickStartType.unavailable,
    );

    final ReadingResumeItem? resumeItem =
        await readingRepository.getLatestIncompleteReading();

    if (resumeItem != null) {
      Pack? resumePack;
      final String? packId = resumeItem.passage.packId;
      if (packId != null && packId.isNotEmpty) {
        resumePack = await packRepository.getPackById(packId);
      }
      quickStart = QuickStartSuggestion(
        type: QuickStartType.resumeReading,
        pack: resumePack,
        resumeItem: resumeItem,
      );
    } else {
      final List<Pack> packs = await packRepository.getPacksWithWordCount();
      if (packs.isNotEmpty) {
        final Pack defaultPack = packs.first;
        final List<String> weakIds = await progressRepository.getWeakWordIds(
          packId: defaultPack.id,
          limit: 10,
        );
        if (weakIds.isNotEmpty) {
          quickStart = QuickStartSuggestion(
            type: QuickStartType.weakWords,
            pack: defaultPack,
            wordIds: weakIds.take(10).toList(growable: false),
          );
        } else {
          final List<WordItem> randomPool =
              await wordRepository.getSessionBatch(
            defaultPack.id,
            limit: 50,
          );
          randomPool.shuffle();
          final List<String> randomIds = randomPool
              .take(10)
              .map((WordItem e) => e.id)
              .toList(growable: false);
          if (randomIds.isNotEmpty) {
            quickStart = QuickStartSuggestion(
              type: QuickStartType.randomWords,
              pack: defaultPack,
              wordIds: randomIds,
            );
          }
        }
      }
    }

    return HomeDashboardData(
      todayWordCount: todayWordCount,
      todayReadSentenceCount: todayReadSentenceCount,
      todaySolvedQuestionText: 'Yakında',
      quickStart: quickStart,
    );
  }

  // Offline-safe fallback data
  const HomeDashboardData offlineFallback = HomeDashboardData(
    todayWordCount: 0,
    todayReadSentenceCount: 0,
    todaySolvedQuestionText: 'Çevrimdışı',
    quickStart: QuickStartSuggestion(type: QuickStartType.unavailable),
  );

  try {
    await ref.watch(authBootstrapProvider.future);
  } catch (_) {
    // Auth failed (likely offline) → return offline fallback
    return offlineFallback;
  }

  try {
    return await loadOperation();
  } catch (error) {
    if (error is! AuthMissingException) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        return offlineFallback;
      }
      rethrow;
    }
    try {
      await ref.read(authSessionServiceProvider).ensureAnonymousSession();
      return await loadOperation();
    } catch (_) {
      return offlineFallback;
    }
  }
});
