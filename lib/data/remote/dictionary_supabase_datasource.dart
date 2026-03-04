import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/dictionary_text_normalizer.dart';
import '../../domain/entities/dictionary_entry.dart';

class DictionaryRemoteManifest {
  const DictionaryRemoteManifest({
    required this.datasetVersion,
    required this.batchId,
    required this.rowCount,
  });

  final String datasetVersion;
  final String? batchId;
  final int rowCount;
}

class DictionaryRemoteFallbackCacheEntry {
  const DictionaryRemoteFallbackCacheEntry({
    required this.queryText,
    required this.queryNormalized,
    required this.sourceLang,
    required this.targetLang,
    required this.provider,
    required this.translatedText,
  });

  final String queryText;
  final String queryNormalized;
  final String sourceLang;
  final String targetLang;
  final String provider;
  final String translatedText;
}

class DictionarySupabaseDataSource {
  DictionarySupabaseDataSource(this._client);

  final SupabaseClient _client;

  Future<DictionaryRemoteManifest> fetchManifest() async {
    final dynamic response = await _client.rpc('dictionary_bootstrap_manifest');
    if (response is! List || response.isEmpty) {
      return const DictionaryRemoteManifest(
        datasetVersion: '',
        batchId: null,
        rowCount: 0,
      );
    }

    final Map<String, dynamic> row =
        Map<String, dynamic>.from(response.first as Map);

    return DictionaryRemoteManifest(
      datasetVersion: (row['dataset_version'] as String? ?? '').trim(),
      batchId: (row['batch_id'] as String?)?.trim(),
      rowCount: _toInt(row['row_count']),
    );
  }

  Future<List<DictionaryEntry>> fetchEntriesPage({
    required int afterSeqId,
    int limit = 2000,
  }) async {
    final dynamic response = await _client.rpc(
      'dictionary_entries_bootstrap_page',
      params: <String, dynamic>{
        'p_after_seq_id': afterSeqId,
        'p_limit': limit,
      },
    );

    if (response is! List || response.isEmpty) {
      return const <DictionaryEntry>[];
    }

    return response
        .whereType<Map>()
        .map((Map row) => _entryFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<DictionaryRemoteFallbackCacheEntry?> getFallbackCache({
    required String queryNormalized,
    required String sourceLang,
    required String targetLang,
    String provider = 'deepl_edge_function',
  }) async {
    final String normalized = normalizeDictionaryQuery(queryNormalized);
    if (normalized.isEmpty) {
      return null;
    }

    final List<dynamic> rows = await _client
        .from('dictionary_fallback_cache')
        .select()
        .eq('query_normalized', normalized)
        .eq('source_lang', sourceLang)
        .eq('target_lang', targetLang)
        .eq('provider', provider)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    final Map<String, dynamic> row =
        Map<String, dynamic>.from(rows.first as Map);

    // Hit sayisini en azindan server tarafinda da guncel tut.
    final int hitCount = _toInt(row['hit_count']);
    try {
      await _client.from('dictionary_fallback_cache').update(<String, dynamic>{
        'hit_count': hitCount + 1,
        'last_hit_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', row['id']);
    } catch (_) {
      // Read yolunu bozmamak icin hit update hatasini yutariz.
    }

    return DictionaryRemoteFallbackCacheEntry(
      queryText: (row['query_text'] as String? ?? '').trim(),
      queryNormalized:
          (row['query_normalized'] as String? ?? normalized).trim(),
      sourceLang: (row['source_lang'] as String? ?? sourceLang).trim(),
      targetLang: (row['target_lang'] as String? ?? targetLang).trim(),
      provider: (row['provider'] as String? ?? provider).trim(),
      translatedText: (row['translated_text'] as String? ?? '').trim(),
    );
  }

  Future<void> upsertFallbackCache({
    required String queryText,
    required String queryNormalized,
    required String sourceLang,
    required String targetLang,
    required String provider,
    required String translatedText,
  }) async {
    final String normalized = normalizeDictionaryQuery(queryNormalized);
    if (normalized.isEmpty || translatedText.trim().isEmpty) {
      return;
    }

    await _client.from('dictionary_fallback_cache').upsert(
      <String, dynamic>{
        'query_text': queryText,
        'query_normalized': normalized,
        'source_lang': sourceLang,
        'target_lang': targetLang,
        'provider': provider,
        'translated_text': translatedText.trim(),
        'last_hit_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'query_normalized,source_lang,target_lang,provider',
    );
  }

  Future<void> bumpMissingQuery({
    required String queryText,
    required String queryNormalized,
    required String sourceLang,
    required String targetLang,
  }) async {
    final String normalized = normalizeDictionaryQuery(queryNormalized);
    if (normalized.isEmpty) {
      return;
    }

    final List<dynamic> rows = await _client
        .from('dictionary_missing_queries')
        .select()
        .eq('query_normalized', normalized)
        .eq('source_lang', sourceLang)
        .eq('target_lang', targetLang)
        .limit(1);

    if (rows.isEmpty) {
      await _client.from('dictionary_missing_queries').insert(
        <String, dynamic>{
          'query_text': queryText,
          'query_normalized': normalized,
          'source_lang': sourceLang,
          'target_lang': targetLang,
          'occurrence_count': 1,
          'first_seen_at': DateTime.now().toUtc().toIso8601String(),
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      return;
    }

    final Map<String, dynamic> row =
        Map<String, dynamic>.from(rows.first as Map);
    final int count = _toInt(row['occurrence_count']);

    await _client.from('dictionary_missing_queries').update(<String, dynamic>{
      'occurrence_count': count + 1,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', row['id']);
  }

  DictionaryEntry _entryFromRow(Map<String, dynamic> row) {
    return DictionaryEntry(
      id: (row['id'] as String? ?? '').trim(),
      seqId: _toInt(row['seq_id']),
      enWord: (row['en_word'] as String? ?? '').trim(),
      enWordNormalized: (row['en_word_normalized'] as String? ?? '').trim(),
      searchKey: (row['search_key'] as String? ?? '').trim(),
      pos: (row['pos'] as String?)?.trim(),
      trMeaning: (row['tr_meaning'] as String? ?? '').trim(),
      source: (row['source'] as String? ?? 'excel_import').trim(),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
