import 'dart:typed_data';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

class FoundationAdminContentRepository implements AdminContentRepository {
  const FoundationAdminContentRepository({
    required AppConfig config,
    required AuthRepository authRepository,
  }) : _config = config,
       _authRepository = authRepository;

  final AppConfig _config;
  final AuthRepository _authRepository;

  void _handleError(Object error) {
    if (error is PostgrestException) {
      if (error.code == '401' || error.code == '403') {
        _authRepository.notifySessionExpired();
      }
    } else if (error is AuthException) {
      if (error.statusCode == '401' || error.statusCode == '403') {
        _authRepository.notifySessionExpired();
      }
    }
  }

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
      _handleError(error);
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
      _handleError(error);
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
      _handleError(error);
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
      _handleError(error);
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
      _handleError(error);
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

    final normalizedDetail = _normalizeWordDetail(detail);
    if (normalizedDetail case AppFailure<AdminWordDetail>()) {
      return normalizedDetail;
    }
    final requestDetail =
        (normalizedDetail as AppSuccess<AdminWordDetail>).value;

    try {
      final payload = await _invokeJsonRpc(
        'admin_upsert_word_detail',
        params: <String, dynamic>{'p_payload': requestDetail.toJson()},
      );
      return AppSuccess<AdminWordDetail>(AdminWordDetail.fromJson(payload));
    } catch (error) {
      _handleError(error);
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
      _handleError(error);
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
      _handleError(error);
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
          'p_payload': items
              .map((item) => item.toJson())
              .toList(growable: false),
        },
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      _handleError(error);
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
      return AppSuccess<AdminReadingDetail>(
        AdminReadingDetail.fromJson(payload),
      );
    } catch (error) {
      _handleError(error);
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
      return AppSuccess<AdminReadingDetail>(
        AdminReadingDetail.fromJson(payload),
      );
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminReadingDetail>('Okuma kaydedilemedi: $error');
    }
  }

  @override
  Future<AppResult<AdminReadingDetail>> uploadReadingCover({
    required String readingId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? altText,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminReadingDetail>(
        'Preview modunda cover yukleme desteklenmiyor.',
      );
    }

    final normalizedReadingId = _normalizedId(readingId);
    if (normalizedReadingId == null) {
      return const AppFailure<AdminReadingDetail>('Reading ID zorunlu.');
    }
    if (bytes.isEmpty) {
      return const AppFailure<AdminReadingDetail>('Bos dosya yuklenemedi.');
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final existingResult = await fetchReadingDetail(readingId: normalizedReadingId);
      if (existingResult case AppFailure<AdminReadingDetail>()) {
        return AppFailure<AdminReadingDetail>(existingResult.message);
      }

      final existingDetail = (existingResult as AppSuccess<AdminReadingDetail>).value;
      final bucketName = 'reading-covers';
      final storagePath = _buildReadingCoverPath(
        readingId: normalizedReadingId,
        fileName: fileName,
      );

      await Supabase.instance.client.storage
          .from(bucketName)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: false),
          );

      try {
        final payload = await _invokeJsonRpc(
          'admin_set_reading_cover',
          params: <String, dynamic>{
            'p_payload': <String, dynamic>{
              'reading_id': normalizedReadingId,
              'bucket_name': bucketName,
              'storage_path': storagePath,
              'mime_type': mimeType,
              'alt_text': _normalizedValue(altText),
            },
          },
        );
        final detail = AdminReadingDetail.fromJson(payload);
        await _removeStoredCover(existingDetail.cover);
        return AppSuccess<AdminReadingDetail>(detail);
      } catch (error) {
      _handleError(error);
        await Supabase.instance.client.storage.from(bucketName).remove([
          storagePath,
        ]);
        return AppFailure<AdminReadingDetail>(
          'Cover kaydedilemedi: $error',
        );
      }
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminReadingDetail>('Cover yuklenemedi: $error');
    }
  }

  @override
  Future<AppResult<AdminReadingDetail>> removeReadingCover({
    required String readingId,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminReadingDetail>(
        'Preview modunda cover silme desteklenmiyor.',
      );
    }

    final normalizedReadingId = _normalizedId(readingId);
    if (normalizedReadingId == null) {
      return const AppFailure<AdminReadingDetail>('Reading ID zorunlu.');
    }

    try {
      final existingResult = await fetchReadingDetail(readingId: normalizedReadingId);
      if (existingResult case AppFailure<AdminReadingDetail>()) {
        return AppFailure<AdminReadingDetail>(existingResult.message);
      }
      final existingDetail = (existingResult as AppSuccess<AdminReadingDetail>).value;

      final payload = await _invokeJsonRpc(
        'admin_clear_reading_cover',
        params: <String, dynamic>{'p_passage_id': normalizedReadingId},
      );
      await _removeStoredCover(existingDetail.cover);
      return AppSuccess<AdminReadingDetail>(AdminReadingDetail.fromJson(payload));
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminReadingDetail>('Cover silinemedi: $error');
    }
  }

  @override
  Future<AppResult<AdminReadingDetail>> autoAssignReadingFocusWords({
    required String readingId,
    int limit = 10,
    bool replaceExisting = true,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminReadingDetail>(
        'Preview modunda otomatik odak kelime atama desteklenmiyor.',
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_autolink_reading_focus_words_v2',
        params: <String, dynamic>{
          'p_passage_id': readingId,
          'p_limit': limit,
          'p_replace_existing': replaceExisting,
        },
      );
      return AppSuccess<AdminReadingDetail>(
        AdminReadingDetail.fromJson(payload),
      );
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminReadingDetail>(
        'Odak kelimeler otomatik atanamadi: $error',
      );
    }
  }

  @override
  Future<AppResult<AdminBulkReadingFocusWordAssignmentResult>>
  autoAssignFocusWordsForAllReadings({
    int limit = 10,
    bool onlyMissing = true,
    bool includeUnpublished = true,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AdminBulkReadingFocusWordAssignmentResult>(
        'Preview modunda toplu odak kelime atama desteklenmiyor.',
      );
    }

    try {
      final payload = await _invokeJsonRpc(
        'admin_autolink_all_reading_focus_words_v2',
        params: <String, dynamic>{
          'p_limit': limit,
          'p_only_missing': onlyMissing,
          'p_include_unpublished': includeUnpublished,
        },
      );
      return AppSuccess<AdminBulkReadingFocusWordAssignmentResult>(
        AdminBulkReadingFocusWordAssignmentResult.fromJson(payload),
      );
    } catch (error) {
      _handleError(error);
      return AppFailure<AdminBulkReadingFocusWordAssignmentResult>(
        'Toplu odak kelime atama tamamlanamadi: $error',
      );
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
      _handleError(error);
      return AppFailure<void>('Okuma silinemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> setContentPublishedBulk({
    required String entityType,
    required List<String> entityIds,
    required bool isPublished,
  }) async {
    if (!_config.supabaseEnabled || entityIds.isEmpty) {
      return const AppSuccess<void>(null);
    }

    try {
      final futures = entityIds.map((id) => setContentPublished(
          entityType: entityType,
          entityId: id,
          isPublished: isPublished,
        ),
      );
      final results = await Future.wait(futures);
      final failure = results.whereType<AppFailure<void>>().firstOrNull;
      if (failure != null) return failure;
      return const AppSuccess<void>(null);
    } catch (error) {
      _handleError(error);
      return AppFailure<void>('Toplu yayin durumu guncellenemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deleteWordsBulk({required List<String> wordIds}) async {
    if (!_config.supabaseEnabled || wordIds.isEmpty) {
      return const AppSuccess<void>(null);
    }

    try {
      final futures = wordIds.map((id) => deleteWord(wordId: id));
      final results = await Future.wait(futures);
      final failure = results.whereType<AppFailure<void>>().firstOrNull;
      if (failure != null) return failure;
      return const AppSuccess<void>(null);
    } catch (error) {
      _handleError(error);
      return AppFailure<void>('Kelimeler toplu silinemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deleteReadingsBulk({required List<String> readingIds}) async {
    if (!_config.supabaseEnabled || readingIds.isEmpty) {
      return const AppSuccess<void>(null);
    }

    try {
      final futures = readingIds.map((id) => deleteReading(readingId: id));
      final results = await Future.wait(futures);
      final failure = results.whereType<AppFailure<void>>().firstOrNull;
      if (failure != null) return failure;
      return const AppSuccess<void>(null);
    } catch (error) {
      _handleError(error);
      return AppFailure<void>('Okumalar toplu silinemedi: $error');
    }
  }

  @override
  Future<AppResult<void>> deleteGrammarModulesBulk({
    required List<int> moduleIds,
  }) async {
    if (!_config.supabaseEnabled || moduleIds.isEmpty) {
      return const AppSuccess<void>(null);
    }

    try {
      final futures = moduleIds.map((id) => deleteGrammarModule(moduleId: id));
      final results = await Future.wait(futures);
      final failure = results.whereType<AppFailure<void>>().firstOrNull;
      if (failure != null) return failure;
      return const AppSuccess<void>(null);
    } catch (error) {
      _handleError(error);
      return AppFailure<void>('Gramer modulleri toplu silinemedi: $error');
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
      _handleError(error);
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
      AppFailure<AdminGrammarModuleDetail>() => AppFailure<void>(
        result.message,
      ),
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
      _handleError(error);
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
      _handleError(error);
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
      _handleError(error);
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

  AppResult<AdminWordDetail> _normalizeWordDetail(AdminWordDetail detail) {
    final rawPos = detail.pos.trim();
    final normalizedPos =
        normalizeAdminWordPos(rawPos) ?? normalizeAdminWordPos(detail.posRaw);
    if (normalizedPos == null) {
      return const AppFailure<AdminWordDetail>(
        'Kelime kaydedilemedi: POS gecersiz. Gecerli degerler: n., v., adj., adv., prep., conj., det., modal, NP, phr. v.',
      );
    }

    final resolvedPosRaw =
        _normalizedValue(detail.posRaw) ??
        (rawPos != normalizedPos ? rawPos : null);
    return AppSuccess<AdminWordDetail>(
      detail.copyWith(
        pos: normalizedPos,
        posRaw: resolvedPosRaw,
        clearPosRaw: resolvedPosRaw == null,
      ),
    );
  }

  String _buildReadingCoverPath({
    required String readingId,
    required String fileName,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final sanitizedName = fileName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-');
    final resolvedName = sanitizedName.isEmpty ? 'cover.png' : sanitizedName;
    return 'readings/$readingId/$now-$resolvedName';
  }

  Future<void> _removeStoredCover(AdminReadingCoverAsset cover) async {
    if (!cover.hasCover) {
      return;
    }

    final bucketName = cover.bucketName?.trim();
    final storagePath = cover.storagePath?.trim();
    if (bucketName == null ||
        bucketName.isEmpty ||
        storagePath == null ||
        storagePath.isEmpty) {
      return;
    }

    try {
      await Supabase.instance.client.storage.from(bucketName).remove([
        storagePath,
      ]);
    } catch (_) {
      // DB state is already updated; stale objects can be cleaned up later.
    }
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
