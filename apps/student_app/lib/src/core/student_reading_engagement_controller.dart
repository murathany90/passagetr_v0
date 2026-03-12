import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class StudentReadingEngagementController
    extends StateNotifier<Map<String, ReadingEngagement>> {
  StudentReadingEngagementController({
    required ReadingEngagementRepository engagementRepository,
    required SyncRepository syncRepository,
    required AccessContext accessContext,
    DateTime Function()? now,
    bool? isWeb,
  }) : _engagementRepository = engagementRepository,
       _syncRepository = syncRepository,
       _accessContext = accessContext,
       _now = now ?? _defaultNow,
       _isWeb = isWeb ?? kIsWeb,
       super(const <String, ReadingEngagement>{}) {
    unawaited(load());
  }

  final ReadingEngagementRepository _engagementRepository;
  final SyncRepository _syncRepository;
  final AccessContext _accessContext;
  final DateTime Function() _now;
  final bool _isWeb;

  ReadingEngagement engagementFor(String readingId) {
    return state[readingId] ?? ReadingEngagement.empty(passageId: readingId);
  }

  Future<void> load() async {
    if (!_accessContext.hasIdentifiedProfile) {
      state = const <String, ReadingEngagement>{};
      return;
    }

    if (!_isWeb) {
      await _syncRepository.syncIfStale(SyncScope.progress);
    }

    final engagements = await _engagementRepository.fetchAll();
    state = _toMap(engagements);
  }

  Future<AppResult<void>> toggleBookmark(String readingId) async {
    if (!_accessContext.hasIdentifiedProfile) {
      return const AppSuccess<void>(null);
    }

    final current = engagementFor(readingId);
    final next = current.setBookmark(!current.isBookmarked, at: _now());
    final previousState = state;
    state = _upsert(state, next);

    final result = await _engagementRepository.setBookmark(
      readingId,
      next.isBookmarked,
    );
    if (result is AppFailure<void>) {
      state = previousState;
    }
    return result;
  }

  Future<AppResult<void>> toggleFavorite(String readingId) async {
    if (!_accessContext.hasIdentifiedProfile) {
      return const AppSuccess<void>(null);
    }

    final current = engagementFor(readingId);
    final next = current.setFavorite(!current.isFavorite, at: _now());
    final previousState = state;
    state = _upsert(state, next);

    final result = await _engagementRepository.setFavorite(
      readingId,
      next.isFavorite,
    );
    if (result is AppFailure<void>) {
      state = previousState;
    }
    return result;
  }

  Map<String, ReadingEngagement> _toMap(List<ReadingEngagement> engagements) {
    return <String, ReadingEngagement>{
      for (final engagement in engagements)
        if (engagement.isBookmarked || engagement.isFavorite)
          engagement.passageId: engagement,
    };
  }

  Map<String, ReadingEngagement> _upsert(
    Map<String, ReadingEngagement> current,
    ReadingEngagement next,
  ) {
    final updated = <String, ReadingEngagement>{...current};
    if (!next.isBookmarked && !next.isFavorite) {
      updated.remove(next.passageId);
    } else {
      updated[next.passageId] = next;
    }
    return updated;
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
