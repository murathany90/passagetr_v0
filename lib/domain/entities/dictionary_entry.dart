class DictionaryEntry {
  const DictionaryEntry({
    required this.id,
    required this.seqId,
    required this.enWord,
    required this.enWordNormalized,
    required this.searchKey,
    required this.pos,
    required this.trMeaning,
    required this.source,
    required this.updatedAt,
  });

  final String id;
  final int seqId;
  final String enWord;
  final String enWordNormalized;
  final String searchKey;
  final String? pos;
  final String trMeaning;
  final String source;
  final DateTime? updatedAt;
}
