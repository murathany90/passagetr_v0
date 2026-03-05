import '../entities/word_item.dart';
import '../entities/word_level_summary.dart';
import '../entities/tag_count.dart';
import '../value_objects/paged_result.dart';

abstract class WordRepository {
  Future<List<String>> getDistinctPosValues({
    String? packId,
    String? level,
  });

  Future<PagedResult<WordItem>> getWordsByPack(
    String packId, {
    String? query,
    String? pos,
    String? tag,
    int limit = 50,
    int offset = 0,
  });

  Future<WordItem?> getWordById(String wordId);

  Future<WordItem?> getWordByEnWord({
    required String packId,
    required String enWord,
  });

  Future<List<WordItem>> getWordsByIds(List<String> wordIds);

  // Faz 2 notu: bu metot icte source-agnostic query builder kullanacak
  // sekilde implement edilir. Gerektiginde getWordsBySource eklenebilir.
  Future<List<WordItem>> getSessionBatch(
    String packId, {
    int limit = 100,
    int offset = 0,
  });

  Future<List<WordItem>> getGlobalWordIndex({int limit = 7000});

  Future<List<WordLevelSummary>> getLevelsWithWordCount();

  Future<List<TagCount>> getTagsByLevel(
    String level, {
    String? search,
  });

  Future<PagedResult<WordItem>> getWordsByLevel({
    required String level,
    String? tag,
    String? query,
    String? pos,
    int limit = 50,
    int offset = 0,
  });

  Future<WordItem?> getWordByEnWordGlobal(String enWord);
}
