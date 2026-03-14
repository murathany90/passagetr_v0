class ReadingPassage {
  const ReadingPassage({
    required this.id,
    required this.title,
    required this.level,
    required this.category,
    this.packId,
    this.summary,
    this.isPro = false,
  });

  final String id;
  final String title;
  final String? level;
  final String? category;
  final String? packId;
  final String? summary;
  final bool isPro;
}
