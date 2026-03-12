class StudentDailyStat {
  const StudentDailyStat({
    required this.date,
    required this.wordsStudied,
    required this.readingsCompleted,
    required this.grammarCompleted,
    required this.streakCount,
    required this.goalCompleted,
  });

  final DateTime date;
  final int wordsStudied;
  final int readingsCompleted;
  final int grammarCompleted;
  final int streakCount;
  final bool goalCompleted;

  int get activityScore =>
      wordsStudied + (readingsCompleted * 12) + (grammarCompleted * 10);
}

enum StudentAnalyticsSource { remote, estimated }

class StudentAnalyticsLoadResult {
  const StudentAnalyticsLoadResult({
    required this.stats,
    required this.source,
    this.fallbackReason,
  });

  final List<StudentDailyStat> stats;
  final StudentAnalyticsSource source;
  final String? fallbackReason;
}

class StudentAnalyticsSnapshot {
  const StudentAnalyticsSnapshot({
    required this.streakDays,
    required this.goalTarget,
    required this.todayGoalScore,
    required this.todayWords,
    required this.todayReadings,
    required this.todayGrammar,
    required this.completedGoalDays,
    required this.weeklyWords,
    required this.weeklyReadings,
    required this.weeklyGrammar,
    required this.weeklyTrend,
    required this.source,
    this.fallbackReason,
  });

  final int streakDays;
  final int goalTarget;
  final int todayGoalScore;
  final int todayWords;
  final int todayReadings;
  final int todayGrammar;
  final int completedGoalDays;
  final int weeklyWords;
  final int weeklyReadings;
  final int weeklyGrammar;
  final List<double> weeklyTrend;
  final StudentAnalyticsSource source;
  final String? fallbackReason;

  bool get isEstimated => source == StudentAnalyticsSource.estimated;

  int get weeklySessions => weeklyReadings + weeklyGrammar;

  double get todayGoalProgress {
    if (goalTarget <= 0) {
      return 0;
    }
    return (todayGoalScore / goalTarget).clamp(0, 1);
  }
}
