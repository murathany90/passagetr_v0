import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class FakeWordFavoriteRepository implements WordFavoriteRepository {
  FakeWordFavoriteRepository({
    List<WordFavorite>? items,
    this.favoriteResult = const AppSuccess<void>(null),
  }) : _items = items ?? const <WordFavorite>[];

  final List<WordFavorite> _items;
  final AppResult<void> favoriteResult;
  final List<(String, bool)> favoriteWrites = <(String, bool)>[];

  @override
  Future<List<WordFavorite>> fetchAll() async => _items;

  @override
  Future<AppResult<void>> setFavorite(String wordId, bool isFavorite) async {
    favoriteWrites.add((wordId, isFavorite));
    return favoriteResult;
  }
}
