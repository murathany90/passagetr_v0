import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/word_item.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/value_objects/paged_result.dart';

class SupabaseWordRepository implements WordRepository {
  SupabaseWordRepository(this._client);

  final SupabaseClient _client;

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
      builder = builder.eq('pos', cleanPos);
    }

    final String cleanTag = (tag ?? '').trim();
    if (cleanTag.isNotEmpty) {
      builder = builder.ilike('tags_raw', '%$cleanTag%');
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
}
