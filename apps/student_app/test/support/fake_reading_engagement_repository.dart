import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class FakeReadingEngagementRepository implements ReadingEngagementRepository {
  const FakeReadingEngagementRepository(this.items);

  final List<ReadingEngagement> items;

  @override
  Future<List<ReadingEngagement>> fetchAll() async => items;

  @override
  Future<AppResult<void>> setBookmark(
    String passageId,
    bool isBookmarked,
  ) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<void>> setFavorite(String passageId, bool isFavorite) async {
    return const AppSuccess<void>(null);
  }
}
