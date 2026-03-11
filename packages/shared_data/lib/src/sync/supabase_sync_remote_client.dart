import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_models.dart';
import 'sync_remote_client.dart';

class SupabaseSyncRemoteClient implements SyncRemoteClient {
  const SupabaseSyncRemoteClient({required AppConfig config})
    : _config = config;

  final AppConfig _config;

  @override
  Future<bool> isAvailable() => _canUseRemote();

  @override
  Future<List<ContentEntityRecord>> bootstrapContentScope({
    required String scope,
  }) async {
    if (!await _canUseRemote()) {
      return const <ContentEntityRecord>[];
    }

    final client = Supabase.instance.client;
    return switch (scope) {
      'packs' => _mapRowsToContentEntities(
        scope: scope,
        entityType: 'packs',
        rows:
            (await client
                    .from('packs')
                    .select(
                      'id,name,from_lang,to_lang,is_published,is_pro,updated_at,created_at',
                    ))
                as List<dynamic>,
      ),
      'words' => _mapRowsToContentEntities(
        scope: scope,
        entityType: 'words',
        rows:
            (await client
                    .from('words')
                    .select(
                      'id,pack_id,en_word,tr_meaning,pos,example_en,example_tr,level,tags_raw,notes,is_published,is_pro,updated_at,created_at',
                    ))
                as List<dynamic>,
      ),
      'readings' => <ContentEntityRecord>[
        ..._mapRowsToContentEntities(
          scope: scope,
          entityType: 'reading_passages',
          rows: await _readingCatalogRows(client),
        ),
        ..._mapRowsToContentEntities(
          scope: scope,
          entityType: 'reading_passage_sentences',
          rows:
              (await client
                      .from('reading_passage_sentences')
                      .select(
                        'id,passage_id,idx,sentence_en,sentence_tr,created_at',
                      ))
                  as List<dynamic>,
        ),
        ..._mapRowsToContentEntities(
          scope: scope,
          entityType: 'reading_passage_words',
          rows:
              (await client
                      .from('reading_passage_words')
                      .select('passage_id,word_id,created_at'))
                  as List<dynamic>,
          entityIdBuilder: (row) =>
              '${row['passage_id'] ?? ''}:${row['word_id'] ?? ''}',
        ),
      ],
      'grammar' => <ContentEntityRecord>[
        ..._mapRowsToContentEntities(
          scope: scope,
          entityType: 'gramer_modulleri',
          rows:
              (await client
                      .from('gramer_modulleri')
                      .select(
                        'id,sira,baslik,dosya_adi,toplam_sayfa,icon,renk,is_published,is_pro,updated_at,created_at',
                      ))
                  as List<dynamic>,
        ),
        ..._mapRowsToContentEntities(
          scope: scope,
          entityType: 'gramer_sayfalari',
          rows:
              (await client
                      .from('gramer_sayfalari')
                      .select(
                        'id,modul_id,sayfa_no,baslik,icerik_html,kelime_sayisi,is_published,is_pro,updated_at,created_at',
                      ))
                  as List<dynamic>,
        ),
        ..._mapRowsToContentEntities(
          scope: scope,
          entityType: 'gramer_ornekler',
          rows:
              (await client
                      .from('gramer_ornekler')
                      .select(
                        'id,sayfa_id,sira,ingilizce,turkce,aciklama,is_published,is_pro,updated_at,created_at',
                      ))
                  as List<dynamic>,
        ),
        ..._mapRowsToContentEntities(
          scope: scope,
          entityType: 'gramer_testler',
          rows:
              (await client
                      .from('gramer_testler')
                      .select(
                        'id,sayfa_id,sira,soru,secenekler_json,dogru_cevap,aciklama,is_published,is_pro,updated_at,created_at',
                      ))
                  as List<dynamic>,
        ),
      ],
      _ => const <ContentEntityRecord>[],
    };
  }

  @override
  Future<List<ProgressSnapshotRecord>> fetchProgressSnapshots({
    required String entityType,
  }) async {
    if (!await _hasAuthenticatedSession()) {
      return const <ProgressSnapshotRecord>[];
    }

    final client = Supabase.instance.client;
    return switch (entityType) {
      'user_word_progress' => _mapRowsToProgressSnapshots(
        entityType: entityType,
        rows:
            (await client
                    .from('user_word_progress')
                    .select(
                      'word_id,mastery,seen_count,correct_count,wrong_count,last_seen_at,last_answer,updated_at',
                    ))
                as List<dynamic>,
        entityIdKey: 'word_id',
      ),
      'user_reading_progress' => _mapRowsToProgressSnapshots(
        entityType: entityType,
        rows:
            (await client
                    .from('user_reading_progress')
                    .select(
                      'passage_id,completed,last_idx,last_seen_at,updated_at',
                    ))
                as List<dynamic>,
        entityIdKey: 'passage_id',
      ),
      'user_grammar_progress' => _mapRowsToProgressSnapshots(
        entityType: entityType,
        rows:
            (await client
                    .from('user_grammar_progress')
                    .select(
                      'module_id,page_id,completed_pages,last_page_no,completed,updated_at',
                    ))
                as List<dynamic>,
        entityIdKey: 'module_id',
      ),
      _ => const <ProgressSnapshotRecord>[],
    };
  }

  @override
  Future<List<ContentDeltaRecord>> pullContentChanges({
    required String scope,
    required int afterId,
    int limit = 100,
  }) async {
    if (!await _canUseRemote()) {
      return const <ContentDeltaRecord>[];
    }

    try {
      final response = await Supabase.instance.client.rpc<dynamic>(
        'pull_content_changes',
        params: <String, dynamic>{
          'p_scope': scope,
          'p_after_id': afterId,
          'p_limit': limit,
        },
      );

      final rows = response as List<dynamic>? ?? const <dynamic>[];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(_mapContentDelta)
          .toList(growable: false);
    } catch (_) {
      return const <ContentDeltaRecord>[];
    }
  }

  @override
  Future<bool> applyOutboxEvent(SyncOutboxRecord record) async {
    if (!await _hasAuthenticatedSession()) {
      return false;
    }

    final payload = _decodePayload(record.payloadJson);

    switch (record.entityType) {
      case 'user_reading_progress':
        await Supabase.instance.client.rpc<void>(
          'apply_user_reading_progress_event',
          params: <String, dynamic>{
            'p_event_id': record.eventId,
            'p_passage_id': payload['passage_id'],
            'p_last_idx': payload['last_idx'] ?? 0,
            'p_completed': payload['completed'] ?? false,
          },
        );
        return true;
      case 'user_reading_bookmarks':
        await Supabase.instance.client.rpc<void>(
          'apply_user_bookmark_event',
          params: <String, dynamic>{
            'p_event_id': record.eventId,
            'p_passage_id': payload['passage_id'],
            'p_should_bookmark': payload['should_bookmark'] ?? false,
          },
        );
        return true;
      case 'user_reading_favorites':
        await Supabase.instance.client.rpc<void>(
          'apply_user_favorite_event',
          params: <String, dynamic>{
            'p_event_id': record.eventId,
            'p_passage_id': payload['passage_id'],
            'p_should_favorite': payload['should_favorite'] ?? false,
          },
        );
        return true;
      case 'user_word_progress':
        await Supabase.instance.client.rpc<void>(
          'apply_user_word_progress_event',
          params: <String, dynamic>{
            'p_event_id': record.eventId,
            'p_word_id': payload['word_id'],
            'p_answer': payload['answer'] ?? 'unsure',
            'p_seen_count_delta': payload['seen_count_delta'] ?? 1,
            'p_correct_count_delta': payload['correct_count_delta'] ?? 0,
            'p_wrong_count_delta': payload['wrong_count_delta'] ?? 0,
            'p_mastery_delta': payload['mastery_delta'] ?? 0,
          },
        );
        return true;
      case 'user_grammar_progress':
        await Supabase.instance.client.rpc<void>(
          'apply_user_grammar_progress_event',
          params: <String, dynamic>{
            'p_event_id': record.eventId,
            'p_module_id': payload['module_id'],
            'p_page_id': payload['page_id'],
            'p_last_page_no': payload['last_page_no'] ?? 0,
            'p_completed_pages': payload['completed_pages'] ?? 0,
            'p_completed': payload['completed'] ?? false,
          },
        );
        return true;
      case 'user_test_attempts':
        await Supabase.instance.client.rpc<void>(
          'apply_user_test_attempt_event',
          params: <String, dynamic>{
            'p_event_id': record.eventId,
            'p_source_type': payload['source_type'] ?? 'word',
            'p_source_id': payload['source_id'] ?? record.entityId,
            'p_score': payload['score'] ?? 0,
            'p_correct_count': payload['correct_count'] ?? 0,
            'p_wrong_count': payload['wrong_count'] ?? 0,
            'p_payload_json': payload['payload_json'] ?? payload,
          },
        );
        return true;
      default:
        throw UnsupportedError(
          'Unsupported outbox entity type: ${record.entityType}',
        );
    }
  }

  Future<bool> _canUseRemote() async {
    if (!_config.supabaseEnabled) {
      return false;
    }

    await SupabaseBootstrap.initialize(_config);
    return true;
  }

  Future<bool> _hasAuthenticatedSession() async {
    if (!await _canUseRemote()) {
      return false;
    }

    return Supabase.instance.client.auth.currentSession != null;
  }

  List<ContentEntityRecord> _mapRowsToContentEntities({
    required String scope,
    required String entityType,
    required List<dynamic> rows,
    String Function(Map<String, dynamic> row)? entityIdBuilder,
  }) {
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ContentEntityRecord(
            scope: scope,
            entityType: entityType,
            entityId:
                entityIdBuilder?.call(row) ??
                (row['id']?.toString() ?? row['seq_id']?.toString() ?? ''),
            payloadJson: jsonEncode(row),
            updatedAt: _readTimestamp(
              row['updated_at'] ?? row['changed_at'] ?? row['created_at'],
            ),
          ),
        )
        .where((record) => record.entityId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<dynamic>> _readingCatalogRows(SupabaseClient client) async {
    try {
      return await client.rpc<dynamic>('student_list_reading_catalog')
          as List<dynamic>;
    } catch (_) {
      return (await client
              .from('reading_passages')
              .select(
                'id,pack_id,title,level,category,tags_raw,is_published,is_pro,updated_at,created_at',
              ))
          as List<dynamic>;
    }
  }

  List<ProgressSnapshotRecord> _mapRowsToProgressSnapshots({
    required String entityType,
    required List<dynamic> rows,
    required String entityIdKey,
  }) {
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ProgressSnapshotRecord(
            entityType: entityType,
            entityId: row[entityIdKey]?.toString() ?? '',
            payloadJson: jsonEncode(row),
            updatedAt: _readTimestamp(
              row['updated_at'] ?? row['last_seen_at'] ?? row['created_at'],
            ),
          ),
        )
        .where((record) => record.entityId.isNotEmpty)
        .toList(growable: false);
  }

  ContentDeltaRecord _mapContentDelta(Map<String, dynamic> row) {
    return ContentDeltaRecord(
      changeId: (row['id'] as num).toInt(),
      scope: row['scope'] as String? ?? '',
      entityType: row['entity_type'] as String? ?? '',
      entityId: row['entity_id'] as String? ?? '',
      operation: row['operation'] as String? ?? '',
      payloadJson: jsonEncode(row['payload_json']),
      changedAt: _readTimestamp(row['changed_at']),
    );
  }

  Map<String, dynamic> _decodePayload(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const FormatException('Outbox payload must decode to a JSON object.');
  }

  DateTime _readTimestamp(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
    }

    return DateTime.now().toUtc();
  }
}
