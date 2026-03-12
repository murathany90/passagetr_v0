class ReadingEngagement {
  const ReadingEngagement({
    required this.passageId,
    required this.isBookmarked,
    required this.isFavorite,
    this.bookmarkedAt,
    this.favoritedAt,
  });

  const ReadingEngagement.empty({required this.passageId})
    : isBookmarked = false,
      isFavorite = false,
      bookmarkedAt = null,
      favoritedAt = null;

  final String passageId;
  final bool isBookmarked;
  final bool isFavorite;
  final DateTime? bookmarkedAt;
  final DateTime? favoritedAt;

  ReadingEngagement copyWith({
    bool? isBookmarked,
    bool? isFavorite,
    DateTime? bookmarkedAt,
    bool clearBookmarkedAt = false,
    DateTime? favoritedAt,
    bool clearFavoritedAt = false,
  }) {
    return ReadingEngagement(
      passageId: passageId,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isFavorite: isFavorite ?? this.isFavorite,
      bookmarkedAt: clearBookmarkedAt
          ? null
          : (bookmarkedAt ?? this.bookmarkedAt),
      favoritedAt: clearFavoritedAt ? null : (favoritedAt ?? this.favoritedAt),
    );
  }

  ReadingEngagement setBookmark(bool value, {DateTime? at}) {
    return copyWith(
      isBookmarked: value,
      bookmarkedAt: value ? (at ?? bookmarkedAt) : null,
      clearBookmarkedAt: !value,
    );
  }

  ReadingEngagement setFavorite(bool value, {DateTime? at}) {
    return copyWith(
      isFavorite: value,
      favoritedAt: value ? (at ?? favoritedAt) : null,
      clearFavoritedAt: !value,
    );
  }
}
