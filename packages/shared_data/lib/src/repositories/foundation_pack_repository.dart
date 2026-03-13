import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_store.dart';

typedef PackRemoteReader = Future<List<ContentPack>> Function();

class FoundationPackRepository implements PackRepository {
  const FoundationPackRepository.preview({
    PackRemoteReader? remoteReaderOverride,
  }) : _database = null,
       _config = null,
       _remoteReaderOverride = remoteReaderOverride;

  const FoundationPackRepository({
    LocalSyncStore? database,
    required AppConfig config,
    PackRemoteReader? remoteReaderOverride,
  }) : _database = database,
       _config = config,
       _remoteReaderOverride = remoteReaderOverride;

  final LocalSyncStore? _database;
  final AppConfig? _config;
  final PackRemoteReader? _remoteReaderOverride;

  @override
  Future<List<ContentPack>> fetchPacks() async {
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

    return const <ContentPack>[
      ContentPack(id: 'pack-yds-001', name: 'YDS İlk 1000', wordCount: 1000),
      ContentPack(id: 'pack-business', name: 'İş İngilizcesi', wordCount: 250),
      ContentPack(
        id: 'pack-academic',
        name: 'Akademik Kelimeler',
        wordCount: 500,
      ),
      ContentPack(id: 'pack-travel', name: 'Seyahat', wordCount: 120),
      ContentPack(
        id: 'pack-daily-speaking',
        name: 'Günlük Konuşma',
        wordCount: 300,
      ),
      ContentPack(
        id: 'pack-phrasal-verbs',
        name: 'Phrasal Verbs',
        wordCount: 150,
      ),
    ];
  }

  Future<List<ContentPack>> _readFromLocal() async {
    final database = _database;
    if (database == null) {
      return const <ContentPack>[];
    }

    final packs = await database.listContentEntities(
      scope: 'packs',
      entityType: 'packs',
    );
    if (packs.isEmpty) {
      return const <ContentPack>[];
    }

    final words = await database.listContentEntities(
      scope: 'words',
      entityType: 'words',
    );
    final wordCounts = <String, int>{};
    for (final record in words) {
      final payload = _decodePayload(record.payloadJson);
      final packId = payload['pack_id']?.toString();
      if (packId == null || packId.isEmpty) {
        continue;
      }
      wordCounts.update(packId, (value) => value + 1, ifAbsent: () => 1);
    }

    return packs
        .map((record) {
          final payload = _decodePayload(record.payloadJson);
          final id = payload['id']?.toString() ?? record.entityId;
          return ContentPack(
            id: id,
            name: payload['name']?.toString() ?? 'İsimsiz Paket',
            wordCount: wordCounts[id] ?? 0,
          );
        })
        .toList(growable: false);
  }

  Future<List<ContentPack>> _readFromRemote() async {
    final remoteReaderOverride = _remoteReaderOverride;
    if (remoteReaderOverride != null) {
      return remoteReaderOverride();
    }

    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <ContentPack>[];
    }

    await SupabaseBootstrap.initialize(config);
    final response = await Supabase.instance.client.rpc<dynamic>(
      'get_packs_with_word_count',
    );
    final rows = response as List<dynamic>? ?? const <dynamic>[];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ContentPack(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? 'İsimsiz Paket',
            wordCount: (row['word_count'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
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
