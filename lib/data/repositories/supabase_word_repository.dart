import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/tag_count.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/entities/word_level_summary.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/value_objects/paged_result.dart';

class SupabaseWordRepository implements WordRepository {
  SupabaseWordRepository(this._client);

  final SupabaseClient _client;
  static const List<String> _orderedLevels = <String>[
    'A1',
    'A2',
    'B1',
    'B2',
    'C1',
    'C2',
  ];

  @override
  Future<List<String>> getDistinctPosValues({
    String? packId,
    String? level,
  }) async {
    dynamic builder = _client.from('words').select('pos');

    final String cleanPackId = (packId ?? '').trim();
    if (cleanPackId.isNotEmpty) {
      builder = builder.eq('pack_id', cleanPackId);
    }

    final String cleanLevel = (level ?? '').trim();
    if (cleanLevel.isNotEmpty) {
      builder = builder.ilike('level', cleanLevel.toUpperCase());
    }

    final List<dynamic> rows = await builder.limit(10000);
    final Set<String> tokens = <String>{};
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
      final String raw = (data['pos'] as String? ?? '').trim();
      if (raw.isEmpty) {
        continue;
      }
      for (final String token
          in _splitTokens(raw, delimiterRegex: RegExp(r';'))) {
        if (token.isNotEmpty) {
          tokens.add(token);
        }
      }
    }

    return _sortTokensByCanonical(tokens);
  }

  @override
  Future<PagedResult<WordItem>> getWordsByPack(
    String packId, {
    String? query,
    String? pos,
    String? tag,
    int limit = 50,
    int offset = 0,
  }) async {
    dynamic builder = _client.from('words').select().eq('pack_id', packId);

    final String cleanQuery = (query ?? '').trim();
    if (cleanQuery.isNotEmpty) {
      builder = builder.ilike('en_word', '%$cleanQuery%');
    }

    final String cleanPos = (pos ?? '').trim();
    if (cleanPos.isNotEmpty) {
      builder = builder.filter('pos', 'imatch', _posTokenRegex(cleanPos));
    }

    final String cleanTag = (tag ?? '').trim();
    if (cleanTag.isNotEmpty) {
      builder = builder.filter('tags_raw', 'imatch', _tagTokenRegex(cleanTag));
    }

    final List<dynamic> rows = await builder
        .order('en_word', ascending: true)
        .range(offset, offset + limit);

    final bool hasMore = rows.length > limit;
    final List<dynamic> sliced = hasMore ? rows.take(limit).toList() : rows;
    final List<WordItem> items =
        sliced.map((dynamic e) => _fromRow(e as Map)).toList(growable: false);

    return PagedResult<WordItem>(
      items: items,
      hasMore: hasMore,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<WordItem?> getWordById(String wordId) async {
    final List<dynamic> rows =
        await _client.from('words').select().eq('id', wordId).limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first as Map);
  }

  @override
  Future<WordItem?> getWordByEnWord({
    required String packId,
    required String enWord,
  }) async {
    final String normalized = enWord.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    final List<dynamic> rows = await _client
        .from('words')
        .select()
        .eq('pack_id', packId)
        .ilike('en_word', normalized)
        .limit(10);

    if (rows.isEmpty) {
      return null;
    }

    WordItem? fallback;
    for (final dynamic row in rows) {
      final WordItem item = _fromRow(row as Map);
      final String current = item.enWord.trim().toLowerCase();
      if (current == normalized) {
        return item;
      }
      fallback ??= item;
    }

    return fallback;
  }

  @override
  Future<List<WordItem>> getWordsByIds(List<String> wordIds) async {
    if (wordIds.isEmpty) {
      return const <WordItem>[];
    }

    final List<dynamic> rows =
        await _client.from('words').select().inFilter('id', wordIds);

    final Map<String, WordItem> byId = <String, WordItem>{};
    for (final dynamic row in rows) {
      final WordItem word = _fromRow(row as Map);
      byId[word.id] = word;
    }

    final List<WordItem> ordered = <WordItem>[];
    for (final String id in wordIds) {
      final WordItem? found = byId[id];
      if (found != null) {
        ordered.add(found);
      }
    }
    return ordered;
  }

  @override
  Future<List<WordItem>> getSessionBatch(
    String packId, {
    int limit = 100,
    int offset = 0,
  }) async {
    final PagedResult<WordItem> page = await getWordsByPack(
      packId,
      limit: limit,
      offset: offset,
    );
    return page.items;
  }

  @override
  Future<List<WordItem>> getGlobalWordIndex({int limit = 7000}) async {
    final int boundedLimit = limit <= 0 ? 7000 : limit;
    final List<dynamic> rows = await _client
        .from('words')
        .select()
        .order('en_word', ascending: true)
        .limit(boundedLimit);

    return rows.map((dynamic e) => _fromRow(e as Map)).toList(growable: false);
  }

  @override
  Future<List<WordLevelSummary>> getLevelsWithWordCount() async {
    final List<dynamic> rows = await _client
        .from('words')
        .select('level')
        .not('level', 'is', null)
        .limit(10000);

    final Map<String, int> counts = <String, int>{};
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
      final String level =
          (data['level'] as String? ?? '').trim().toUpperCase();
      if (level.isEmpty) {
        continue;
      }
      counts[level] = (counts[level] ?? 0) + 1;
    }

    return _orderedLevels
        .map(
          (String level) => WordLevelSummary(
            level: level,
            wordCount: counts[level] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<TagCount>> getTagsByLevel(
    String level, {
    String? search,
  }) async {
    final String cleanLevel = level.trim().toUpperCase();
    final String cleanSearch = _normalize(search ?? '');
    if (cleanLevel.isEmpty) {
      return const <TagCount>[];
    }

    final List<dynamic> rows = await _client
        .from('words')
        .select('tags_raw')
        .ilike('level', cleanLevel)
        .not('tags_raw', 'is', null)
        .limit(10000);

    final Map<String, int> counts = <String, int>{};
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
      final String raw = (data['tags_raw'] as String? ?? '').trim();
      if (raw.isEmpty) {
        continue;
      }
      final List<String> parts = raw
          .split(RegExp(r'[;,]'))
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList(growable: false);
      for (final String part in parts) {
        final String key = _normalize(part);
        if (key.isEmpty) {
          continue;
        }
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    final List<TagCount> tags = counts.entries
        .where(
          (MapEntry<String, int> e) =>
              cleanSearch.isEmpty || e.key.contains(cleanSearch),
        )
        .map((MapEntry<String, int> e) => TagCount(tag: e.key, count: e.value))
        .toList(growable: false)
      ..sort((TagCount a, TagCount b) {
        final int countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.tag.compareTo(b.tag);
      });

    return tags;
  }

  @override
  Future<PagedResult<WordItem>> getWordsByLevel({
    required String level,
    String? tag,
    String? query,
    String? pos,
    int limit = 50,
    int offset = 0,
  }) async {
    dynamic builder = _client
        .from('words')
        .select()
        .ilike('level', level.trim().toUpperCase());

    final String cleanQuery = (query ?? '').trim();
    if (cleanQuery.isNotEmpty) {
      builder = builder.ilike('en_word', '%$cleanQuery%');
    }

    final String cleanPos = (pos ?? '').trim();
    if (cleanPos.isNotEmpty) {
      builder = builder.filter('pos', 'imatch', _posTokenRegex(cleanPos));
    }

    final String cleanTag = (tag ?? '').trim();
    if (cleanTag.isNotEmpty) {
      builder = builder.filter('tags_raw', 'imatch', _tagTokenRegex(cleanTag));
    }

    final List<dynamic> rows = await builder
        .order('en_word', ascending: true)
        .range(offset, offset + limit);

    final bool hasMore = rows.length > limit;
    final List<dynamic> sliced = hasMore ? rows.take(limit).toList() : rows;
    final List<WordItem> items =
        sliced.map((dynamic e) => _fromRow(e as Map)).toList(growable: false);

    return PagedResult<WordItem>(
      items: items,
      hasMore: hasMore,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<WordItem?> getWordByEnWordGlobal(String enWord) async {
    final String normalized = _normalize(enWord);
    if (normalized.isEmpty) {
      return null;
    }

    final List<dynamic> rows = await _client
        .from('words')
        .select()
        .ilike('en_word', normalized)
        .limit(20);

    if (rows.isEmpty) {
      return null;
    }

    WordItem? fallback;
    for (final dynamic row in rows) {
      final WordItem item = _fromRow(row as Map);
      if (_normalize(item.enWord) == normalized) {
        return item;
      }
      fallback ??= item;
    }
    return fallback;
  }

  WordItem _fromRow(Map row) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);
    return WordItem(
      id: data['id'] as String,
      packId: data['pack_id'] as String?,
      enWord: (data['en_word'] as String?) ?? '',
      trMeaning: (data['tr_meaning'] as String?) ?? '',
      pos: (data['pos'] as String?) ?? '',
      exampleEn: (data['example_en'] as String?) ?? '',
      exampleTr: data['example_tr'] as String?,
      synonymsRaw: data['synonyms_raw'] as String?,
      antonymsRaw: data['antonyms_raw'] as String?,
      level: data['level'] as String?,
      tagsRaw: data['tags_raw'] as String?,
      notes: data['notes'] as String?,
    );
  }

  String _normalize(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> _splitTokens(
    String raw, {
    required RegExp delimiterRegex,
  }) {
    return raw
        .split(delimiterRegex)
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _sortTokensByCanonical(Set<String> values) {
    final Set<String> remaining = values.map((String e) => e.trim()).toSet();
    final List<String> ordered = <String>[];

    for (final String canonical in AppConstants.posValues) {
      final String match = remaining.firstWhere(
        (String value) => value.toLowerCase() == canonical.toLowerCase(),
        orElse: () => '',
      );
      if (match.isNotEmpty) {
        ordered.add(canonical);
        remaining.remove(match);
      }
    }

    final List<String> unknown = remaining.toList(growable: false)
      ..sort(
          (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    ordered.addAll(unknown);
    return ordered;
  }

  String _posTokenRegex(String token) {
    final String body = _regexBodyFromToken(token);
    return '(^|;)\\s*$body\\s*(;|${r'$'})';
  }

  String _tagTokenRegex(String token) {
    final String body = _regexBodyFromToken(token);
    return '(^|[;,])\\s*$body\\s*([;,]|${r'$'})';
  }

  String _regexBodyFromToken(String token) {
    final List<String> parts = token
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '';
    }

    return parts.map(_escapeRegexLiteral).join(r'\s*');
  }

  String _escapeRegexLiteral(String value) {
    return value.replaceAllMapped(
      RegExp(r'[\\^$.*+?()\[\]{}|]'),
      (Match match) => '\\${match.group(0)}',
    );
  }
}
