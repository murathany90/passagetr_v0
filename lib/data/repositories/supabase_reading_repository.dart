import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/sentence_translation.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/value_objects/paged_result.dart';

class SupabaseReadingRepository implements ReadingRepository {
  SupabaseReadingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    int limit = 20,
    int offset = 0,
  }) async {
    final List<dynamic> rows = await _client
        .from('reading_passages')
        .select()
        .eq('pack_id', packId)
        .order('title', ascending: true)
        .range(offset, offset + limit);

    final bool hasMore = rows.length > limit;
    final List<dynamic> sliced = hasMore ? rows.take(limit).toList() : rows;

    final List<ReadingPassage> items = sliced
        .map((dynamic e) => _passageFromRow(e as Map))
        .toList(growable: false);

    return PagedResult<ReadingPassage>(
      items: items,
      hasMore: hasMore,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<List<PassageSentence>> getSentences({
    required String passageId,
  }) async {
    final List<dynamic> rows = await _client
        .from('reading_passage_sentences')
        .select()
        .eq('passage_id', passageId)
        .order('idx', ascending: true);

    return rows
        .map((dynamic e) => _sentenceFromRow(e as Map))
        .toList(growable: false);
  }

  @override
  Future<SentenceTranslation?> getCachedTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
  }) async {
    final List<dynamic> rows = await _client
        .from('reading_sentence_translations')
        .select()
        .eq('sentence_id', sentenceId)
        .eq('provider', provider)
        .eq('target_lang', targetLang)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return _translationFromRow(rows.first as Map);
  }

  @override
  Future<void> saveTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
    required String translatedText,
  }) async {
    await _client.from('reading_sentence_translations').upsert(
      <String, dynamic>{
        'sentence_id': sentenceId,
        'provider': provider,
        'target_lang': targetLang,
        'translated_text': translatedText,
      },
      onConflict: 'sentence_id,provider,target_lang',
    );
  }

  ReadingPassage _passageFromRow(Map row) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);
    return ReadingPassage(
      id: data['id'] as String,
      packId: data['pack_id'] as String?,
      packName: data['pack_name'] as String?,
      title: (data['title'] as String?) ?? '',
      level: data['level'] as String?,
      tagsRaw: data['tags_raw'] as String?,
      sourceUrl: data['source_url'] as String?,
    );
  }

  PassageSentence _sentenceFromRow(Map row) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);
    return PassageSentence(
      id: data['id'] as String,
      passageId: data['passage_id'] as String?,
      passageTitle: data['passage_title'] as String?,
      idx: data['idx'] as int? ?? 0,
      sentenceEn: (data['sentence_en'] as String?) ?? '',
      sentenceTr: data['sentence_tr'] as String?,
    );
  }

  SentenceTranslation _translationFromRow(Map row) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);
    return SentenceTranslation(
      id: data['id'] as String,
      sentenceId: data['sentence_id'] as String,
      provider: (data['provider'] as String?) ?? '',
      targetLang: (data['target_lang'] as String?) ?? 'tr',
      translatedText: (data['translated_text'] as String?) ?? '',
      createdAt: data['created_at'] == null
          ? null
          : DateTime.tryParse(data['created_at'] as String),
    );
  }
}
