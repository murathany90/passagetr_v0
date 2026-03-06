class WordLevelProgressSummary {
  const WordLevelProgressSummary({
    required this.level,
    required this.wordCount,
    required this.studiedWordCount,
  });

  final String level;
  final int wordCount;
  final int studiedWordCount;

  double get ratio {
    if (wordCount <= 0) {
      return 0;
    }
    final double raw = studiedWordCount / wordCount;
    if (raw < 0) {
      return 0;
    }
    if (raw > 1) {
      return 1;
    }
    return raw;
  }
}
