import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/pack.dart';
import '../../domain/repositories/pack_repository.dart';

class SupabasePackRepository implements PackRepository {
  SupabasePackRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Pack>> getPacksWithWordCount() async {
    final List<dynamic> rows =
        await _client.from('packs').select().order('created_at');

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

  @override
  Future<Pack?> getPackById(String packId) async {
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
}
