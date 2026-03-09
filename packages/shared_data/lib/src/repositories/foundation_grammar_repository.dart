import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_store.dart';

class FoundationGrammarRepository implements GrammarRepository {
  const FoundationGrammarRepository.preview()
    : _database = null,
      _config = null;

  const FoundationGrammarRepository({
    LocalSyncStore? database,
    required AppConfig config,
  }) : _database = database,
       _config = config;

  final LocalSyncStore? _database;
  final AppConfig? _config;

  @override
  Future<List<GrammarModule>> fetchModules() async {
    final localItems = await _readFromLocal();
    if (localItems.isNotEmpty) {
      return localItems;
    }

    final remoteItems = await _readFromRemote();
    if (remoteItems.isNotEmpty) {
      return remoteItems;
    }

    return const <GrammarModule>[
      GrammarModule(id: 1, title: 'Temel Kavramlar', pageCount: 12),
      GrammarModule(id: 2, title: 'Tense System (Zamanlar)', pageCount: 45),
      GrammarModule(id: 3, title: 'Modals (Kiplikler)', pageCount: 20),
      GrammarModule(
        id: 4,
        title: 'Conditionals (Kosul Cumleleri)',
        pageCount: 18,
      ),
    ];
  }

  Future<List<GrammarModule>> _readFromLocal() async {
    final database = _database;
    if (database == null) {
      return const <GrammarModule>[];
    }

    final modules = await database.listContentEntities(
      scope: 'grammar',
      entityType: 'gramer_modulleri',
    );
    return modules
        .map((record) {
          final payload = _decodePayload(record.payloadJson);
          return GrammarModule(
            id: int.tryParse(payload['id']?.toString() ?? '') ?? 0,
            title: payload['baslik']?.toString() ?? '',
            pageCount: (payload['toplam_sayfa'] as num?)?.toInt() ?? 0,
          );
        })
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  Future<List<GrammarModule>> _readFromRemote() async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <GrammarModule>[];
    }

    await SupabaseBootstrap.initialize(config);
    final rows =
        (await Supabase.instance.client
                .from('gramer_modulleri')
                .select('id,baslik,toplam_sayfa')
                .order('sira'))
            as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => GrammarModule(
            id: (row['id'] as num?)?.toInt() ?? 0,
            title: row['baslik']?.toString() ?? '',
            pageCount: (row['toplam_sayfa'] as num?)?.toInt() ?? 0,
          ),
        )
        .where((item) => item.id > 0)
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
