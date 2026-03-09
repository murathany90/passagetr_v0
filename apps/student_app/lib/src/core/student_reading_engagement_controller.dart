import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class ReadingEngagementState {
  const ReadingEngagementState({
    required this.isBookmarked,
    required this.isFavorite,
  });

  final bool isBookmarked;
  final bool isFavorite;

  ReadingEngagementState copyWith({bool? isBookmarked, bool? isFavorite}) {
    return ReadingEngagementState(
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class StudentReadingEngagementController
    extends StateNotifier<Map<String, ReadingEngagementState>> {
  StudentReadingEngagementController({
    required ProgressRepository progressRepository,
    DateTime Function()? now,
  }) : _progressRepository = progressRepository,
       _now = now ?? _defaultNow,
       super(const <String, ReadingEngagementState>{
         'reading-silent-ocean': ReadingEngagementState(
           isBookmarked: true,
           isFavorite: false,
         ),
         'reading-coffee-shops': ReadingEngagementState(
           isBookmarked: false,
           isFavorite: true,
         ),
       });

  final ProgressRepository _progressRepository;
  final DateTime Function() _now;

  ReadingEngagementState stateFor(String readingId) {
    return state[readingId] ??
        const ReadingEngagementState(isBookmarked: false, isFavorite: false);
  }

  Future<AppResult<void>> toggleBookmark(String readingId) async {
    final current = stateFor(readingId);
    final nextValue = !current.isBookmarked;
    state = <String, ReadingEngagementState>{
      ...state,
      readingId: current.copyWith(isBookmarked: nextValue),
    };
    return _progressRepository.enqueue(
      OutboxEvent(
        eventId: 'bookmark-$readingId-${_now().microsecondsSinceEpoch}',
        scope: SyncScope.progress,
        entityType: 'user_reading_bookmarks',
        entityId: readingId,
        operation: OutboxOperation.event,
        payloadJson: jsonEncode(<String, dynamic>{
          'passage_id': readingId,
          'should_bookmark': nextValue,
        }),
      ),
    );
  }

  Future<AppResult<void>> toggleFavorite(String readingId) async {
    final current = stateFor(readingId);
    final nextValue = !current.isFavorite;
    state = <String, ReadingEngagementState>{
      ...state,
      readingId: current.copyWith(isFavorite: nextValue),
    };
    return _progressRepository.enqueue(
      OutboxEvent(
        eventId: 'favorite-$readingId-${_now().microsecondsSinceEpoch}',
        scope: SyncScope.progress,
        entityType: 'user_reading_favorites',
        entityId: readingId,
        operation: OutboxOperation.event,
        payloadJson: jsonEncode(<String, dynamic>{
          'passage_id': readingId,
          'should_favorite': nextValue,
        }),
      ),
    );
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
