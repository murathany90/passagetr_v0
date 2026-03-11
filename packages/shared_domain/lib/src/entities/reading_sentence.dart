class ReadingSentence {
  const ReadingSentence({
    required this.passageId,
    required this.index,
    required this.englishText,
    this.turkishText,
  });

  final String passageId;
  final int index;
  final String englishText;
  final String? turkishText;
}
