class WordEntry {
  const WordEntry({
    required this.id,
    required this.packId,
    required this.enWord,
    required this.trMeaning,
    required this.pos,
    this.exampleEn = '',
    this.exampleTr,
    this.synonymsRaw,
    this.antonymsRaw,
    this.notes,
  });

  final String id;
  final String packId;
  final String enWord;
  final String trMeaning;
  final String pos;
  final String exampleEn;
  final String? exampleTr;
  final String? synonymsRaw;
  final String? antonymsRaw;
  final String? notes;
}
