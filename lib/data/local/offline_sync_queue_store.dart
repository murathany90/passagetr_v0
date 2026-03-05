import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/value_objects/flashcard_answer.dart';

class OfflineReadingProgressEntry {
  const OfflineReadingProgressEntry({
    required this.passageId,
    required this.lastIdx,
    required this.completed,
    required this.updatedAtMillis,
  });

  final String passageId;
  final int lastIdx;
  final bool completed;
  final int updatedAtMillis;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'passageId': passageId,
      'lastIdx': lastIdx,
      'completed': completed,
      'updatedAtMillis': updatedAtMillis,
    };
  }

  static OfflineReadingProgressEntry fromJson(
    Map<String, dynamic> json,
  ) {
    return OfflineReadingProgressEntry(
      passageId: (json['passageId'] as String? ?? '').trim(),
      lastIdx: json['lastIdx'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
      updatedAtMillis: json['updatedAtMillis'] as int? ?? 0,
    );
  }
}

enum OfflineWordEventType {
  flashcard,
  test,
}

class OfflineWordProgressEvent {
  const OfflineWordProgressEvent({
    required this.id,
    required this.type,
    required this.wordId,
    required this.answer,
    required this.isCorrect,
    required this.createdAtMillis,
  });

  final String id;
  final OfflineWordEventType type;
  final String wordId;
  final FlashcardAnswer? answer;
  final bool? isCorrect;
  final int createdAtMillis;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type.name,
      'wordId': wordId,
      'answer': answer?.value,
      'isCorrect': isCorrect,
      'createdAtMillis': createdAtMillis,
    };
  }

  static OfflineWordProgressEvent fromJson(Map<String, dynamic> json) {
    final String rawType = (json['type'] as String? ?? 'flashcard').trim();
    final OfflineWordEventType type = OfflineWordEventType.values.firstWhere(
      (OfflineWordEventType e) => e.name == rawType,
      orElse: () => OfflineWordEventType.flashcard,
    );

    final String? rawAnswer = (json['answer'] as String?)?.trim();
    FlashcardAnswer? answer;
    if (rawAnswer != null && rawAnswer.isNotEmpty) {
      answer = FlashcardAnswer.values.firstWhere(
        (FlashcardAnswer e) => e.value == rawAnswer,
        orElse: () => FlashcardAnswer.unsure,
      );
    }

    return OfflineWordProgressEvent(
      id: (json['id'] as String? ?? '').trim(),
      type: type,
      wordId: (json['wordId'] as String? ?? '').trim(),
      answer: answer,
      isCorrect: json['isCorrect'] as bool?,
      createdAtMillis: json['createdAtMillis'] as int? ?? 0,
    );
  }
}

class OfflineSyncSnapshot {
  const OfflineSyncSnapshot({
    required this.readingByPassage,
    required this.wordEvents,
    required this.lastFlushAtMillis,
    required this.droppedCount,
  });

  final Map<String, OfflineReadingProgressEntry> readingByPassage;
  final List<OfflineWordProgressEvent> wordEvents;
  final int? lastFlushAtMillis;
  final int droppedCount;

  int get pendingReadingCount => readingByPassage.length;
  int get pendingWordEventCount => wordEvents.length;
  int get pendingTotal => pendingReadingCount + pendingWordEventCount;
}

class OfflineSyncQueueStore {
  static const String _readingKey = 'offline_sync_reading_v1';
  static const String _wordEventsKey = 'offline_sync_word_events_v1';
  static const String _lastFlushAtKey = 'offline_sync_last_flush_at_v1';
  static const String _droppedCountKey = 'offline_sync_dropped_count_v1';
  static const int maxWordEvents = 2000;

  Future<void> _writeLock = Future<void>.value();

  Future<T> _runLocked<T>(Future<T> Function() operation) {
    final Future<T> next = _writeLock.then((_) => operation());
    _writeLock = next.then((_) {}, onError: (_, __) {});
    return next;
  }

  Future<OfflineSyncSnapshot> loadSnapshot() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, OfflineReadingProgressEntry> readingMap =
        _readReadingMap(prefs.getString(_readingKey));
    final List<OfflineWordProgressEvent> wordEvents =
        _readWordEvents(prefs.getString(_wordEventsKey));
    final int? lastFlushAtMillis = prefs.getInt(_lastFlushAtKey);
    final int droppedCount = prefs.getInt(_droppedCountKey) ?? 0;
    return OfflineSyncSnapshot(
      readingByPassage: readingMap,
      wordEvents: wordEvents,
      lastFlushAtMillis: lastFlushAtMillis,
      droppedCount: droppedCount,
    );
  }

  Future<void> upsertReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
    int? nowMillis,
  }) {
    return _runLocked(() async {
      final String key = passageId.trim();
      if (key.isEmpty) {
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, OfflineReadingProgressEntry> readingMap =
          _readReadingMap(prefs.getString(_readingKey));
      final OfflineReadingProgressEntry? current = readingMap[key];
      final int mergedLastIdx = current == null
          ? lastIdx
          : (lastIdx > current.lastIdx ? lastIdx : current.lastIdx);
      final bool mergedCompleted =
          (current?.completed ?? false) || completed;

      readingMap[key] = OfflineReadingProgressEntry(
        passageId: key,
        lastIdx: mergedLastIdx < 0 ? 0 : mergedLastIdx,
        completed: mergedCompleted,
        updatedAtMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setString(
        _readingKey,
        jsonEncode(
          readingMap.map(
            (String k, OfflineReadingProgressEntry v) => MapEntry(k, v.toJson()),
          ),
        ),
      );
    });
  }

  Future<void> removeReadingProgress(String passageId) {
    return _runLocked(() async {
      final String key = passageId.trim();
      if (key.isEmpty) {
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, OfflineReadingProgressEntry> readingMap =
          _readReadingMap(prefs.getString(_readingKey));
      readingMap.remove(key);
      await prefs.setString(
        _readingKey,
        jsonEncode(
          readingMap.map(
            (String k, OfflineReadingProgressEntry v) => MapEntry(k, v.toJson()),
          ),
        ),
      );
    });
  }

  Future<void> enqueueFlashcardEvent({
    required String wordId,
    required FlashcardAnswer answer,
    int? nowMillis,
  }) {
    return _enqueueWordEvent(
      OfflineWordProgressEvent(
        id: _nextEventId(nowMillis),
        type: OfflineWordEventType.flashcard,
        wordId: wordId.trim(),
        answer: answer,
        isCorrect: null,
        createdAtMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> enqueueTestEvent({
    required String wordId,
    required bool isCorrect,
    int? nowMillis,
  }) {
    return _enqueueWordEvent(
      OfflineWordProgressEvent(
        id: _nextEventId(nowMillis),
        type: OfflineWordEventType.test,
        wordId: wordId.trim(),
        answer: null,
        isCorrect: isCorrect,
        createdAtMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _enqueueWordEvent(OfflineWordProgressEvent event) {
    return _runLocked(() async {
      if (event.wordId.isEmpty) {
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<OfflineWordProgressEvent> events =
          _readWordEvents(prefs.getString(_wordEventsKey));
      events.add(event);

      int dropped = prefs.getInt(_droppedCountKey) ?? 0;
      if (events.length > maxWordEvents) {
        final int removeCount = events.length - maxWordEvents;
        events.removeRange(0, removeCount);
        dropped += removeCount;
      }

      await prefs.setString(
        _wordEventsKey,
        jsonEncode(
          events
              .map((OfflineWordProgressEvent e) => e.toJson())
              .toList(growable: false),
        ),
      );
      await prefs.setInt(_droppedCountKey, dropped);
    });
  }

  Future<void> removeWordEventById(String eventId) {
    return _runLocked(() async {
      final String normalized = eventId.trim();
      if (normalized.isEmpty) {
        return;
      }
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<OfflineWordProgressEvent> events =
          _readWordEvents(prefs.getString(_wordEventsKey));
      events.removeWhere((OfflineWordProgressEvent e) => e.id == normalized);
      await prefs.setString(
        _wordEventsKey,
        jsonEncode(
          events
              .map((OfflineWordProgressEvent e) => e.toJson())
              .toList(growable: false),
        ),
      );
    });
  }

  Future<void> setLastFlushNow([int? nowMillis]) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _lastFlushAtKey,
      nowMillis ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<int> getQueuedWordEventCountToday() async {
    final OfflineSyncSnapshot snapshot = await loadSnapshot();
    final DateTime now = DateTime.now();
    final DateTime dayStart = DateTime(now.year, now.month, now.day);
    final int dayStartMillis = dayStart.millisecondsSinceEpoch;
    return snapshot.wordEvents
        .where((OfflineWordProgressEvent e) => e.createdAtMillis >= dayStartMillis)
        .length;
  }

  Future<int> getQueuedReadSentenceCountToday() async {
    final OfflineSyncSnapshot snapshot = await loadSnapshot();
    final DateTime now = DateTime.now();
    final DateTime dayStart = DateTime(now.year, now.month, now.day);
    final int dayStartMillis = dayStart.millisecondsSinceEpoch;
    int total = 0;
    for (final OfflineReadingProgressEntry entry
        in snapshot.readingByPassage.values) {
      if (entry.updatedAtMillis >= dayStartMillis) {
        total += entry.lastIdx < 0 ? 0 : entry.lastIdx;
      }
    }
    return total;
  }

  Future<void> clearAll() {
    return _runLocked(() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_readingKey);
      await prefs.remove(_wordEventsKey);
      await prefs.remove(_lastFlushAtKey);
      await prefs.remove(_droppedCountKey);
    });
  }

  Map<String, OfflineReadingProgressEntry> _readReadingMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <String, OfflineReadingProgressEntry>{};
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, OfflineReadingProgressEntry>{};
      }
      final Map<String, OfflineReadingProgressEntry> out =
          <String, OfflineReadingProgressEntry>{};
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        if (entry.value is! Map<String, dynamic>) {
          continue;
        }
        final OfflineReadingProgressEntry data =
            OfflineReadingProgressEntry.fromJson(entry.value as Map<String, dynamic>);
        if (data.passageId.isNotEmpty) {
          out[data.passageId] = data;
        }
      }
      return out;
    } catch (_) {
      return <String, OfflineReadingProgressEntry>{};
    }
  }

  List<OfflineWordProgressEvent> _readWordEvents(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return <OfflineWordProgressEvent>[];
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <OfflineWordProgressEvent>[];
      }
      final List<OfflineWordProgressEvent> out = <OfflineWordProgressEvent>[];
      for (final dynamic item in decoded) {
        if (item is Map<String, dynamic>) {
          final OfflineWordProgressEvent event =
              OfflineWordProgressEvent.fromJson(item);
          if (event.id.isNotEmpty && event.wordId.isNotEmpty) {
            out.add(event);
          }
        }
      }
      out.sort((OfflineWordProgressEvent a, OfflineWordProgressEvent b) {
        return a.createdAtMillis.compareTo(b.createdAtMillis);
      });
      return out;
    } catch (_) {
      return <OfflineWordProgressEvent>[];
    }
  }

  String _nextEventId(int? nowMillis) {
    final int now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    return '$now-${DateTime.now().microsecondsSinceEpoch}';
  }
}

