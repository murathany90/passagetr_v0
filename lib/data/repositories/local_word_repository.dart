import '../../domain/entities/word_item.dart';
import '../../domain/entities/word_level_summary.dart';
import '../../domain/entities/tag_count.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/value_objects/paged_result.dart';
import '../local/app_content_local_datasource.dart';

class LocalWordRepository implements WordRepository {
  LocalWordRepository(this._local);

  final AppContentLocalDataSource _local;

  @override
  Future<PagedResult<WordItem>> getWordsByPack(
    String packId, {
    String? query,
    String? pos,
    String? tag,
    int limit = 50,
    int offset = 0,
  }) {
    return _local.getWordsByPack(
      packId,
      query: query,
      pos: pos,
      tag: tag,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<WordItem?> getWordById(String wordId) {
    return _local.getWordById(wordId);
  }

  @override
  Future<WordItem?> getWordByEnWord({
    required String packId,
    required String enWord,
  }) {
    return _local.getWordByEnWord(
      packId: packId,
      enWord: enWord,
    );
  }

  @override
  Future<List<WordItem>> getWordsByIds(List<String> wordIds) {
    return _local.getWordsByIds(wordIds);
  }

  @override
  Future<List<WordItem>> getSessionBatch(
    String packId, {
    int limit = 100,
    int offset = 0,
  }) {
    return _local.getSessionBatch(
      packId,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<WordItem>> getGlobalWordIndex({int limit = 7000}) {
    return _local.getGlobalWordIndex(limit: limit);
  }

  @override
  Future<List<WordLevelSummary>> getLevelsWithWordCount() {
    return _local.getLevelsWithWordCount();
  }

  @override
  Future<List<TagCount>> getTagsByLevel(
    String level, {
    String? search,
  }) {
    return _local.getTagsByLevel(level, search: search);
  }

  @override
  Future<PagedResult<WordItem>> getWordsByLevel({
    required String level,
    String? tag,
    String? query,
    String? pos,
    int limit = 50,
    int offset = 0,
  }) {
    return _local.getWordsByLevel(
      level: level,
      tag: tag,
      query: query,
      pos: pos,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<WordItem?> getWordByEnWordGlobal(String enWord) {
    return _local.getWordByEnWordGlobal(enWord);
  }
}
