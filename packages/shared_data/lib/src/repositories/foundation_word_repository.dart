import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_store.dart';

class FoundationWordRepository implements WordRepository {
  const FoundationWordRepository.preview() : _database = null, _config = null;

  const FoundationWordRepository({
    LocalSyncStore? database,
    required AppConfig config,
  }) : _database = database,
       _config = config;

  final LocalSyncStore? _database;
  final AppConfig? _config;

  @override
  Future<List<WordEntry>> fetchWords({String? packId}) async {
    final localItems = await _readFromLocal(packId: packId);
    if (localItems.isNotEmpty) {
      return localItems;
    }

    final remoteItems = await _readFromRemote(packId: packId);
    if (remoteItems.isNotEmpty) {
      return remoteItems;
    }

    return const <WordEntry>[
      WordEntry(
        id: 'word-a',
        packId: 'pack-yds-001',
        enWord: 'a great deal of',
        trMeaning: 'çok miktarda',
        pos: 'prep.',
      ),
      WordEntry(
        id: 'word-b',
        packId: 'pack-business',
        enWord: 'benchmark',
        trMeaning: 'ölçüt',
        pos: 'n.',
      ),
      WordEntry(
        id: 'word-c',
        packId: 'pack-yds-001',
        enWord: 'allocate',
        trMeaning: 'tahsis etmek',
        pos: 'v.',
      ),
      WordEntry(
        id: 'word-d',
        packId: 'pack-business',
        enWord: 'revenue',
        trMeaning: 'gelir',
        pos: 'n.',
      ),
      WordEntry(
        id: 'word-e',
        packId: 'pack-academic',
        enWord: 'hypothesis',
        trMeaning: 'hipotez',
        pos: 'n.',
      ),
      WordEntry(
        id: 'word-f',
        packId: 'pack-travel',
        enWord: 'itinerary',
        trMeaning: 'seyahat planı',
        pos: 'n.',
      ),
      WordEntry(
        id: 'word-g',
        packId: 'pack-daily-speaking',
        enWord: 'catch up',
        trMeaning: 'hasret gidermek',
        pos: 'phr. v.',
      ),
      WordEntry(
        id: 'word-h',
        packId: 'pack-phrasal-verbs',
        enWord: 'turn down',
        trMeaning: 'reddetmek',
        pos: 'phr. v.',
      ),
    ];
  }

  @override
  Future<List<WordEntry>> fetchWordsByIds(Iterable<String> ids) async {
    final normalizedIds = ids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <WordEntry>[];
    }

    final localItems = await _readFromLocal();
    final localById = <String, WordEntry>{
      for (final item in localItems)
        if (normalizedIds.contains(item.id)) item.id: item,
    };
    final needsRemote =
        localById.length != normalizedIds.length ||
        localById.values.any((item) => !_hasRichMetadata(item));
    if (!needsRemote && localById.isNotEmpty) {
      return normalizedIds
          .map((id) => localById[id])
          .whereType<WordEntry>()
          .toList(growable: false);
    }

    final remoteItems = await _readFromRemoteByIds(normalizedIds);
    if (remoteItems.isNotEmpty) {
      return remoteItems;
    }

    return normalizedIds
        .map((id) => localById[id])
        .whereType<WordEntry>()
        .toList(growable: false);
  }

  Future<List<WordEntry>> _readFromLocal({String? packId}) async {
    final database = _database;
    if (database == null) {
      return const <WordEntry>[];
    }

    final words = await database.listContentEntities(
      scope: 'words',
      entityType: 'words',
    );
    return words
        .map((record) {
          final payload = _decodePayload(record.payloadJson);
          return WordEntry(
            id: payload['id']?.toString() ?? record.entityId,
            packId: payload['pack_id']?.toString() ?? '',
            enWord: payload['en_word']?.toString() ?? '',
            trMeaning: payload['tr_meaning']?.toString() ?? '',
            pos: payload['pos']?.toString() ?? '',
            exampleEn: payload['example_en']?.toString() ?? '',
            exampleTr: payload['example_tr']?.toString(),
            synonymsRaw: payload['synonyms_raw']?.toString(),
            antonymsRaw: payload['antonyms_raw']?.toString(),
            notes: payload['notes']?.toString(),
          );
        })
        .where(
          (item) =>
              item.id.isNotEmpty &&
              (packId == null || packId.isEmpty || item.packId == packId),
        )
        .toList(growable: false);
  }

  Future<List<WordEntry>> _readFromRemote({String? packId}) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <WordEntry>[];
    }

    await SupabaseBootstrap.initialize(config);
    var query = Supabase.instance.client
        .from('words')
        .select(
          'id,pack_id,en_word,tr_meaning,pos,example_en,example_tr,synonyms_raw,antonyms_raw,notes',
        );
    if (packId != null && packId.isNotEmpty) {
      query = query.eq('pack_id', packId);
    }
    final rows = (await query.order('en_word')) as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => WordEntry(
            id: row['id']?.toString() ?? '',
            packId: row['pack_id']?.toString() ?? '',
            enWord: row['en_word']?.toString() ?? '',
            trMeaning: row['tr_meaning']?.toString() ?? '',
            pos: row['pos']?.toString() ?? '',
            exampleEn: row['example_en']?.toString() ?? '',
            exampleTr: row['example_tr']?.toString(),
            synonymsRaw: row['synonyms_raw']?.toString(),
            antonymsRaw: row['antonyms_raw']?.toString(),
            notes: row['notes']?.toString(),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<WordEntry>> _readFromRemoteByIds(List<String> ids) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled || ids.isEmpty) {
      return const <WordEntry>[];
    }

    await SupabaseBootstrap.initialize(config);
    final rows =
        (await Supabase.instance.client
                .from('words')
                .select(
                  'id,pack_id,en_word,tr_meaning,pos,example_en,example_tr,synonyms_raw,antonyms_raw,notes',
                )
                .inFilter('id', ids)
                .order('en_word'))
            as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => WordEntry(
            id: row['id']?.toString() ?? '',
            packId: row['pack_id']?.toString() ?? '',
            enWord: row['en_word']?.toString() ?? '',
            trMeaning: row['tr_meaning']?.toString() ?? '',
            pos: row['pos']?.toString() ?? '',
            exampleEn: row['example_en']?.toString() ?? '',
            exampleTr: row['example_tr']?.toString(),
            synonymsRaw: row['synonyms_raw']?.toString(),
            antonymsRaw: row['antonyms_raw']?.toString(),
            notes: row['notes']?.toString(),
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  bool _hasRichMetadata(WordEntry item) {
    return item.exampleEn.trim().isNotEmpty ||
        (item.exampleTr?.trim().isNotEmpty ?? false) ||
        (item.synonymsRaw?.trim().isNotEmpty ?? false) ||
        (item.antonymsRaw?.trim().isNotEmpty ?? false) ||
        (item.notes?.trim().isNotEmpty ?? false);
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
}
