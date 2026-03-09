import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'student_analytics_models.dart';

class StudentAnalyticsService {
  const StudentAnalyticsService({
    required AppConfig config,
    required ProgressRepository progressRepository,
  }) : _config = config,
       _progressRepository = progressRepository;

  final AppConfig _config;
  final ProgressRepository _progressRepository;

  static const int goalTargetScore = 12;

  Future<List<StudentDailyStat>> loadDailyStats({
    required AccessContext accessContext,
    int days = 7,
  }) async {
    final remote = await _loadRemoteDailyStats(
      accessContext: accessContext,
      days: days,
    );
    if (remote.isNotEmpty) {
      return _ensureSevenDayShape(remote, days: days);
    }

    final fallback = await _buildFallbackDailyStats(days: days);
    return _ensureSevenDayShape(fallback, days: days);
  }

  StudentAnalyticsSnapshot buildSnapshot(List<StudentDailyStat> stats) {
    final ordered = stats.toList(growable: false)
      ..sort((a, b) => a.date.compareTo(b.date));
    final today = ordered.isEmpty
        ? StudentDailyStat(
            date: DateTime.now(),
            wordsStudied: 0,
            readingsCompleted: 0,
            grammarCompleted: 0,
            streakCount: 0,
            goalCompleted: false,
          )
        : ordered.last;

    final weeklyWords = ordered.fold<int>(
      0,
      (sum, item) => sum + item.wordsStudied,
    );
    final weeklyReadings = ordered.fold<int>(
      0,
      (sum, item) => sum + item.readingsCompleted,
    );
    final weeklyGrammar = ordered.fold<int>(
      0,
      (sum, item) => sum + item.grammarCompleted,
    );
    final completedGoalDays = ordered
        .where((item) => item.goalCompleted)
        .length;
    final maxScore = ordered
        .map((item) => item.activityScore)
        .fold<int>(1, (maxValue, item) => item > maxValue ? item : maxValue);

    return StudentAnalyticsSnapshot(
      streakDays: today.streakCount,
      goalTarget: goalTargetScore,
      todayGoalScore: today.activityScore,
      todayWords: today.wordsStudied,
      todayReadings: today.readingsCompleted,
      todayGrammar: today.grammarCompleted,
      completedGoalDays: completedGoalDays,
      weeklyWords: weeklyWords,
      weeklyReadings: weeklyReadings,
      weeklyGrammar: weeklyGrammar,
      weeklyTrend: ordered
          .map((item) => (item.activityScore / maxScore).clamp(0, 1).toDouble())
          .toList(growable: false),
    );
  }

  Future<List<StudentDailyStat>> _loadRemoteDailyStats({
    required AccessContext accessContext,
    required int days,
  }) async {
    if (!_config.supabaseEnabled || !accessContext.isAuthenticated) {
      return const <StudentDailyStat>[];
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        return const <StudentDailyStat>[];
      }

      final rows =
          (await Supabase.instance.client.rpc<dynamic>(
                'fetch_user_daily_stats',
                params: <String, dynamic>{'p_days': days},
              ))
              as List<dynamic>;

      return rows
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final date =
                DateTime.tryParse(row['stat_date']?.toString() ?? '') ??
                DateTime.now();
            return StudentDailyStat(
              date: DateTime(date.year, date.month, date.day),
              wordsStudied: _readInt(row['words_studied']),
              readingsCompleted: _readInt(row['readings_completed']),
              grammarCompleted: _readInt(row['grammar_completed']),
              streakCount: _readInt(row['streak_count']),
              goalCompleted: _readBool(row['goal_completed']),
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const <StudentDailyStat>[];
    }
  }

  Future<List<StudentDailyStat>> _buildFallbackDailyStats({
    required int days,
  }) async {
    final wordProgress = await _progressRepository.fetchWordProgress();
    final readingProgress = await _progressRepository.fetchReadingProgress();
    final grammarProgress = await _progressRepository.fetchGrammarProgress();

    final totalWords = wordProgress.fold<int>(
      0,
      (sum, item) => sum + item.seenCount,
    );
    final totalReadings = readingProgress
        .where((item) => item.completed)
        .length;
    final totalGrammar = grammarProgress.where((item) => item.completed).length;

    final today = DateTime.now();
    final preview = <StudentDailyStat>[];
    var runningStreak = 0;

    for (var offset = days - 1; offset >= 0; offset--) {
      final date = DateTime(today.year, today.month, today.day - offset);
      final words = _seededWordsFor(offset, totalWords);
      final readings = _seededReadingsFor(offset, totalReadings);
      final grammar = _seededGrammarFor(offset, totalGrammar);
      final goalCompleted = _computeGoalCompleted(
        wordsStudied: words,
        readingsCompleted: readings,
        grammarCompleted: grammar,
      );
      runningStreak = goalCompleted ? runningStreak + 1 : 0;
      preview.add(
        StudentDailyStat(
          date: date,
          wordsStudied: words,
          readingsCompleted: readings,
          grammarCompleted: grammar,
          streakCount: runningStreak,
          goalCompleted: goalCompleted,
        ),
      );
    }

    return preview;
  }

  List<StudentDailyStat> _ensureSevenDayShape(
    List<StudentDailyStat> stats, {
    required int days,
  }) {
    final today = DateTime.now();
    final indexed = <DateTime, StudentDailyStat>{
      for (final item in stats)
        DateTime(item.date.year, item.date.month, item.date.day): item,
    };
    final resolved = <StudentDailyStat>[];
    var runningStreak = 0;

    for (var offset = days - 1; offset >= 0; offset--) {
      final date = DateTime(today.year, today.month, today.day - offset);
      final existing =
          indexed[DateTime(date.year, date.month, date.day)] ??
          StudentDailyStat(
            date: date,
            wordsStudied: 0,
            readingsCompleted: 0,
            grammarCompleted: 0,
            streakCount: 0,
            goalCompleted: false,
          );
      final goalCompleted = existing.goalCompleted;
      runningStreak = goalCompleted ? runningStreak + 1 : 0;
      resolved.add(
        StudentDailyStat(
          date: existing.date,
          wordsStudied: existing.wordsStudied,
          readingsCompleted: existing.readingsCompleted,
          grammarCompleted: existing.grammarCompleted,
          streakCount: existing.streakCount > 0
              ? existing.streakCount
              : runningStreak,
          goalCompleted: goalCompleted,
        ),
      );
    }

    return resolved;
  }

  bool _computeGoalCompleted({
    required int wordsStudied,
    required int readingsCompleted,
    required int grammarCompleted,
  }) {
    return wordsStudied >= 10 ||
        readingsCompleted >= 1 ||
        grammarCompleted >= 1;
  }

  int _seededWordsFor(int offset, int totalWords) {
    final seeds = <int>[6, 8, 5, 9, 12, 14, 11];
    final boost = totalWords > 0 ? (totalWords / 6).round() : 0;
    return seeds[offset % seeds.length] + boost;
  }

  int _seededReadingsFor(int offset, int totalReadings) {
    if (offset == 0) {
      return totalReadings > 0 ? 1 : 0;
    }
    return offset.isEven ? 0 : (totalReadings > 1 ? 1 : 0);
  }

  int _seededGrammarFor(int offset, int totalGrammar) {
    if (totalGrammar == 0) {
      return 0;
    }
    return offset % 3 == 0 ? 1 : 0;
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }
}
