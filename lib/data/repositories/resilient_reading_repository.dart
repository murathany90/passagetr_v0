import 'dart:async';

import '../../core/services/offline_sync_controller.dart';
import '../../core/utils/network_error_classifier.dart';
import '../local/offline_sync_queue_store.dart';
import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/reading_resume_item.dart';
import '../../domain/entities/sentence_translation.dart';
import '../../domain/entities/user_reading_progress.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/value_objects/paged_result.dart';

class ResilientReadingRepository implements ReadingRepository {
  ResilientReadingRepository({
    required ReadingRepository baseRepository,
    required OfflineSyncCoordinator syncCoordinator,
  })  : _base = baseRepository,
        _sync = syncCoordinator;

  final ReadingRepository _base;
  final OfflineSyncCoordinator _sync;

  @override
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  }) {
    return _base.getPassagesByPack(
      packId: packId,
      levels: levels,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<PassageSentence>> getSentences({required String passageId}) {
    return _base.getSentences(passageId: passageId);
  }

  @override
  Future<SentenceTranslation?> getCachedTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
  }) {
    return _base.getCachedTranslation(
      sentenceId: sentenceId,
      provider: provider,
      targetLang: targetLang,
    );
  }

  @override
  Future<void> saveTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
    required String translatedText,
  }) {
    return _base.saveTranslation(
      sentenceId: sentenceId,
      provider: provider,
      targetLang: targetLang,
      translatedText: translatedText,
    );
  }

  @override
  Future<UserReadingProgress?> getUserReadingProgress({
    required String passageId,
  }) async {
    final OfflineReadingProgressEntry? queued =
        await _sync.getQueuedReadingProgress(passageId);

    try {
      final UserReadingProgress? remote =
          await _base.getUserReadingProgress(passageId: passageId);
      if (queued == null) {
        return remote;
      }
      final UserReadingProgress local = _toProgress(queued);
      if (remote == null) {
        return local;
      }
      return _mergeProgress(remote, local);
    } catch (error) {
      if (queued != null &&
          (NetworkErrorClassifier.isNetworkLikeError(error) ||
              NetworkErrorClassifier.isAuthTransientError(error))) {
        return _toProgress(queued);
      }
      rethrow;
    }
  }

  @override
  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {
    try {
      await _base.upsertUserReadingProgress(
        passageId: passageId,
        lastIdx: lastIdx,
        completed: completed,
      );
      unawaited(_sync.flushPending(silent: true));
    } catch (error) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        await _sync.enqueueReadingProgress(
          passageId: passageId,
          lastIdx: lastIdx,
          completed: completed,
        );
        return;
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, UserReadingProgress>> getProgressMapForPassages(
    List<String> passageIds,
  ) async {
    Map<String, UserReadingProgress> remote = <String, UserReadingProgress>{};
    try {
      remote = await _base.getProgressMapForPassages(passageIds);
    } catch (_) {
      remote = <String, UserReadingProgress>{};
    }

    final Map<String, OfflineReadingProgressEntry> queued =
        await _sync.getQueuedReadingMap(passageIds);
    if (queued.isEmpty) {
      return remote;
    }

    final Map<String, UserReadingProgress> merged =
        <String, UserReadingProgress>{...remote};
    for (final MapEntry<String, OfflineReadingProgressEntry> entry
        in queued.entries) {
      final UserReadingProgress local = _toProgress(entry.value);
      final UserReadingProgress? remoteValue = merged[entry.key];
      merged[entry.key] =
          remoteValue == null ? local : _mergeProgress(remoteValue, local);
    }
    return merged;
  }

  @override
  Future<int> getTodayReadSentenceCount() async {
    final int queued = await _sync.getQueuedReadSentenceCountToday();
    try {
      final int remote = await _base.getTodayReadSentenceCount();
      return remote > queued ? remote : queued;
    } catch (error) {
      if (NetworkErrorClassifier.isNetworkLikeError(error) ||
          NetworkErrorClassifier.isAuthTransientError(error)) {
        return queued;
      }
      rethrow;
    }
  }

  @override
  Future<ReadingResumeItem?> getLatestIncompleteReading() {
    return _base.getLatestIncompleteReading();
  }

  @override
  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  }) {
    return _base.getPassageWords(
      passageId: passageId,
      limit: limit,
    );
  }

  UserReadingProgress _toProgress(OfflineReadingProgressEntry entry) {
    return UserReadingProgress(
      userId: 'offline',
      passageId: entry.passageId,
      completed: entry.completed,
      lastIdx: entry.lastIdx,
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(entry.updatedAtMillis),
    );
  }

  UserReadingProgress _mergeProgress(
    UserReadingProgress remote,
    UserReadingProgress local,
  ) {
    final int lastIdx =
        local.lastIdx > remote.lastIdx ? local.lastIdx : remote.lastIdx;
    return UserReadingProgress(
      userId: remote.userId,
      passageId: remote.passageId,
      completed: remote.completed || local.completed,
      lastIdx: lastIdx,
      lastSeenAt: local.lastSeenAt ?? remote.lastSeenAt,
    );
  }
}
