import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_store.dart';
import '../local/drift/local_sync_models.dart';

class FoundationReadingRepository implements ReadingRepository {
  const FoundationReadingRepository.preview()
    : _database = null,
      _config = null;

  const FoundationReadingRepository({
    LocalSyncStore? database,
    required AppConfig config,
  }) : _database = database,
       _config = config;

  final LocalSyncStore? _database;
  final AppConfig? _config;

  @override
  Future<List<ReadingPassage>> fetchReadings() async {
    try {
      final remoteItems = await _readFromRemote();
      if (remoteItems.isNotEmpty) {
        _syncReadingPassagesToLocal(remoteItems);
        return remoteItems;
      }
    } catch (_) {
      // Fallback to local
    }

    final localItems = await _readFromLocal();
    if (localItems.isNotEmpty) {
      return localItems;
    }

    return const <ReadingPassage>[
      ReadingPassage(
        id: 'reading-silent-ocean',
        title: 'The Silent Ocean',
        level: 'Zor',
        category: 'Bilim',
        packId: 'pack-yds-001',
        isPro: false,
      ),
      ReadingPassage(
        id: 'reading-brief-history',
        title: 'A Brief History of Time',
        level: 'Orta',
        category: 'Bilim',
        packId: 'pack-academic',
        isPro: false,
      ),
      ReadingPassage(
        id: 'reading-coffee-shops',
        title: 'Everyday English in Coffee Shops',
        level: 'Kolay',
        category: 'Gunluk Yasam',
        packId: 'pack-daily-speaking',
        isPro: false,
      ),
    ];
  }

  @override
  Future<List<ReadingSentence>> fetchReadingSections(String passageId) async {
    try {
      final remoteItems = await _readSectionsFromRemote(passageId);
      if (remoteItems.isNotEmpty) {
        _syncReadingSentencesToLocal(passageId, remoteItems);
        return remoteItems;
      }
    } catch (_) {
      // Fallback to local
    }

    final localItems = await _readSectionsFromLocal(passageId);
    if (localItems.isNotEmpty) {
      return localItems;
    }

    return const <ReadingSentence>[];
  }

  @override
  Future<List<ReadingFocusWord>> fetchFocusWords(String passageId) async {
    try {
      final remoteItems = await _readFocusWordsFromRemote(passageId);
      if (remoteItems.isNotEmpty) {
        _syncReadingFocusWordsToLocal(passageId, remoteItems);
        return remoteItems;
      }
    } catch (_) {
      // Fallback to local
    }

    final localItems = await _readFocusWordsFromLocal(passageId);
    if (localItems.isNotEmpty) {
      return localItems;
    }

    return const <ReadingFocusWord>[];
  }

  @override
  Future<List<ReadingQuestion>> fetchQuestions(String passageId) async {
    try {
      final remoteItems = await _readQuestionsFromRemote(passageId);
      if (remoteItems.isNotEmpty) {
        _syncReadingQuestionsToLocal(passageId, remoteItems);
        return remoteItems;
      }
    } catch (_) {
      // Fallback to local
    }

    final localItems = await _readQuestionsFromLocal(passageId);
    if (localItems.isNotEmpty) {
      return localItems;
    }

    return const <ReadingQuestion>[];
  }

  @override
  Future<String?> fetchSentenceTranslation(String passageId, int idx) async {
    final candidateIndexes = _candidateSentenceIndexes(idx);
    final database = _database;
    if (database != null) {
      final records = await database.listContentEntities(
        scope: 'readings',
        entityType: 'reading_passage_sentences',
      );
      for (final candidateIndex in candidateIndexes) {
        for (final record in records) {
          final payload = _decodePayload(record.payloadJson);
          final payloadIdx = _asInt(payload['idx']);
          if (payload['passage_id'] == passageId &&
              payloadIdx == candidateIndex) {
            final tr = payload['sentence_tr']?.toString();
            if (tr != null && tr.isNotEmpty) {
              return tr;
            }
          }
        }
      }
    }

    final config = _config;
    if (config != null && config.supabaseEnabled) {
      try {
        await SupabaseBootstrap.initialize(config);
        for (final candidateIndex in candidateIndexes) {
          final response = await Supabase.instance.client
              .from('reading_passage_sentences')
              .select('sentence_tr')
              .eq('passage_id', passageId)
              .eq('idx', candidateIndex)
              .maybeSingle();

          if (response != null && response['sentence_tr'] != null) {
            return response['sentence_tr'].toString();
          }
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Future<void> _syncReadingPassagesToLocal(List<ReadingPassage> passages) async {
    final database = _database;
    if (database == null) return;

    for (final item in passages) {
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'readings',
          entityType: 'reading_passages',
          entityId: item.id,
          payloadJson: jsonEncode({
            'id': item.id,
            'pack_id': item.packId,
            'title': item.title,
            'level': item.level,
            'category': item.category,
            'is_pro': item.isPro,
            'summary': item.summary,
            'question_count': item.questionCount,
            'cover_bucket_name': item.coverBucketName,
            'cover_storage_path': item.coverStoragePath,
            'cover_alt_text': item.coverAltText,
          }),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _syncReadingSentencesToLocal(
    String passageId,
    List<ReadingSentence> sentences,
  ) async {
    final database = _database;
    if (database == null) return;

    for (final item in sentences) {
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'readings',
          entityType: 'reading_passage_sentences',
          entityId: '${passageId}_${item.index}',
          payloadJson: jsonEncode({
            'passage_id': passageId,
            'idx': item.index,
            'sentence_en': item.englishText,
            'sentence_tr': item.turkishText,
          }),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _syncReadingFocusWordsToLocal(
    String passageId,
    List<ReadingFocusWord> focusWords,
  ) async {
    final database = _database;
    if (database == null) return;

    for (final item in focusWords) {
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'readings',
          entityType: 'reading_passage_words',
          entityId: '${passageId}_${item.wordId}',
          payloadJson: jsonEncode({
            'passage_id': passageId,
            'word_id': item.wordId,
          }),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> _syncReadingQuestionsToLocal(
    String passageId,
    List<ReadingQuestion> questions,
  ) async {
    final database = _database;
    if (database == null) return;

    for (final item in questions) {
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'readings',
          entityType: 'reading_passage_questions',
          entityId: item.id,
          payloadJson: jsonEncode({
            'id': item.id,
            'passage_id': passageId,
            'sort_order': item.sortOrder,
            'question': item.question,
            'options_json': jsonEncode(item.options),
            'correct_option_index': item.correctOptionIndex,
            'explanation': item.explanation,
            'is_published': true,
          }),
          updatedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<List<ReadingPassage>> _readFromLocal() async {
    final database = _database;
    if (database == null) {
      return const <ReadingPassage>[];
    }

    final readings = await database.listContentEntities(
      scope: 'readings',
      entityType: 'reading_passages',
    );
    final questionRecords = await database.listContentEntities(
      scope: 'readings',
      entityType: 'reading_passage_questions',
    );
    final questionCounts = <String, int>{};
    for (final record in questionRecords) {
      final payload = _decodePayload(record.payloadJson);
      if (payload['is_published'] == false) {
        continue;
      }
      final passageId = payload['passage_id']?.toString().trim();
      if (passageId == null || passageId.isEmpty) {
        continue;
      }
      questionCounts[passageId] = (questionCounts[passageId] ?? 0) + 1;
    }
    return readings
        .map((record) {
          final payload = _decodePayload(record.payloadJson);
          final passageId = payload['id']?.toString() ?? record.entityId;
          return ReadingPassage(
            id: passageId,
            title: payload['title']?.toString() ?? '',
            level: payload['level']?.toString(),
            category: payload['category']?.toString(),
            packId: payload['pack_id']?.toString(),
            summary: payload['summary']?.toString(),
            questionCount:
                (_asInt(payload['question_count']) ?? questionCounts[passageId]) ??
                0,
            coverBucketName: payload['cover_bucket_name']?.toString(),
            coverStoragePath: payload['cover_storage_path']?.toString(),
            coverAltText: payload['cover_alt_text']?.toString(),
            coverUrl: _coverUrlFor(
              payload['cover_bucket_name']?.toString(),
              payload['cover_storage_path']?.toString(),
            ),
            isPro: payload['is_pro'] as bool? ?? false,
          );
        })
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<ReadingPassage>> _readFromRemote() async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <ReadingPassage>[];
    }

    await SupabaseBootstrap.initialize(config);
    final client = Supabase.instance.client;
    List<dynamic> rows;
    try {
      rows =
          await client.rpc<dynamic>('student_list_reading_catalog')
              as List<dynamic>;
    } catch (_) {
      rows =
          (await client
                .from('reading_passages')
                .select(
                  'id,pack_id,title,level,category,is_pro,cover_bucket_name,cover_storage_path,cover_alt_text',
                )
                .order('title'))
              as List<dynamic>;
    }
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ReadingPassage(
            id: row['id']?.toString() ?? '',
            title: row['title']?.toString() ?? '',
            level: row['level']?.toString(),
            category: row['category']?.toString(),
            packId: row['pack_id']?.toString(),
            summary: row['summary']?.toString(),
            questionCount: (row['question_count'] as num?)?.toInt() ?? 0,
            coverBucketName: row['cover_bucket_name']?.toString(),
            coverStoragePath: row['cover_storage_path']?.toString(),
            coverAltText: row['cover_alt_text']?.toString(),
            coverUrl: _coverUrlFor(
              row['cover_bucket_name']?.toString(),
              row['cover_storage_path']?.toString(),
            ),
            isPro: row['is_pro'] as bool? ?? false,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  String? _coverUrlFor(String? bucketName, String? storagePath) {
    final bucket = bucketName?.trim();
    final path = storagePath?.trim();
    if (bucket == null || bucket.isEmpty || path == null || path.isEmpty) {
      return null;
    }

    final base = _config?.supabaseUrl.trim() ?? '';
    if (base.isEmpty) {
      return null;
    }

    final normalizedBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final encodedPath = path
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '$normalizedBase/storage/v1/object/public/$bucket/$encodedPath';
  }

  Future<List<ReadingSentence>> _readSectionsFromLocal(String passageId) async {
    final database = _database;
    if (database == null) {
      return const <ReadingSentence>[];
    }

    final records = await database.listContentEntities(
      scope: 'readings',
      entityType: 'reading_passage_sentences',
    );
    return _mapSentenceRecords(records, passageId);
  }

  Future<List<ReadingSentence>> _readSectionsFromRemote(
    String passageId,
  ) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <ReadingSentence>[];
    }

    await SupabaseBootstrap.initialize(config);
    final rows =
        (await Supabase.instance.client
                .from('reading_passage_sentences')
                .select('passage_id,idx,sentence_en,sentence_tr')
                .eq('passage_id', passageId)
                .order('idx'))
            as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ReadingSentence(
            passageId: row['passage_id']?.toString() ?? passageId,
            index: _asInt(row['idx']) ?? 0,
            englishText: row['sentence_en']?.toString() ?? '',
            turkishText: row['sentence_tr']?.toString(),
          ),
        )
        .where((item) => item.englishText.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((left, right) => left.index.compareTo(right.index));
  }

  Future<List<ReadingFocusWord>> _readFocusWordsFromLocal(
    String passageId,
  ) async {
    final database = _database;
    if (database == null) {
      return const <ReadingFocusWord>[];
    }

    final linkRecords = await database.listContentEntities(
      scope: 'readings',
      entityType: 'reading_passage_words',
    );
    final wordRecords = await database.listContentEntities(
      scope: 'words',
      entityType: 'words',
    );
    final wordsById = <String, Map<String, dynamic>>{
      for (final record in wordRecords)
        record.entityId: _decodePayload(record.payloadJson),
    };

    final links =
        linkRecords
            .where((record) {
              final payload = _decodePayload(record.payloadJson);
              return payload['passage_id']?.toString() == passageId;
            })
            .toList(growable: false)
          ..sort((left, right) {
            final timestampComparison = left.updatedAt.compareTo(
              right.updatedAt,
            );
            if (timestampComparison != 0) {
              return timestampComparison;
            }
            return left.entityId.compareTo(right.entityId);
          });

    return _mapFocusWordsFromLocalLinks(links, wordsById);
  }

  Future<List<ReadingFocusWord>> _readFocusWordsFromRemote(
    String passageId,
  ) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <ReadingFocusWord>[];
    }

    await SupabaseBootstrap.initialize(config);
    final client = Supabase.instance.client;
    final linkRows =
        (await client
                .from('reading_passage_words')
                .select('word_id,created_at')
                .eq('passage_id', passageId)
                .order('created_at'))
            as List<dynamic>;

    final links = linkRows.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );
    if (links.isEmpty) {
      return const <ReadingFocusWord>[];
    }

    final wordIds = links
        .map((row) => row['word_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (wordIds.isEmpty) {
      return const <ReadingFocusWord>[];
    }

    final wordRows =
        (await client
                .from('words')
                .select('id,en_word,tr_meaning,pos')
                .inFilter('id', wordIds))
            as List<dynamic>;
    final wordsById = <String, Map<String, dynamic>>{
      for (final row in wordRows.whereType<Map<String, dynamic>>())
        row['id']?.toString() ?? '': row,
    }..remove('');

    return _mapFocusWordsFromRemoteLinks(links, wordsById);
  }

  Future<List<ReadingQuestion>> _readQuestionsFromLocal(
    String passageId,
  ) async {
    final database = _database;
    if (database == null) {
      return const <ReadingQuestion>[];
    }

    final records = await database.listContentEntities(
      scope: 'readings',
      entityType: 'reading_passage_questions',
    );
    return _mapQuestionRecords(records, passageId);
  }

  Future<List<ReadingQuestion>> _readQuestionsFromRemote(
    String passageId,
  ) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <ReadingQuestion>[];
    }

    await SupabaseBootstrap.initialize(config);
    final rows =
        (await Supabase.instance.client
                .from('reading_passage_questions')
                .select(
                  'id,passage_id,sort_order,question,options_json,correct_option_index,explanation,is_published',
                )
                .eq('passage_id', passageId)
                .eq('is_published', true)
                .order('sort_order'))
            as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(_questionFromPayload)
        .whereType<ReadingQuestion>()
        .toList(growable: false)
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  }

  Map<String, dynamic> _decodePayload(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }

  // DB'deki `reading_passage_sentences.idx` sütunu 1-tabanlıdır.
  // `idx` (metod parametresi) 0-tabanlı cümle indeksidir; 1 eklenerek
  // DB değerine dönüştürülür. Backcompat için ikinci deneme (0-tabanlı)
  // korunmaktadır; şema kesinleşince bu yedek kaldırılabilir.
  List<int> _candidateSentenceIndexes(int idx) {
    if (idx < 0) {
      return const <int>[];
    }
    final oneBasedIndex = idx + 1;
    if (idx == 0) {
      return <int>[oneBasedIndex];
    }

    // Önce doğru 1-tabanlı index, bulunamazsa eski 0-tabanlı (backcompat).
    return <int>[oneBasedIndex, idx];
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    if (value is num) {
      return value != 0;
    }
    return false;
  }

  List<ReadingSentence> _mapSentenceRecords(
    List<ContentEntityRecord> records,
    String passageId,
  ) {
    return records
        .map((record) => _decodePayload(record.payloadJson))
        .where((payload) => payload['passage_id']?.toString() == passageId)
        .map(
          (payload) => ReadingSentence(
            passageId: payload['passage_id']?.toString() ?? passageId,
            index: _asInt(payload['idx']) ?? 0,
            englishText: payload['sentence_en']?.toString() ?? '',
            turkishText: payload['sentence_tr']?.toString(),
          ),
        )
        .where((item) => item.englishText.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((left, right) => left.index.compareTo(right.index));
  }

  List<ReadingFocusWord> _mapFocusWordsFromLocalLinks(
    List<ContentEntityRecord> links,
    Map<String, Map<String, dynamic>> wordsById,
  ) {
    return links
        .map((record) {
          final payload = _decodePayload(record.payloadJson);
          final wordId = payload['word_id']?.toString() ?? '';
          if (wordId.isEmpty) {
            return null;
          }
          final wordPayload = wordsById[wordId];
          if (wordPayload == null) {
            return null;
          }
          return _focusWordFromPayload(wordId, wordPayload);
        })
        .whereType<ReadingFocusWord>()
        .toList(growable: false);
  }

  List<ReadingFocusWord> _mapFocusWordsFromRemoteLinks(
    List<Map<String, dynamic>> links,
    Map<String, Map<String, dynamic>> wordsById,
  ) {
    return links
        .map((payload) {
          final wordId = payload['word_id']?.toString() ?? '';
          if (wordId.isEmpty) {
            return null;
          }
          final wordPayload = wordsById[wordId];
          if (wordPayload == null) {
            return null;
          }
          return _focusWordFromPayload(wordId, wordPayload);
        })
        .whereType<ReadingFocusWord>()
        .toList(growable: false);
  }

  List<ReadingQuestion> _mapQuestionRecords(
    List<ContentEntityRecord> records,
    String passageId,
  ) {
    return records
        .map((record) => _decodePayload(record.payloadJson))
        .where((payload) => payload['passage_id']?.toString() == passageId)
        .where(
          (payload) =>
              payload['is_published'] == null ||
              _asBool(payload['is_published']),
        )
        .map(_questionFromPayload)
        .whereType<ReadingQuestion>()
        .where((item) => item.passageId == passageId)
        .toList(growable: false)
      ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  }

  ReadingFocusWord? _focusWordFromPayload(
    String wordId,
    Map<String, dynamic> payload,
  ) {
    final enWord = payload['en_word']?.toString().trim() ?? '';
    final trMeaning = payload['tr_meaning']?.toString().trim() ?? '';
    if (enWord.isEmpty || trMeaning.isEmpty) {
      return null;
    }

    return ReadingFocusWord(
      wordId: wordId,
      enWord: enWord,
      trMeaning: trMeaning,
      pos: payload['pos']?.toString().trim(),
    );
  }

  ReadingQuestion? _questionFromPayload(Map<String, dynamic> payload) {
    final passageId = payload['passage_id']?.toString().trim() ?? '';
    final question = payload['question']?.toString().trim() ?? '';
    final options = _readStringList(
      payload['options_json'] ?? payload['options'],
    );
    final correctOptionIndex = _asInt(payload['correct_option_index']) ?? -1;
    final isPublished = payload.containsKey('is_published')
        ? _asBool(payload['is_published'])
        : true;
    if (!isPublished ||
        passageId.isEmpty ||
        question.isEmpty ||
        options.length < 2 ||
        correctOptionIndex < 0 ||
        correctOptionIndex >= options.length) {
      return null;
    }

    return ReadingQuestion(
      id: payload['id']?.toString().trim().isNotEmpty == true
          ? payload['id']!.toString().trim()
          : '$passageId:${_asInt(payload['sort_order']) ?? 1}:$question',
      passageId: passageId,
      sortOrder: _asInt(payload['sort_order']) ?? 1,
      question: question,
      options: options,
      correctOptionIndex: correctOptionIndex,
      explanation: _nullableTrimmed(payload['explanation']?.toString()),
    );
  }

  List<String> _readStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        return const <String>[];
      }
    }
    return const <String>[];
  }

  String? _nullableTrimmed(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
