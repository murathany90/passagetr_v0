class UserReadingProgress {
  const UserReadingProgress({
    required this.userId,
    required this.passageId,
    required this.completed,
    required this.lastIdx,
    required this.lastSeenAt,
  });

  final String userId;
  final String passageId;
  final bool completed;
  final int lastIdx;
  final DateTime? lastSeenAt;
}
