import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

class FoundationAdminContentRepository implements AdminContentRepository {
  const FoundationAdminContentRepository({required AppConfig config})
    : _config = config;

  final AppConfig _config;

  @override
  Future<AppResult<void>> setContentPublished({
    required String entityType,
    required String entityId,
    required bool isPublished,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_set_content_publish_state',
        params: <String, dynamic>{
          'p_entity_type': entityType,
          'p_entity_id': entityId,
          'p_is_published': isPublished,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Icerik yayin durumu guncellenemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> upsertPack({
    String? packId,
    required String name,
    required bool isPublished,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_upsert_pack',
        params: <String, dynamic>{
          'p_pack_id': _normalizedId(packId),
          'p_name': name,
          'p_is_published': isPublished,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Paket kaydedilemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deletePack({required String packId}) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_delete_pack',
        params: <String, dynamic>{'p_pack_id': packId},
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Paket silinemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> upsertWord({
    String? wordId,
    required String packId,
    required String enWord,
    required String trMeaning,
    required String pos,
    required String exampleEn,
    String? exampleTr,
    String? level,
    String? notes,
    required bool isPublished,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_upsert_word',
        params: <String, dynamic>{
          'p_word_id': _normalizedId(wordId),
          'p_pack_id': packId,
          'p_en_word': enWord,
          'p_tr_meaning': trMeaning,
          'p_pos': pos,
          'p_example_en': exampleEn,
          'p_example_tr': _normalizedValue(exampleTr),
          'p_level': _normalizedValue(level),
          'p_notes': _normalizedValue(notes),
          'p_is_published': isPublished,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Kelime kaydedilemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deleteWord({required String wordId}) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_delete_word',
        params: <String, dynamic>{'p_word_id': wordId},
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Kelime silinemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> importWords({
    required String packId,
    required List<Map<String, dynamic>> rows,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_import_words',
        params: <String, dynamic>{'p_pack_id': packId, 'p_rows': rows},
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('CSV import tamamlanamadi: $error');
    }
  }

  @override
  Future<AppResult<void>> upsertReading({
    String? readingId,
    String? packId,
    String? packName,
    required String title,
    String? level,
    String? category,
    String? tagsRaw,
    required bool isPublished,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_upsert_reading_passage',
        params: <String, dynamic>{
          'p_passage_id': _normalizedId(readingId),
          'p_pack_id': _normalizedId(packId),
          'p_pack_name': _normalizedValue(packName),
          'p_title': title,
          'p_level': _normalizedValue(level),
          'p_category': _normalizedValue(category),
          'p_tags_raw': _normalizedValue(tagsRaw),
          'p_is_published': isPublished,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Okuma kaydedilemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deleteReading({required String readingId}) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_delete_reading_passage',
        params: <String, dynamic>{'p_passage_id': readingId},
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Okuma silinemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> upsertGrammarModule({
    int? moduleId,
    int? sortOrder,
    required String title,
    required String fileName,
    required int pageCount,
    required String icon,
    required String color,
    required bool isPublished,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_upsert_grammar_module',
        params: <String, dynamic>{
          'p_module_id': moduleId,
          'p_sira': sortOrder,
          'p_baslik': title,
          'p_dosya_adi': fileName,
          'p_toplam_sayfa': pageCount,
          'p_icon': icon,
          'p_renk': color,
          'p_is_published': isPublished,
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Gramer modulu kaydedilemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deleteGrammarModule({required int moduleId}) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_delete_grammar_module',
        params: <String, dynamic>{'p_module_id': moduleId},
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Gramer modulu silinemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> reorderGrammarModules({
    required List<int> moduleIdsInOrder,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_reorder_grammar_modules',
        params: <String, dynamic>{'p_module_ids': moduleIdsInOrder},
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Gramer sirasi guncellenemedi: $error');
    }
  }

  Future<void> _invokeVoidRpc(
    String functionName, {
    required Map<String, dynamic> params,
  }) async {
    await SupabaseBootstrap.initialize(_config);
    await Supabase.instance.client.rpc<void>(functionName, params: params);
  }

  String? _normalizedId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _normalizedValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
