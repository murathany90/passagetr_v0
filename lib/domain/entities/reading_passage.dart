class ReadingPassage {
  const ReadingPassage({
    required this.id,
    required this.packId,
    required this.packName,
    required this.title,
    required this.level,
    required this.tagsRaw,
    required this.category,
  });

  final String id;
  final String? packId;
  final String? packName;
  final String title;
  final String? level;
  final String? tagsRaw;
  final String? category;
}
