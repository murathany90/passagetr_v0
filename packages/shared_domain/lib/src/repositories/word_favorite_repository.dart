import 'package:shared_core/shared_core.dart';

import '../entities/word_favorite.dart';

abstract interface class WordFavoriteRepository {
  Future<List<WordFavorite>> fetchAll();

  Future<AppResult<void>> setFavorite(String wordId, bool isFavorite);
}
