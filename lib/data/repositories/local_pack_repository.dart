import '../../domain/entities/pack.dart';
import '../../domain/repositories/pack_repository.dart';
import '../local/app_content_local_datasource.dart';

class LocalPackRepository implements PackRepository {
  LocalPackRepository(this._local);

  final AppContentLocalDataSource _local;

  /// In-memory cache for passage-based word counts per pack.
  static Map<String, int>? _passageWordCountCache;

  @override
  Future<List<Pack>> getPacksWithWordCount() async {
    final List<Pack> packs = await _local.getPacksWithWordCount();

    // Build the passage-based word count cache if not available yet.
    if (_passageWordCountCache == null) {
      _passageWordCountCache = <String, int>{};
      for (final Pack pack in packs) {
        final int passageWordCount =
            await _local.getPassageWordCountByPack(pack.id);
        _passageWordCountCache![pack.id] = passageWordCount;
      }
    }

    // Return packs with the HIGHER of FK-based vs passage-based word count.
    // This ensures packs with direct FK words (YDS Set 001) keep their count,
    // while packs with only reading passages get their passage-word count.
    return packs.map((Pack pack) {
      final int passageCount = _passageWordCountCache![pack.id] ?? 0;
      final int effectiveCount =
          passageCount > pack.wordCount ? passageCount : pack.wordCount;
      return pack.copyWith(wordCount: effectiveCount);
    }).toList(growable: false);
  }

  @override
  Future<Pack?> getPackById(String packId) {
    return _local.getPackById(packId);
  }

  /// Clears the in-memory passage word count cache.
  static void clearCache() {
    _passageWordCountCache = null;
  }
}
