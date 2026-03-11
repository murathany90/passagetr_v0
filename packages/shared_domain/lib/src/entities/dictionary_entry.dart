class DictionaryEntry {
  const DictionaryEntry({
    required this.enWord,
    required this.trMeaning,
    this.pos,
  });

  final String enWord;
  final String trMeaning;
  final String? pos;
}
