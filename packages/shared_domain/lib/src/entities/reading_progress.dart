class ReadingProgress {
  const ReadingProgress({
    required this.passageId,
    required this.completed,
    required this.lastIndex,
  });

  final String passageId;
  final bool completed;
  final int lastIndex;
}
