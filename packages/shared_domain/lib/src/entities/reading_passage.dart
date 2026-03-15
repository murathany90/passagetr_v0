class ReadingPassage {
  const ReadingPassage({
    required this.id,
    required this.title,
    required this.level,
    required this.category,
    this.packId,
    this.summary,
    this.questionCount = 0,
    this.coverBucketName,
    this.coverStoragePath,
    this.coverAltText,
    this.coverUrl,
    this.isPro = false,
  });

  final String id;
  final String title;
  final String? level;
  final String? category;
  final String? packId;
  final String? summary;
  final int questionCount;
  final String? coverBucketName;
  final String? coverStoragePath;
  final String? coverAltText;
  final String? coverUrl;
  final bool isPro;

  bool get hasCover =>
      (coverUrl?.trim().isNotEmpty ?? false) ||
      ((coverBucketName?.trim().isNotEmpty ?? false) &&
          (coverStoragePath?.trim().isNotEmpty ?? false));
}
