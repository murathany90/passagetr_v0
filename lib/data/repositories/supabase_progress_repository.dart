import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/single_flight.dart';
import '../../core/utils/timed_memory_cache.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../domain/entities/user_word_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/value_objects/flashcard_answer.dart';

class SupabaseProgressRepository implements ProgressRepository {
  SupabaseProgressRepository(
    this._client, {
    bool? useRpc,
  }) : _useRpc = useRpc ?? AppConfig.useProgressRpc;

  final SupabaseClient _client;
  final bool _useRpc;
  final Map<String, Future<void>> _wordLocks = <String, Future<void>>{};
  final TimedMemoryCache<String, int> _todayWordCountCache =
      TimedMemoryCache<String, int>(ttl: const Duration(seconds: 45));
  final TimedMemoryCache<String, List<String>> _weakWordIdsCache =
      TimedMemoryCache<String, List<String>>(ttl: const Duration(seconds: 45));
  final SingleFlight<String, int> _countFlight = SingleFlight<String, int>();
  final SingleFlight<String, List<String>> _weakIdsFlight =
      SingleFlight<String, List<String>>();

  @override
  Future<void> applyFlashcardResult({
    required String wordId,
    required FlashcardAnswer answer,
  }) {
    return _serializeByWord(
      wordId,
      () async {
        if (_useRpc) {
          await _withRetry<void>(() async {
            await _client.rpc(
              'apply_flashcard_result',
              params: <String, dynamic>{
                'p_word_id': wordId,
                'p_answer': answer.value,
              },
            );
          });
          _clearDerivedCaches();
          return;
        }

        await _withRetry<void>(() async {
          final String userId = _resolveUserId();
          final Map<String, dynamic>? current =
              await _getCurrentProgress(userId: userId, wordId: wordId);

          final int delta = switch (answer) {
            FlashcardAnswer.known => 12,
            FlashcardAnswer.unsure => 4,
            FlashcardAnswer.unknown => -8,
          };

          final int mastery =
              _clamp((current?['mastery'] as int? ?? 0) + delta);
          final int seen = (current?['seen_count'] as int? ?? 0) + 1;
          final int correct = current?['correct_count'] as int? ?? 0;
          final int wrong = current?['wrong_count'] as int? ?? 0;

          await _client.from('user_word_progress').upsert(
            <String, dynamic>{
              'user_id': userId,
              'word_id': wordId,
              'mastery': mastery,
              'seen_count': seen,
              'correct_count': correct,
              'wrong_count': wrong,
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
              'last_answer': answer.value,
            },
            onConflict: 'user_id,word_id',
          );
        });
        _clearDerivedCaches();
      },
    );
  }

  @override
  Future<void> applyTestResult({
    required String wordId,
    required bool isCorrect,
  }) {
    return _serializeByWord(
      wordId,
      () async {
        if (_useRpc) {
          await _withRetry<void>(() async {
            await _client.rpc(
              'apply_test_result',
              params: <String, dynamic>{
                'p_word_id': wordId,
                'p_is_correct': isCorrect,
              },
            );
          });
          _clearDerivedCaches();
          return;
        }

        await _withRetry<void>(() async {
          final String userId = _resolveUserId();
          final Map<String, dynamic>? current =
              await _getCurrentProgress(userId: userId, wordId: wordId);

          final int delta = isCorrect ? 10 : -10;
          final int mastery =
              _clamp((current?['mastery'] as int? ?? 0) + delta);
          final int seen = (current?['seen_count'] as int? ?? 0) + 1;
          final int correct =
              (current?['correct_count'] as int? ?? 0) + (isCorrect ? 1 : 0);
          final int wrong =
              (current?['wrong_count'] as int? ?? 0) + (isCorrect ? 0 : 1);

          await _client.from('user_word_progress').upsert(
            <String, dynamic>{
              'user_id': userId,
              'word_id': wordId,
              'mastery': mastery,
              'seen_count': seen,
              'correct_count': correct,
              'wrong_count': wrong,
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
              'last_answer': isCorrect ? 'known' : 'unknown',
            },
            onConflict: 'user_id,word_id',
          );
        });
        _clearDerivedCaches();
      },
    );
  }

  @override
  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  }) async {
    if (wordIds.isEmpty) {
      return const <String, UserWordProgress>{};
    }

    final String userId = _resolveUserId();
    final List<dynamic> rows = await _client
        .from('user_word_progress')
        .select()
        .eq('user_id', userId)
        .inFilter('word_id', wordIds);

    final Map<String, UserWordProgress> mapped = <String, UserWordProgress>{};
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
      final String wordId = data['word_id'] as String;
      mapped[wordId] = UserWordProgress(
        userId: data['user_id'] as String,
        wordId: wordId,
        mastery: data['mastery'] as int? ?? 0,
        seenCount: data['seen_count'] as int? ?? 0,
        correctCount: data['correct_count'] as int? ?? 0,
        wrongCount: data['wrong_count'] as int? ?? 0,
        lastSeenAt: data['last_seen_at'] == null
            ? null
            : DateTime.tryParse(data['last_seen_at'] as String),
        lastAnswer: data['last_answer'] as String?,
      );
    }
    return mapped;
  }

  @override
  Future<Map<String, int>> getStudiedWordCountByLevel({
    required List<String> levels,
  }) async {
    final List<String> normalizedLevels = levels
        .map((String level) => level.trim().toUpperCase())
        .where((String level) => level.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedLevels.isEmpty) {
      return const <String, int>{};
    }

    try {
      final dynamic response = await _client.rpc(
        'get_studied_word_counts_by_level',
        params: <String, dynamic>{
          'p_levels': normalizedLevels,
        },
      );

      final Map<String, int> counts = <String, int>{};
      for (final dynamic row in (response as List<dynamic>)) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
        final String level =
            (data['level'] as String? ?? '').trim().toUpperCase();
        if (level.isEmpty) {
          continue;
        }
        counts[level] = _asInt(data['studied_word_count']);
      }
      return counts;
    } on PostgrestException catch (error) {
      if (!_isMissingRpc(error)) {
        rethrow;
      }
    }

    return _loadStudiedWordCountByLevelFromRows(normalizedLevels);
  }

  @override
  Future<int> getTodayWordCount() async {
    final String userId = _resolveUserId();
    final String cacheKey = 'today-word:$userId';
    final int? cached = _todayWordCountCache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    return _countFlight.run(cacheKey, () async {
      final int? fresh = _todayWordCountCache.get(cacheKey);
      if (fresh != null) {
        return fresh;
      }

      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);

      final List<dynamic> rows = await _client
          .from('user_word_progress')
          .select('word_id')
          .eq('user_id', userId)
          .gte('last_seen_at', startOfDay.toUtc().toIso8601String());

      final int count = rows.length;
      _todayWordCountCache.put(cacheKey, count);
      return count;
    });
  }

  @override
  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  }) async {
    final String userId = _resolveUserId();
    final String cacheKey = 'weak:$userId:$packId:$limit';
    final List<String>? cached = _weakWordIdsCache.get(cacheKey);
    if (cached != null) {
      return cached;
    }

    return _weakIdsFlight.run(cacheKey, () async {
      final List<String>? fresh = _weakWordIdsCache.get(cacheKey);
      if (fresh != null) {
        return fresh;
      }

      final List<dynamic> weakRows = await _client
          .from('user_word_progress')
          .select('word_id, mastery, wrong_count, words!inner(pack_id)')
          .eq('user_id', userId)
          .eq('words.pack_id', packId)
          .order('mastery', ascending: true)
          .order('wrong_count', ascending: false)
          .limit(limit);

      final List<String> ids = <String>[];
      final Set<String> seen = <String>{};
      for (final dynamic row in weakRows) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
        final String? wordId = data['word_id'] as String?;
        if (wordId != null && seen.add(wordId)) {
          ids.add(wordId);
        }
      }

      if (ids.length < limit) {
        final List<dynamic> fallbackRows = await _client
            .from('words')
            .select('id')
            .eq('pack_id', packId)
            .order('created_at', ascending: true)
            .limit(limit * 3);

        for (final dynamic row in fallbackRows) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
          final String? id = data['id'] as String?;
          if (id != null && seen.add(id)) {
            ids.add(id);
          }
          if (ids.length >= limit) {
            break;
          }
        }
      }

      final List<String> result = ids.take(limit).toList(growable: false);
      _weakWordIdsCache.put(cacheKey, result);
      return result;
    });
  }

  Future<Map<String, dynamic>?> _getCurrentProgress({
    required String userId,
    required String wordId,
  }) async {
    final List<dynamic> rows = await _client
        .from('user_word_progress')
        .select()
        .eq('user_id', userId)
        .eq('word_id', wordId)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return Map<String, dynamic>.from(rows.first as Map);
  }

  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    const List<int> backoffMillis = <int>[300, 900, 1800];
    Object? lastError;
    for (int i = 0; i < backoffMillis.length; i++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        if (i < backoffMillis.length - 1) {
          await Future<void>.delayed(Duration(milliseconds: backoffMillis[i]));
        }
      }
    }
    throw lastError ?? Exception('Bilinmeyen progress hatasi');
  }

  Future<void> _serializeByWord(
    String wordId,
    Future<void> Function() operation,
  ) {
    final Future<void> previous = _wordLocks[wordId] ?? Future<void>.value();
    final Future<void> safePrevious = previous.catchError((Object _) {});
    final Future<void> current = safePrevious.then((_) => operation());

    _wordLocks[wordId] = current;
    return current.whenComplete(() {
      if (identical(_wordLocks[wordId], current)) {
        _wordLocks.remove(wordId);
      }
    });
  }

  String _resolveUserId() {
    final String? authUserId = _client.auth.currentUser?.id;
    if (authUserId != null && authUserId.isNotEmpty) {
      return authUserId;
    }

    if (kDebugMode &&
        AppConfig.allowDemoFallback &&
        AppConfig.demoUserUuid.isNotEmpty) {
      return AppConfig.demoUserUuid;
    }

    throw const AuthMissingException(
      'Auth session yok. Progress yazimi auth olmadan baslatilamaz.',
    );
  }

  int _clamp(int value) {
    if (value < 0) {
      return 0;
    }
    if (value > 100) {
      return 100;
    }
    return value;
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<Map<String, int>> _loadStudiedWordCountByLevelFromRows(
    List<String> normalizedLevels,
  ) async {
    final String userId = _resolveUserId();
    final Set<String> levelFilter = normalizedLevels.toSet();
    final List<dynamic> rows = await _client
        .from('user_word_progress')
        .select('seen_count, words!inner(level)')
        .eq('user_id', userId)
        .gt('seen_count', 0);

    final Map<String, int> counts = <String, int>{};
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
      final Map<String, dynamic> word = Map<String, dynamic>.from(
        data['words'] as Map? ?? const <String, dynamic>{},
      );
      final String level =
          (word['level'] as String? ?? '').trim().toUpperCase();
      if (level.isEmpty || !levelFilter.contains(level)) {
        continue;
      }
      counts[level] = (counts[level] ?? 0) + 1;
    }
    return counts;
  }

  bool _isMissingRpc(PostgrestException error) {
    final String code = error.code?.trim() ?? '';
    final String message = error.message.toLowerCase();
    return code == 'PGRST202' ||
        message.contains('could not find the function') ||
        message.contains('get_studied_word_counts_by_level');
  }

  void _clearDerivedCaches() {
    _todayWordCountCache.clear();
    _weakWordIdsCache.clear();
  }
}
