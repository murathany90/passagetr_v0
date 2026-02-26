class Pack {
  const Pack({
    required this.id,
    required this.name,
    required this.fromLang,
    required this.toLang,
    required this.wordCount,
  });

  final String id;
  final String name;
  final String fromLang;
  final String toLang;
  final int wordCount;

  Pack copyWith({
    String? id,
    String? name,
    String? fromLang,
    String? toLang,
    int? wordCount,
  }) {
    return Pack(
      id: id ?? this.id,
      name: name ?? this.name,
      fromLang: fromLang ?? this.fromLang,
      toLang: toLang ?? this.toLang,
      wordCount: wordCount ?? this.wordCount,
    );
  }
}
