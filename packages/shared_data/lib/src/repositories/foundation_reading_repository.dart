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
    final localItems = await _readFromLocal();
    if (localItems.isNotEmpty) {
      return localItems;
    }

    try {
      final remoteItems = await _readFromRemote();
      if (remoteItems.isNotEmpty) {
        return remoteItems;
      }
    } catch (_) {
      // Fall back to bundled preview content when the network path is unavailable.
    }

    return const <ReadingPassage>[
      ReadingPassage(
        id: 'reading-silent-ocean',
        title: 'The Silent Ocean',
        level: 'Zor',
        category: 'Bilim',
        isPro: false,
      ),
      ReadingPassage(
        id: 'reading-brief-history',
        title: 'A Brief History of Time',
        level: 'Orta',
        category: 'Bilim',
        isPro: false,
      ),
      ReadingPassage(
        id: 'reading-coffee-shops',
        title: 'Everyday English in Coffee Shops',
        level: 'Kolay',
        category: 'Gunluk Yasam',
        isPro: false,
      ),
    ];
  }

  @override
  Future<List<ReadingSentence>> fetchReadingSections(String passageId) async {
    final localItems = await _readSectionsFromLocal(passageId);
    if (localItems.isNotEmpty) {
      return localItems;
    }

    try {
      final remoteItems = await _readSectionsFromRemote(passageId);
      if (remoteItems.isNotEmpty) {
        return remoteItems;
      }
    } catch (_) {
      // Fall back to bundled preview content handled by the UI layer.
    }

    return const <ReadingSentence>[];
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

  Future<List<ReadingPassage>> _readFromLocal() async {
    final database = _database;
    if (database == null) {
      return const <ReadingPassage>[];
    }

    final readings = await database.listContentEntities(
      scope: 'readings',
      entityType: 'reading_passages',
    );
    return readings
        .map((record) {
          final payload = _decodePayload(record.payloadJson);
          return ReadingPassage(
            id: payload['id']?.toString() ?? record.entityId,
            title: payload['title']?.toString() ?? '',
            level: payload['level']?.toString(),
            category: payload['category']?.toString(),
            summary: payload['summary']?.toString(),
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
                  .select('id,title,level,category,is_pro')
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
            summary: row['summary']?.toString(),
            isPro: row['is_pro'] as bool? ?? false,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
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

  List<int> _candidateSentenceIndexes(int idx) {
    if (idx < 0) {
      return const <int>[];
    }
    final oneBasedIndex = idx + 1;
    if (idx == 0) {
      return <int>[oneBasedIndex];
    }

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
}
