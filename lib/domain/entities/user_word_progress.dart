class UserWordProgress {
  const UserWordProgress({
    required this.userId,
    required this.wordId,
    required this.mastery,
    required this.seenCount,
    required this.correctCount,
    required this.wrongCount,
    required this.lastSeenAt,
    required this.lastAnswer,
  });

  final String userId;
  final String wordId;
  final int mastery;
  final int seenCount;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastSeenAt;
  final String? lastAnswer;
}
