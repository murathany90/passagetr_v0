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
  Future<AppResult<AdminPackDetail>> fetchPackDetail({
    required String packId,
  }) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminPackDetail>(
        AdminPackDetail(
          metadata: AdminContentMetadata(id: packId),
          name: 'Preview Pack',
        ),
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_get_pack_detail',
        params: <String, dynamic>{'p_pack_id': packId},
      );
      return AppSuccess<AdminPackDetail>(AdminPackDetail.fromJson(payload));
    } catch (error) {
      return AppFailure<AdminPackDetail>('Paket detayi yuklenemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> upsertPack({
    String? packId,
    required String name,
    required bool isPublished,
  }) async {
    final result = await upsertPackDetail(
      AdminPackDetail(
        metadata: AdminContentMetadata(id: _normalizedId(packId)),
        name: name,
        isPublished: isPublished,
      ),
    );
    return switch (result) {
      AppSuccess<AdminPackDetail>() => const AppSuccess<void>(null),
      AppFailure<AdminPackDetail>() => AppFailure<void>(result.message),
    };
  }

  @override
  Future<AppResult<AdminPackDetail>> upsertPackDetail(
    AdminPackDetail detail,
  ) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminPackDetail>(detail);
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_upsert_pack_detail',
        params: <String, dynamic>{'p_payload': detail.toJson()},
      );
      return AppSuccess<AdminPackDetail>(AdminPackDetail.fromJson(payload));
    } catch (error) {
      return AppFailure<AdminPackDetail>('Paket kaydedilemedi: $error');
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
  Future<AppResult<AdminWordDetail>> fetchWordDetail({
    required String wordId,
  }) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminWordDetail>(
        AdminWordDetail(metadata: AdminContentMetadata(id: wordId)),
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_get_word_detail',
        params: <String, dynamic>{'p_word_id': wordId},
      );
      return AppSuccess<AdminWordDetail>(AdminWordDetail.fromJson(payload));
    } catch (error) {
      return AppFailure<AdminWordDetail>('Kelime detayi yuklenemedi: $error');
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
    final result = await upsertWordDetail(
      AdminWordDetail(
        metadata: AdminContentMetadata(id: _normalizedId(wordId)),
        packId: packId,
        enWord: enWord,
        trMeaning: trMeaning,
        pos: pos,
        exampleEn: exampleEn,
        exampleTr: _normalizedValue(exampleTr),
        level: _normalizedValue(level),
        notes: _normalizedValue(notes),
        isPublished: isPublished,
      ),
    );
    return switch (result) {
      AppSuccess<AdminWordDetail>() => const AppSuccess<void>(null),
      AppFailure<AdminWordDetail>() => AppFailure<void>(result.message),
    };
  }

  @override
  Future<AppResult<AdminWordDetail>> upsertWordDetail(
    AdminWordDetail detail,
  ) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminWordDetail>(detail);
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_upsert_word_detail',
        params: <String, dynamic>{'p_payload': detail.toJson()},
      );
      return AppSuccess<AdminWordDetail>(AdminWordDetail.fromJson(payload));
    } catch (error) {
      return AppFailure<AdminWordDetail>('Kelime kaydedilemedi: $error');
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
  Future<AppResult<void>> importReadings({
    required List<AdminReadingDetail> items,
  }) async {
    if (items.isEmpty) {
      return const AppFailure<void>('En az bir okuma kaydi gerekli.');
    }
    if (!_config.supabaseEnabled) {
      return const AppSuccess<void>(null);
    }

    try {
      await _invokeVoidRpc(
        'admin_import_readings',
        params: <String, dynamic>{
          'p_payload': items.map((item) => item.toJson()).toList(growable: false),
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Okuma CSV import tamamlanamadi: $error');
    }
  }

  @override
  Future<AppResult<AdminReadingDetail>> fetchReadingDetail({
    required String readingId,
  }) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminReadingDetail>(
        AdminReadingDetail(metadata: AdminContentMetadata(id: readingId)),
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_get_reading_detail',
        params: <String, dynamic>{'p_passage_id': readingId},
      );
      return AppSuccess<AdminReadingDetail>(AdminReadingDetail.fromJson(payload));
    } catch (error) {
      return AppFailure<AdminReadingDetail>('Okuma detayi yuklenemedi: $error');
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
    required bool isPro,
    required bool isPublished,
  }) async {
    final result = await upsertReadingDetail(
      AdminReadingDetail(
        metadata: AdminContentMetadata(id: _normalizedId(readingId)),
        packId: _normalizedId(packId),
        title: title,
        level: _normalizedValue(level),
        category: _normalizedValue(category),
        tagsRaw: _normalizedValue(tagsRaw),
        isPro: isPro,
        isPublished: isPublished,
      ),
    );
    return switch (result) {
      AppSuccess<AdminReadingDetail>() => const AppSuccess<void>(null),
      AppFailure<AdminReadingDetail>() => AppFailure<void>(result.message),
    };
  }

  @override
  Future<AppResult<AdminReadingDetail>> upsertReadingDetail(
    AdminReadingDetail detail,
  ) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminReadingDetail>(detail);
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_upsert_reading_detail',
        params: <String, dynamic>{'p_payload': detail.toJson()},
      );
      return AppSuccess<AdminReadingDetail>(AdminReadingDetail.fromJson(payload));
    } catch (error) {
      return AppFailure<AdminReadingDetail>('Okuma kaydedilemedi: $error');
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
  Future<AppResult<AdminGrammarModuleDetail>> fetchGrammarModuleDetail({
    required int moduleId,
  }) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminGrammarModuleDetail>(
        AdminGrammarModuleDetail(
          metadata: AdminContentMetadata(id: moduleId.toString()),
        ),
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_get_grammar_module_detail',
        params: <String, dynamic>{'p_module_id': moduleId},
      );
      return AppSuccess<AdminGrammarModuleDetail>(
        AdminGrammarModuleDetail.fromJson(payload),
      );
    } catch (error) {
      return AppFailure<AdminGrammarModuleDetail>(
        'Gramer modulu detayi yuklenemedi: $error',
      );
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
    final result = await upsertGrammarModuleDetail(
      AdminGrammarModuleDetail(
        metadata: AdminContentMetadata(id: moduleId?.toString()),
        sortOrder: sortOrder ?? 1,
        title: title,
        fileName: fileName,
        icon: icon,
        color: color,
        isPublished: isPublished,
      ),
    );
    return switch (result) {
      AppSuccess<AdminGrammarModuleDetail>() => const AppSuccess<void>(null),
      AppFailure<AdminGrammarModuleDetail>() => AppFailure<void>(result.message),
    };
  }

  @override
  Future<AppResult<AdminGrammarModuleDetail>> upsertGrammarModuleDetail(
    AdminGrammarModuleDetail detail,
  ) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminGrammarModuleDetail>(detail);
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_upsert_grammar_module_detail',
        params: <String, dynamic>{'p_payload': detail.toJson()},
      );
      return AppSuccess<AdminGrammarModuleDetail>(
        AdminGrammarModuleDetail.fromJson(payload),
      );
    } catch (error) {
      return AppFailure<AdminGrammarModuleDetail>(
        'Gramer modulu kaydedilemedi: $error',
      );
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

  Future<Map<String, dynamic>> _invokeJsonRpc(
    String functionName, {
    required Map<String, dynamic> params,
  }) async {
    await SupabaseBootstrap.initialize(_config);
    final response = await Supabase.instance.client.rpc<dynamic>(
      functionName,
      params: params,
    );
    return _coerceMap(response);
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

Map<String, dynamic> _coerceMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}
