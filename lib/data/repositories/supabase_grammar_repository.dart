import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/grammar_example.dart';
import '../../domain/entities/grammar_mini_test.dart';
import '../../domain/entities/grammar_module.dart';
import '../../domain/entities/grammar_page.dart';
import '../../domain/entities/grammar_page_detail.dart';
import '../../domain/repositories/grammar_repository.dart';

class SupabaseGrammarRepository implements GrammarRepository {
  SupabaseGrammarRepository(this._client);

  final SupabaseClient _client;

  static const String _modulesCacheKey = 'grammar_modules_cache_v1';

  @override
  Future<List<GrammarModule>> getModules() async {
    try {
      final List<dynamic> rows = await _client
          .from('gramer_modulleri')
          .select()
          .order('sira', ascending: true);

      final List<GrammarModule> modules = rows
          .map((dynamic row) => _moduleFromRow(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);

      await _cacheModules(modules);
      return modules;
    } catch (_) {
      final List<GrammarModule> cached = await _readModulesFromCache();
      if (cached.isNotEmpty) {
        return cached;
      }
      rethrow;
    }
  }

  @override
  Future<List<GrammarPage>> getPagesByModule({
    required int modulId,
  }) async {
    final List<dynamic> rows = await _client
        .from('gramer_sayfalari')
        .select()
        .eq('modul_id', modulId)
        .order('sayfa_no', ascending: true);

    return rows
        .map((dynamic row) => _pageFromRow(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  @override
  Future<GrammarPageDetail> getPageDetail({
    required int sayfaId,
  }) async {
    final List<dynamic> pageRows =
        await _client.from('gramer_sayfalari').select().eq('id', sayfaId).limit(1);
    if (pageRows.isEmpty) {
      throw StateError('Gramer sayfasi bulunamadi: $sayfaId');
    }

    final GrammarPage page = _pageFromRow(
      Map<String, dynamic>.from(pageRows.first as Map),
    );

    final List<dynamic> exampleRows = await _client
        .from('gramer_ornekler')
        .select()
        .eq('sayfa_id', sayfaId)
        .order('sira', ascending: true);

    final List<GrammarExample> examples = exampleRows
        .map((dynamic row) => _exampleFromRow(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);

    final List<dynamic> testRows = await _client
        .from('gramer_testler')
        .select()
        .eq('sayfa_id', sayfaId)
        .order('sira', ascending: true);

    final List<GrammarMiniTest> tests = testRows
        .map((dynamic row) => _testFromRow(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);

    return GrammarPageDetail(
      page: page,
      examples: examples,
      tests: tests,
    );
  }

  Future<void> _cacheModules(List<GrammarModule> modules) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> payload = modules
        .map(
          (GrammarModule module) => <String, dynamic>{
            'id': module.id,
            'sira': module.sira,
            'baslik': module.baslik,
            'dosya_adi': module.dosyaAdi,
            'toplam_sayfa': module.toplamSayfa,
            'icon': module.icon,
            'renk': module.renk,
          },
        )
        .toList(growable: false);
    await prefs.setString(_modulesCacheKey, jsonEncode(payload));
  }

  Future<List<GrammarModule>> _readModulesFromCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_modulesCacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <GrammarModule>[];
    }
    final dynamic parsed = jsonDecode(raw);
    if (parsed is! List) {
      return const <GrammarModule>[];
    }
    return parsed
        .whereType<Map>()
        .map((Map row) => _moduleFromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  GrammarModule _moduleFromRow(Map<String, dynamic> row) {
    return GrammarModule(
      id: _toInt(row['id']),
      sira: _toInt(row['sira']),
      baslik: (row['baslik'] as String?) ?? '',
      dosyaAdi: (row['dosya_adi'] as String?) ?? '',
      toplamSayfa: _toInt(row['toplam_sayfa']),
      icon: ((row['icon'] as String?) ?? '📘').trim(),
      renk: ((row['renk'] as String?) ?? '#4776E6').trim(),
    );
  }

  GrammarPage _pageFromRow(Map<String, dynamic> row) {
    return GrammarPage(
      id: _toInt(row['id']),
      modulId: _toInt(row['modul_id']),
      sayfaNo: _toInt(row['sayfa_no']),
      baslik: (row['baslik'] as String?) ?? '',
      icerikHtml: (row['icerik_html'] as String?) ?? '',
      kelimeSayisi: _toInt(row['kelime_sayisi']),
    );
  }

  GrammarExample _exampleFromRow(Map<String, dynamic> row) {
    return GrammarExample(
      id: _toInt(row['id']),
      sayfaId: _toInt(row['sayfa_id']),
      sira: _toInt(row['sira']),
      ingilizce: (row['ingilizce'] as String?) ?? '',
      turkce: (row['turkce'] as String?) ?? '',
      aciklama: (row['aciklama'] as String?) ?? '',
    );
  }

  GrammarMiniTest _testFromRow(Map<String, dynamic> row) {
    final dynamic optionsRaw = row['secenekler_json'];
    final Map<String, String> options = <String, String>{};
    if (optionsRaw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in optionsRaw.entries) {
        final String key = entry.key.toString().trim();
        final String value = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty) {
          options[key] = value;
        }
      }
    }

    return GrammarMiniTest(
      id: _toInt(row['id']),
      sayfaId: _toInt(row['sayfa_id']),
      sira: _toInt(row['sira']),
      soru: (row['soru'] as String?) ?? '',
      secenekler: options,
      dogruCevap: (row['dogru_cevap'] as String?) ?? '',
      aciklama: (row['aciklama'] as String?) ?? '',
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
}


