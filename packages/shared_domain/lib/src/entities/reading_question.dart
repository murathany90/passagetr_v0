class ReadingQuestion {
  const ReadingQuestion({
    required this.id,
    required this.passageId,
    required this.sortOrder,
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.explanation,
  });

  final String id;
  final String passageId;
  final int sortOrder;
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String? explanation;
}
