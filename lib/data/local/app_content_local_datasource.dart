import 'package:drift/drift.dart';

import '../../core/utils/passage_word_extractor.dart';
import '../../core/utils/pos_label_mapper.dart';
import '../../domain/entities/tag_count.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/entities/word_level_summary.dart';
import '../../domain/value_objects/paged_result.dart';
import 'app_content_local_database.dart';

class AppContentLocalDataSource {
  AppContentLocalDataSource(this._db);

  final AppContentLocalDatabase _db;
  static const List<String> _orderedLevels = <String>[
    'A1',
    'A2',
    'B1',
    'B2',
    'C1',
    'C2',
  ];

  Future<void> ensureReady() async {
    await getDatasetVersion();
  }

  Future<String> getDatasetVersion() async {
    final AppContentMetaData? row = await (_db.select(_db.appContentMeta)
          ..where((tbl) => tbl.key.equals('dataset_version'))
          ..limit(1))
        .getSingleOrNull();
    return (row?.value ?? '').trim();
  }

  Future<List<Pack>> getPacksWithWordCount() async {
    final List<QueryRow> rows = await _db.customSelect(
      '''
select
  p.id,
  p.name,
  p.from_lang,
  p.to_lang,
  count(w.id) as word_count
from packs p
left join words w on w.pack_id = p.id
group by p.id, p.name, p.from_lang, p.to_lang
order by lower(p.name) asc, p.name asc
      ''',
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentPacks,
        _db.appContentWords,
      },
    ).get();

    return rows.map(_packFromQueryRow).toList(growable: false);
  }

  Future<Pack?> getPackById(String packId) async {
    final String normalized = packId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final List<QueryRow> rows = await _db.customSelect(
      '''
select
  p.id,
  p.name,
  p.from_lang,
  p.to_lang,
  count(w.id) as word_count
from packs p
left join words w on w.pack_id = p.id
where p.id = ?1
group by p.id, p.name, p.from_lang, p.to_lang
limit 1
      ''',
      variables: <Variable<Object>>[Variable<String>(normalized)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentPacks,
        _db.appContentWords,
      },
    ).get();

    if (rows.isEmpty) {
      return null;
    }
    return _packFromQueryRow(rows.first);
  }

  Future<PagedResult<WordItem>> getWordsByPack(
    String packId, {
    String? query,
    String? pos,
    String? tag,
    int limit = 50,
    int offset = 0,
  }) async {
    final String normalizedPackId = packId.trim();
    final String normalizedQuery = _normalize((query ?? '').trim());
    final String normalizedPos = _normalizeTokenForContains(pos ?? '');
    final String normalizedPosLike = '%;$normalizedPos;%';
    final String normalizedTag = _normalizeTokenForContains(tag ?? '');
    final int boundedLimit = limit <= 0 ? 50 : limit;
    final int boundedOffset = offset < 0 ? 0 : offset;

    final String queryLike = '%$normalizedQuery%';
    final String tagLike = '%;$normalizedTag;%';

    final List<QueryRow> rows = await _db.customSelect(
      '''
select *
from words
where pack_id = ?1
  and (?2 = '' or en_word_normalized like ?3 or search_key like ?3)
  and (?4 = '' or (';' || replace(replace(lower(coalesce(pos, '')), ',', ';'), ' ', '') || ';') like ?5)
  and (?6 = '' or (';' || replace(replace(lower(coalesce(tags_raw, '')), ',', ';'), ' ', '') || ';') like ?7)
order by lower(en_word) asc, en_word asc
limit ?8 offset ?9
      ''',
      variables: <Variable<Object>>[
        Variable<String>(normalizedPackId),
        Variable<String>(normalizedQuery),
        Variable<String>(queryLike),
        Variable<String>(normalizedPos),
        Variable<String>(normalizedPosLike),
        Variable<String>(normalizedTag),
        Variable<String>(tagLike),
        Variable<int>(boundedLimit + 1),
        Variable<int>(boundedOffset),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentWords
      },
    ).get();

    final bool hasMore = rows.length > boundedLimit;
    final List<QueryRow> sliced =
        hasMore ? rows.take(boundedLimit).toList() : rows;
    final List<WordItem> items =
        sliced.map(_wordFromQueryRow).toList(growable: false);

    return PagedResult<WordItem>(
      items: items,
      hasMore: hasMore,
      nextOffset: boundedOffset + items.length,
    );
  }

  Future<List<String>> getDistinctPosValues({
    String? packId,
    String? level,
  }) async {
    final String cleanPackId = (packId ?? '').trim();
    final String cleanLevel = (level ?? '').trim().toUpperCase();

    final List<Variable<Object>> variables = <Variable<Object>>[
      Variable<String>(cleanPackId),
      Variable<String>(cleanLevel),
    ];

    final List<QueryRow> rows = await _db
        .customSelect(
          '''
select pos
from words
where (?1 = '' or pack_id = ?1)
  and (?2 = '' or upper(coalesce(level, '')) = ?2)
  and trim(coalesce(pos, '')) <> ''
      ''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.appContentWords
          },
        )
        .get();

    final Set<String> tokens = <String>{};
    for (final QueryRow row in rows) {
      final String raw = row.read<String>('pos');
      for (final String token in raw.split(';')) {
        final String trimmed = token.trim();
        if (trimmed.isNotEmpty) {
          tokens.add(trimmed);
        }
      }
    }
    return PosLabelMapper.sortByCanonicalOrder(tokens);
  }

  Future<WordItem?> getWordById(String wordId) async {
    final String normalized = wordId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final AppContentWord? row = await (_db.select(_db.appContentWords)
          ..where((tbl) => tbl.id.equals(normalized))
          ..limit(1))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _wordFromData(row);
  }

  Future<WordItem?> getWordByEnWord({
    required String packId,
    required String enWord,
  }) async {
    final String normalizedPack = packId.trim();
    final String normalizedWord = _normalize(enWord);
    if (normalizedPack.isEmpty || normalizedWord.isEmpty) {
      return null;
    }

    final List<AppContentWord> rows = await (_db.select(_db.appContentWords)
          ..where(
            (tbl) =>
                tbl.packId.equals(normalizedPack) &
                tbl.enWordNormalized.equals(normalizedWord),
          )
          ..limit(1))
        .get();
    if (rows.isEmpty) {
      return null;
    }
    return _wordFromData(rows.first);
  }

  Future<List<WordItem>> getWordsByIds(List<String> wordIds) async {
    if (wordIds.isEmpty) {
      return const <WordItem>[];
    }

    final List<String> deduped = wordIds
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (deduped.isEmpty) {
      return const <WordItem>[];
    }

    final List<AppContentWord> rows = await (_db.select(_db.appContentWords)
          ..where((tbl) => tbl.id.isIn(deduped)))
        .get();

    final Map<String, WordItem> byId = <String, WordItem>{};
    for (final AppContentWord row in rows) {
      final WordItem item = _wordFromData(row);
      byId[item.id] = item;
    }

    final List<WordItem> ordered = <WordItem>[];
    for (final String id in wordIds) {
      final WordItem? item = byId[id];
      if (item != null) {
        ordered.add(item);
      }
    }
    return ordered;
  }

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

  Future<List<WordItem>> getGlobalWordIndex({int limit = 7000}) async {
    final int boundedLimit = limit <= 0 ? 7000 : limit;
    final List<QueryRow> rows = await _db.customSelect(
      '''
select *
from words
order by lower(en_word) asc, en_word asc
limit ?1
      ''',
      variables: <Variable<Object>>[Variable<int>(boundedLimit)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentWords
      },
    ).get();

    return rows.map(_wordFromQueryRow).toList(growable: false);
  }

  Future<List<WordLevelSummary>> getLevelsWithWordCount() async {
    final List<QueryRow> rows = await _db.customSelect(
      '''
select upper(coalesce(level, '')) as level_key, count(*) as word_count
from words
where level is not null and trim(level) <> ''
group by upper(coalesce(level, ''))
      ''',
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentWords
      },
    ).get();

    final Map<String, int> counts = <String, int>{};
    for (final QueryRow row in rows) {
      final String level = (row.read<String>('level_key')).trim().toUpperCase();
      if (level.isNotEmpty) {
        counts[level] = row.read<int>('word_count');
      }
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

  Future<List<TagCount>> getTagsByLevel(
    String level, {
    String? search,
  }) async {
    final String normalizedLevel = level.trim().toUpperCase();
    final String normalizedSearch = _normalize(search ?? '');
    if (normalizedLevel.isEmpty) {
      return const <TagCount>[];
    }

    final List<QueryRow> rows = await _db.customSelect(
      '''
select tags_raw
from words
where upper(coalesce(level, '')) = ?1
  and tags_raw is not null
  and trim(tags_raw) <> ''
      ''',
      variables: <Variable<Object>>[Variable<String>(normalizedLevel)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentWords
      },
    ).get();

    final Map<String, int> counts = <String, int>{};
    for (final QueryRow row in rows) {
      final String raw = row.read<String>('tags_raw');
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
              normalizedSearch.isEmpty || e.key.contains(normalizedSearch),
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

  Future<PagedResult<WordItem>> getWordsByLevel({
    required String level,
    String? tag,
    String? query,
    String? pos,
    int limit = 50,
    int offset = 0,
  }) async {
    final String normalizedLevel = level.trim().toUpperCase();
    final String normalizedQuery = _normalize((query ?? '').trim());
    final String normalizedPos = _normalizeTokenForContains(pos ?? '');
    final String normalizedPosLike = '%;$normalizedPos;%';
    final String normalizedTag = _normalizeTokenForContains(tag ?? '');
    final int boundedLimit = limit <= 0 ? 50 : limit;
    final int boundedOffset = offset < 0 ? 0 : offset;

    final String queryLike = '%$normalizedQuery%';
    final String tagLike = '%;$normalizedTag;%';

    final List<QueryRow> rows = await _db.customSelect(
      '''
select *
from words
where upper(coalesce(level, '')) = ?1
  and (?2 = '' or en_word_normalized like ?3 or search_key like ?3)
  and (?4 = '' or (';' || replace(replace(lower(coalesce(pos, '')), ',', ';'), ' ', '') || ';') like ?5)
  and (?6 = '' or (';' || replace(replace(lower(coalesce(tags_raw, '')), ',', ';'), ' ', '') || ';') like ?7)
order by lower(en_word) asc, en_word asc
limit ?8 offset ?9
      ''',
      variables: <Variable<Object>>[
        Variable<String>(normalizedLevel),
        Variable<String>(normalizedQuery),
        Variable<String>(queryLike),
        Variable<String>(normalizedPos),
        Variable<String>(normalizedPosLike),
        Variable<String>(normalizedTag),
        Variable<String>(tagLike),
        Variable<int>(boundedLimit + 1),
        Variable<int>(boundedOffset),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentWords
      },
    ).get();

    final bool hasMore = rows.length > boundedLimit;
    final List<QueryRow> sliced =
        hasMore ? rows.take(boundedLimit).toList() : rows;
    final List<WordItem> items =
        sliced.map(_wordFromQueryRow).toList(growable: false);

    return PagedResult<WordItem>(
      items: items,
      hasMore: hasMore,
      nextOffset: boundedOffset + items.length,
    );
  }

  Future<WordItem?> getWordByEnWordGlobal(String enWord) async {
    final String normalizedWord = _normalize(enWord);
    if (normalizedWord.isEmpty) {
      return null;
    }

    final List<AppContentWord> rows = await (_db.select(_db.appContentWords)
          ..where((tbl) => tbl.enWordNormalized.equals(normalizedWord))
          ..limit(1))
        .get();
    if (rows.isEmpty) {
      return null;
    }
    return _wordFromData(rows.first);
  }

  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  }) async {
    final String normalizedPackId = packId.trim();
    final int boundedLimit = limit <= 0 ? 20 : limit;
    final int boundedOffset = offset < 0 ? 0 : offset;
    final List<String> normalizedLevels = (levels ?? <String>{})
        .map((String e) => e.trim().toUpperCase())
        .where((String e) => e.isNotEmpty)
        .toList(growable: false);

    final List<Variable<Object>> variables = <Variable<Object>>[
      Variable<String>(normalizedPackId),
    ];
    final StringBuffer where = StringBuffer('where pack_id = ?1');

    if (normalizedLevels.isNotEmpty) {
      final List<String> placeholders = <String>[];
      for (final String level in normalizedLevels) {
        final int index = variables.length + 1;
        variables.add(Variable<String>(level));
        placeholders.add('?$index');
      }
      where.write(
          ' and upper(coalesce(level, \'\')) in (${placeholders.join(',')})');
    }

    final int limitIdx = variables.length + 1;
    variables.add(Variable<int>(boundedLimit + 1));
    final int offsetIdx = variables.length + 1;
    variables.add(Variable<int>(boundedOffset));

    final List<QueryRow> rows = await _db
        .customSelect(
          '''
select *
from reading_passages
$where
order by lower(title) asc, title asc
limit ?$limitIdx offset ?$offsetIdx
      ''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.appContentReadingPassages,
          },
        )
        .get();

    final bool hasMore = rows.length > boundedLimit;
    final List<QueryRow> sliced =
        hasMore ? rows.take(boundedLimit).toList() : rows;
    final List<ReadingPassage> items =
        sliced.map(_passageFromQueryRow).toList(growable: false);

    return PagedResult<ReadingPassage>(
      items: items,
      hasMore: hasMore,
      nextOffset: boundedOffset + items.length,
    );
  }

  Future<List<PassageSentence>> getSentences({
    required String passageId,
  }) async {
    final String normalized = passageId.trim();
    if (normalized.isEmpty) {
      return const <PassageSentence>[];
    }

    final List<AppContentReadingSentence> rows =
        await (_db.select(_db.appContentReadingSentences)
              ..where((tbl) => tbl.passageId.equals(normalized))
              ..orderBy([
                (tbl) => OrderingTerm.asc(tbl.idx),
              ]))
            .get();

    return rows.map(_sentenceFromData).toList(growable: false);
  }

  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  }) async {
    final List<PassageSentence> sentences =
        await getSentences(passageId: passageId);
    if (sentences.isEmpty) {
      return const <WordItem>[];
    }

    final List<String> candidates = extractPassageWordCandidates(
      sentences.map((PassageSentence s) => s.sentenceEn),
      max: limit * 4,
    );
    if (candidates.isEmpty) {
      return const <WordItem>[];
    }

    final List<WordItem> global = await getGlobalWordIndex(limit: 7000);
    final Set<String> candidateSet = candidates.map(_normalize).toSet();
    final List<WordItem> matched = <WordItem>[];
    for (final WordItem word in global) {
      if (candidateSet.contains(_normalize(word.enWord))) {
        matched.add(word);
      }
      if (matched.length >= limit) {
        break;
      }
    }
    return matched;
  }

  /// Returns all English sentences for all passages that belong to [packId].
  Future<List<String>> getAllSentencesByPack(String packId) async {
    final String normalized = packId.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final List<QueryRow> rows = await _db.customSelect(
      '''
select s.sentence_en
from reading_sentences s
inner join reading_passages p on p.id = s.passage_id
where p.pack_id = ?1
order by s.passage_id, s.idx
      ''',
      variables: <Variable<Object>>[Variable<String>(normalized)],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.appContentReadingSentences,
        _db.appContentReadingPassages,
      },
    ).get();

    return rows
        .map((QueryRow row) => row.read<String>('sentence_en'))
        .toList(growable: false);
  }

  /// Counts how many unique words from the global word pool appear in the
  /// reading passages of the given pack. This enables cross-pack word
  /// discovery: words linked to any pack via FK will still be counted
  /// for other packs if they appear in that pack's reading content.
  Future<int> getPassageWordCountByPack(String packId) async {
    final List<String> sentences = await getAllSentencesByPack(packId);
    if (sentences.isEmpty) {
      return 0;
    }

    // Extract all unique word candidates (no limit) from all pack sentences.
    final Set<String> candidateSet = <String>{};
    for (final String sentence in sentences) {
      final List<String> words = sentence
          .toLowerCase()
          .split(RegExp(r'[^a-z]+'))
          .map((String e) => e.trim())
          .where((String e) => e.length > 1)
          .toList(growable: false);
      for (final String word in words) {
        candidateSet.add(word);
      }
    }
    if (candidateSet.isEmpty) {
      return 0;
    }

    // Match candidates against the global word index.
    final List<WordItem> global = await getGlobalWordIndex(limit: 7000);
    int count = 0;
    for (final WordItem word in global) {
      if (candidateSet.contains(_normalize(word.enWord))) {
        count++;
      }
    }
    return count;
  }

  Pack _packFromQueryRow(QueryRow row) {
    return Pack(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      fromLang: row.read<String>('from_lang'),
      toLang: row.read<String>('to_lang'),
      wordCount: row.read<int>('word_count'),
    );
  }

  ReadingPassage _passageFromQueryRow(QueryRow row) {
    return ReadingPassage(
      id: row.read<String>('id'),
      packId: row.read<String?>('pack_id'),
      packName: row.read<String?>('pack_name'),
      title: row.read<String>('title'),
      level: row.read<String?>('level'),
      tagsRaw: row.read<String?>('tags_raw'),
      category: row.read<String?>('category'),
    );
  }

  PassageSentence _sentenceFromData(AppContentReadingSentence row) {
    return PassageSentence(
      id: row.id,
      passageId: row.passageId,
      passageTitle: row.passageTitle,
      idx: row.idx,
      sentenceEn: row.sentenceEn,
      sentenceTr: row.sentenceTr,
    );
  }

  WordItem _wordFromData(AppContentWord row) {
    return WordItem(
      id: row.id,
      packId: row.packId,
      enWord: row.enWord,
      trMeaning: row.trMeaning,
      pos: row.pos,
      exampleEn: row.exampleEn,
      exampleTr: row.exampleTr,
      synonymsRaw: row.synonymsRaw,
      antonymsRaw: row.antonymsRaw,
      level: row.level,
      tagsRaw: row.tagsRaw,
      notes: row.notes,
    );
  }

  WordItem _wordFromQueryRow(QueryRow row) {
    return WordItem(
      id: row.read<String>('id'),
      packId: row.read<String>('pack_id'),
      enWord: row.read<String>('en_word'),
      trMeaning: row.read<String>('tr_meaning'),
      pos: row.read<String>('pos'),
      exampleEn: row.read<String>('example_en'),
      exampleTr: row.read<String?>('example_tr'),
      synonymsRaw: row.read<String?>('synonyms_raw'),
      antonymsRaw: row.read<String?>('antonyms_raw'),
      level: row.read<String?>('level'),
      tagsRaw: row.read<String?>('tags_raw'),
      notes: row.read<String?>('notes'),
    );
  }

  String _normalize(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeTokenForContains(String value) {
    return _normalize(value).replaceAll(' ', '');
  }
}
