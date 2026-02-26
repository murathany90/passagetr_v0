class WordItem {
  const WordItem({
    required this.id,
    required this.packId,
    required this.enWord,
    required this.trMeaning,
    required this.pos,
    required this.exampleEn,
    required this.exampleTr,
    required this.synonymsRaw,
    required this.antonymsRaw,
    required this.level,
    required this.tagsRaw,
    required this.notes,
  });

  final String id;
  final String? packId;
  final String enWord;
  final String trMeaning;
  final String pos;
  final String exampleEn;
  final String? exampleTr;
  final String? synonymsRaw;
  final String? antonymsRaw;
  final String? level;
  final String? tagsRaw;
  final String? notes;
}
