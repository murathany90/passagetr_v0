import 'package:shared_core/shared_core.dart';

import '../entities/reading_engagement.dart';

abstract interface class ReadingEngagementRepository {
  Future<List<ReadingEngagement>> fetchAll();

  Future<AppResult<void>> setBookmark(String passageId, bool isBookmarked);

  Future<AppResult<void>> setFavorite(String passageId, bool isFavorite);
}
