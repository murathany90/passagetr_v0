import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/passage_word_extractor.dart';
import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/reading_resume_item.dart';
import '../../domain/entities/sentence_translation.dart';
import '../../domain/entities/user_reading_progress.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/value_objects/paged_result.dart';

class SupabaseReadingRepository implements ReadingRepository {
  SupabaseReadingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  }) async {
    dynamic builder =
        _client.from('reading_passages').select().eq('pack_id', packId);
    final Set<String> normalizedLevels = (levels ?? <String>{})
        .map((String e) => e.trim().toUpperCase())
        .where((String e) => e.isNotEmpty)
        .toSet();
    if (normalizedLevels.isNotEmpty) {
      builder = builder.inFilter('level', normalizedLevels.toList());
    }

    final List<dynamic> rows = await builder
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
  Future<PagedResult<ReadingPassage>> getReadingFeed({
    String? category,
    String? level,
    int limit = 20,
    int offset = 0,
  }) async {
    dynamic builder = _client.from('reading_passages').select();

    final String cleanCategory = (category ?? '').trim();
    if (cleanCategory.isNotEmpty) {
      builder = builder.ilike('category', cleanCategory);
    }

    final String cleanLevel = (level ?? '').trim().toUpperCase();
    if (cleanLevel.isNotEmpty) {
      builder = builder.ilike('level', cleanLevel);
    }

    final List<dynamic> rows = await builder
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

  @override
  Future<UserReadingProgress?> getUserReadingProgress({
    required String passageId,
  }) async {
    final String userId = _resolveUserId();
    final List<dynamic> rows = await _client
        .from('user_reading_progress')
        .select()
        .eq('user_id', userId)
        .eq('passage_id', passageId)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return _readingProgressFromRow(rows.first as Map);
  }

  @override
  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {
    final String userId = _resolveUserId();
    await _client.from('user_reading_progress').upsert(
      <String, dynamic>{
        'user_id': userId,
        'passage_id': passageId,
        'last_idx': lastIdx < 0 ? 0 : lastIdx,
        'completed': completed,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,passage_id',
    );
  }

  @override
  Future<Map<String, UserReadingProgress>> getProgressMapForPassages(
    List<String> passageIds,
  ) async {
    if (passageIds.isEmpty) {
      return const <String, UserReadingProgress>{};
    }

    final String userId = _resolveUserId();
    final List<dynamic> rows = await _client
        .from('user_reading_progress')
        .select()
        .eq('user_id', userId)
        .inFilter('passage_id', passageIds);

    final Map<String, UserReadingProgress> mapped =
        <String, UserReadingProgress>{};
    for (final dynamic row in rows) {
      final UserReadingProgress progress = _readingProgressFromRow(row as Map);
      mapped[progress.passageId] = progress;
    }
    return mapped;
  }

  @override
  Future<int> getTodayReadSentenceCount() async {
    final String userId = _resolveUserId();
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);

    final List<dynamic> rows = await _client
        .from('user_reading_progress')
        .select('last_idx')
        .eq('user_id', userId)
        .gte('last_seen_at', startOfDay.toUtc().toIso8601String());

    int sum = 0;
    for (final dynamic row in rows) {
      final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
      sum += data['last_idx'] as int? ?? 0;
    }
    return sum;
  }

  @override
  Future<ReadingResumeItem?> getLatestIncompleteReading() async {
    final String userId = _resolveUserId();
    final List<dynamic> progressRows = await _client
        .from('user_reading_progress')
        .select()
        .eq('user_id', userId)
        .eq('completed', false)
        .gt('last_idx', 0)
        .order('last_seen_at', ascending: false)
        .limit(1);

    if (progressRows.isEmpty) {
      return null;
    }

    final UserReadingProgress progress =
        _readingProgressFromRow(progressRows.first as Map);

    final List<dynamic> passageRows = await _client
        .from('reading_passages')
        .select()
        .eq('id', progress.passageId)
        .limit(1);

    if (passageRows.isEmpty) {
      return null;
    }

    return ReadingResumeItem(
      passage: _passageFromRow(passageRows.first as Map),
      progress: progress,
    );
  }

  @override
  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  }) async {
    final List<WordItem> fromRelation = await _getPassageWordsFromRelation(
      passageId: passageId,
      limit: limit,
    );
    if (fromRelation.isNotEmpty) {
      return fromRelation;
    }
    return _getPassageWordsFromRuntimeExtraction(
      passageId: passageId,
      limit: limit,
    );
  }

  @override
  Future<void> toggleBookmark(String passageId) async {
    final String userId = _resolveUserId();
    final List<dynamic> existing = await _client
        .from('user_reading_bookmarks')
        .select('passage_id')
        .eq('user_id', userId)
        .eq('passage_id', passageId)
        .limit(1);

    if (existing.isEmpty) {
      await _client.from('user_reading_bookmarks').insert(
        <String, dynamic>{
          'user_id': userId,
          'passage_id': passageId,
        },
      );
      return;
    }

    await _client
        .from('user_reading_bookmarks')
        .delete()
        .eq('user_id', userId)
        .eq('passage_id', passageId);
  }

  @override
  Future<void> toggleFavorite(String passageId) async {
    final String userId = _resolveUserId();
    final List<dynamic> existing = await _client
        .from('user_reading_favorites')
        .select('passage_id')
        .eq('user_id', userId)
        .eq('passage_id', passageId)
        .limit(1);

    if (existing.isEmpty) {
      await _client.from('user_reading_favorites').insert(
        <String, dynamic>{
          'user_id': userId,
          'passage_id': passageId,
        },
      );
      return;
    }

    await _client
        .from('user_reading_favorites')
        .delete()
        .eq('user_id', userId)
        .eq('passage_id', passageId);
  }

  @override
  Future<PagedResult<ReadingPassage>> getBookmarkedPassages({
    int limit = 20,
    int offset = 0,
  }) {
    return _getPassagesFromUserCollection(
      table: 'user_reading_bookmarks',
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<PagedResult<ReadingPassage>> getFavoritePassages({
    int limit = 20,
    int offset = 0,
  }) {
    return _getPassagesFromUserCollection(
      table: 'user_reading_favorites',
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<bool> isPassageBookmarked(String passageId) async {
    final String userId = _resolveUserId();
    final List<dynamic> rows = await _client
        .from('user_reading_bookmarks')
        .select('passage_id')
        .eq('user_id', userId)
        .eq('passage_id', passageId)
        .limit(1);
    return rows.isNotEmpty;
  }

  @override
  Future<bool> isPassageFavorited(String passageId) async {
    final String userId = _resolveUserId();
    final List<dynamic> rows = await _client
        .from('user_reading_favorites')
        .select('passage_id')
        .eq('user_id', userId)
        .eq('passage_id', passageId)
        .limit(1);
    return rows.isNotEmpty;
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
      category: data['category'] as String?,
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

  UserReadingProgress _readingProgressFromRow(Map row) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);
    return UserReadingProgress(
      userId: data['user_id'] as String,
      passageId: data['passage_id'] as String,
      completed: data['completed'] as bool? ?? false,
      lastIdx: data['last_idx'] as int? ?? 0,
      lastSeenAt: data['last_seen_at'] == null
          ? null
          : DateTime.tryParse(data['last_seen_at'] as String),
    );
  }

  Future<List<WordItem>> _getPassageWordsFromRelation({
    required String passageId,
    required int limit,
  }) async {
    try {
      final List<dynamic> rows = await _client
          .from('reading_passage_words')
          .select('word_id, words(*)')
          .eq('passage_id', passageId)
          .limit(limit);

      final List<WordItem> words = <WordItem>[];
      for (final dynamic row in rows) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
        final dynamic nested = data['words'];
        if (nested is Map) {
          words.add(_fromWordRow(nested));
        }
      }
      return words;
    } catch (_) {
      return const <WordItem>[];
    }
  }

  Future<List<WordItem>> _getPassageWordsFromRuntimeExtraction({
    required String passageId,
    required int limit,
  }) async {
    final List<dynamic> passageRows = await _client
        .from('reading_passages')
        .select('pack_id')
        .eq('id', passageId)
        .limit(1);

    if (passageRows.isEmpty) {
      return const <WordItem>[];
    }
    final Map<String, dynamic> passage =
        Map<String, dynamic>.from(passageRows.first as Map);
    final String? packId = passage['pack_id'] as String?;
    if (packId == null || packId.trim().isEmpty) {
      return const <WordItem>[];
    }

    final List<dynamic> sentenceRows = await _client
        .from('reading_passage_sentences')
        .select('sentence_en')
        .eq('passage_id', passageId)
        .order('idx', ascending: true);

    final List<String> texts = sentenceRows
        .map((dynamic row) =>
            (Map<String, dynamic>.from(row as Map)['sentence_en'] as String?) ??
            '')
        .where((String e) => e.trim().isNotEmpty)
        .toList(growable: false);

    final List<String> candidates = extractPassageWordCandidates(
      texts,
      max: limit * 4,
    );
    if (candidates.isEmpty) {
      return const <WordItem>[];
    }

    final List<dynamic> wordsRows = await _client
        .from('words')
        .select()
        .eq('pack_id', packId)
        .order('en_word', ascending: true)
        .limit(4000);

    final Set<String> candidateSet = candidates.toSet();
    final List<WordItem> matched = <WordItem>[];
    for (final dynamic row in wordsRows) {
      final WordItem word = _fromWordRow(row as Map);
      if (candidateSet.contains(word.enWord.toLowerCase())) {
        matched.add(word);
      }
      if (matched.length >= limit) {
        break;
      }
    }
    return matched;
  }

  WordItem _fromWordRow(Map row) {
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

  Future<PagedResult<ReadingPassage>> _getPassagesFromUserCollection({
    required String table,
    required int limit,
    required int offset,
  }) async {
    final String userId = _resolveUserId();
    final List<dynamic> rows = await _client
        .from(table)
        .select('passage_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit);

    final bool hasMore = rows.length > limit;
    final List<dynamic> sliced = hasMore ? rows.take(limit).toList() : rows;
    final List<String> ids = sliced
        .map((dynamic row) =>
            (Map<String, dynamic>.from(row as Map)['passage_id'] as String? ??
                    '')
                .trim())
        .where((String id) => id.isNotEmpty)
        .toList(growable: false);

    if (ids.isEmpty) {
      return PagedResult<ReadingPassage>(
        items: const <ReadingPassage>[],
        hasMore: hasMore,
        nextOffset: offset,
      );
    }

    final List<dynamic> passageRows =
        await _client.from('reading_passages').select().inFilter('id', ids);
    final Map<String, ReadingPassage> byId = <String, ReadingPassage>{};
    for (final dynamic row in passageRows) {
      final ReadingPassage passage = _passageFromRow(row as Map);
      byId[passage.id] = passage;
    }
    final List<ReadingPassage> items = <ReadingPassage>[];
    for (final String id in ids) {
      final ReadingPassage? found = byId[id];
      if (found != null) {
        items.add(found);
      }
    }
    return PagedResult<ReadingPassage>(
      items: items,
      hasMore: hasMore,
      nextOffset: offset + items.length,
    );
  }

  String _resolveUserId() {
    final String? authUserId = _client.auth.currentUser?.id;
    if (authUserId != null && authUserId.isNotEmpty) {
      return authUserId;
    }

    if (kDebugMode &&
        AppConfig.allowDemoFallback &&
        AppConfig.demoUserUuid.isNotEmpty) {
      return AppConfig.demoUserUuid;
    }

    throw StateError(
      'Auth session yok. Reading progress auth olmadan baslatilamaz.',
    );
  }
}
