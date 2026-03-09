import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_store.dart';

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

    final remoteItems = await _readFromRemote();
    if (remoteItems.isNotEmpty) {
      return remoteItems;
    }

    return const <ReadingPassage>[
      ReadingPassage(
        id: 'reading-silent-ocean',
        title: 'The Silent Ocean',
        level: 'Zor',
        category: 'Bilim',
      ),
      ReadingPassage(
        id: 'reading-brief-history',
        title: 'A Brief History of Time',
        level: 'Orta',
        category: 'Bilim',
      ),
      ReadingPassage(
        id: 'reading-coffee-shops',
        title: 'Everyday English in Coffee Shops',
        level: 'Kolay',
        category: 'Gunluk Yasam',
      ),
    ];
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
    final rows =
        (await Supabase.instance.client
                .from('reading_passages')
                .select('id,title,level,category')
                .order('title'))
            as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ReadingPassage(
            id: row['id']?.toString() ?? '',
            title: row['title']?.toString() ?? '',
            level: row['level']?.toString(),
            category: row['category']?.toString(),
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
