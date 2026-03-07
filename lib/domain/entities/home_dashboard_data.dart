import 'pack.dart';
import 'reading_resume_item.dart';

enum QuickStartType {
  resumeReading,
  weakWords,
  randomWords,
  unavailable,
}

class QuickStartSuggestion {
  const QuickStartSuggestion({
    required this.type,
    this.pack,
    this.resumeItem,
    this.wordIds = const <String>[],
  });

  final QuickStartType type;
  final Pack? pack;
  final ReadingResumeItem? resumeItem;
  final List<String> wordIds;

  bool get isAvailable => type != QuickStartType.unavailable;
}

class HomeDashboardData {
  const HomeDashboardData({
    required this.todayWordCount,
    required this.todayReadSentenceCount,
    required this.todaySolvedQuestionText,
    required this.quickStart,
  });

  final int todayWordCount;
  final int todayReadSentenceCount;
  final String todaySolvedQuestionText;
  final QuickStartSuggestion quickStart;
}

class HomeMetricsData {
  const HomeMetricsData({
    required this.todayWordCount,
    required this.todayReadSentenceCount,
    required this.todaySolvedQuestionText,
  });

  final int todayWordCount;
  final int todayReadSentenceCount;
  final String todaySolvedQuestionText;
}
