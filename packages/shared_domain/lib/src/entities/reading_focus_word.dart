class ReadingFocusWord {
  const ReadingFocusWord({
    required this.wordId,
    required this.enWord,
    required this.trMeaning,
    this.pos,
  });

  final String wordId;
  final String enWord;
  final String trMeaning;
  final String? pos;
}
