class WordFavorite {
  const WordFavorite({
    required this.wordId,
    required this.isFavorite,
    this.favoritedAt,
  });

  const WordFavorite.empty({required this.wordId})
    : isFavorite = false,
      favoritedAt = null;

  final String wordId;
  final bool isFavorite;
  final DateTime? favoritedAt;

  WordFavorite copyWith({
    bool? isFavorite,
    DateTime? favoritedAt,
    bool clearFavoritedAt = false,
  }) {
    return WordFavorite(
      wordId: wordId,
      isFavorite: isFavorite ?? this.isFavorite,
      favoritedAt: clearFavoritedAt ? null : (favoritedAt ?? this.favoritedAt),
    );
  }

  WordFavorite setFavorite(bool value, {DateTime? at}) {
    return copyWith(
      isFavorite: value,
      favoritedAt: value ? (at ?? favoritedAt) : null,
      clearFavoritedAt: !value,
    );
  }
}
