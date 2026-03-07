import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/single_flight.dart';
import '../../core/utils/timed_memory_cache.dart';
import '../../domain/entities/pack.dart';
import '../../domain/repositories/pack_repository.dart';

class SupabasePackRepository implements PackRepository {
  SupabasePackRepository(this._client);

  final SupabaseClient _client;
  final TimedMemoryCache<String, List<Pack>> _packListCache =
      TimedMemoryCache<String, List<Pack>>(ttl: const Duration(minutes: 5));
  final SingleFlight<String, List<Pack>> _packListFlight =
      SingleFlight<String, List<Pack>>();

  @override
  Future<List<Pack>> getPacksWithWordCount() async {
    final List<Pack>? cached = _packListCache.get('all');
    if (cached != null) {
      return cached;
    }

    return _packListFlight.run('all', () async {
      final List<Pack>? fresh = _packListCache.get('all');
      if (fresh != null) {
        return fresh;
      }

      final List<Pack> packs = await _loadPackSummaries();
      _packListCache.put('all', packs);
      return packs;
    });
  }

  @override
  Future<Pack?> getPackById(String packId) async {
    final List<Pack>? cached = _packListCache.get('all');
    if (cached != null) {
      for (final Pack pack in cached) {
        if (pack.id == packId) {
          return pack;
        }
      }
    }

    final List<dynamic> rows =
        await _client.from('packs').select().eq('id', packId).limit(1);
    if (rows.isEmpty) {
      return null;
    }
    final Map<String, dynamic> data = Map<String, dynamic>.from(rows.first);
    final List<dynamic> words =
        await _client.from('words').select('id').eq('pack_id', packId);

    return Pack(
      id: packId,
      name: (data['name'] as String?) ?? 'Unknown',
      fromLang: (data['from_lang'] as String?) ?? 'en',
      toLang: (data['to_lang'] as String?) ?? 'tr',
      wordCount: words.length,
    );
  }

  Future<List<Pack>> _loadPackSummaries() async {
    try {
      final dynamic response = await _client.rpc('get_packs_with_word_count');
      return (response as List<dynamic>)
          .map((dynamic row) => _packFromSummaryRow(row as Map))
          .toList(growable: false);
    } catch (_) {
      final List<dynamic> rows =
          await _client.from('packs').select().order('name', ascending: true);

      final List<Pack> packs = <Pack>[];
      for (final dynamic row in rows) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(row as Map);
        final String packId = data['id'] as String;

        final List<dynamic> words =
            await _client.from('words').select('id').eq('pack_id', packId);

        packs.add(
          Pack(
            id: packId,
            name: (data['name'] as String?) ?? 'Unknown',
            fromLang: (data['from_lang'] as String?) ?? 'en',
            toLang: (data['to_lang'] as String?) ?? 'tr',
            wordCount: words.length,
          ),
        );
      }
      return packs;
    }
  }

  Pack _packFromSummaryRow(Map<dynamic, dynamic> row) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(row);
    return Pack(
      id: (data['id'] as String?) ?? '',
      name: (data['name'] as String?) ?? 'Unknown',
      fromLang: (data['from_lang'] as String?) ?? 'en',
      toLang: (data['to_lang'] as String?) ?? 'tr',
      wordCount: _asInt(data['word_count']),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
