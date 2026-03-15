import 'dart:typed_data';

import 'package:shared_core/shared_core.dart';
import '../entities/admin_console_contracts.dart';

abstract interface class AdminContentRepository {
  Future<AppResult<void>> setContentPublished({
    required String entityType,
    required String entityId,
    required bool isPublished,
  });

  Future<AppResult<AdminPackDetail>> fetchPackDetail({required String packId});

  Future<AppResult<void>> upsertPack({
    String? packId,
    required String name,
    required bool isPublished,
  });

  Future<AppResult<AdminPackDetail>> upsertPackDetail(AdminPackDetail detail);

  Future<AppResult<void>> deletePack({required String packId});

  Future<AppResult<AdminWordDetail>> fetchWordDetail({required String wordId});

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
  });

  Future<AppResult<AdminWordDetail>> upsertWordDetail(AdminWordDetail detail);

  Future<AppResult<void>> deleteWord({required String wordId});

  Future<AppResult<void>> importWords({
    required String packId,
    required List<Map<String, dynamic>> rows,
  });

  Future<AppResult<void>> importReadings({
    required List<AdminReadingDetail> items,
  });

  Future<AppResult<AdminReadingDetail>> fetchReadingDetail({
    required String readingId,
  });

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
  });

  Future<AppResult<AdminReadingDetail>> upsertReadingDetail(
    AdminReadingDetail detail,
  );

  Future<AppResult<AdminReadingDetail>> uploadReadingCover({
    required String readingId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? altText,
  });

  Future<AppResult<AdminReadingDetail>> removeReadingCover({
    required String readingId,
  });

  Future<AppResult<AdminReadingDetail>> autoAssignReadingFocusWords({
    required String readingId,
    int limit = 10,
    bool replaceExisting = true,
  });

  Future<AppResult<AdminBulkReadingFocusWordAssignmentResult>>
  autoAssignFocusWordsForAllReadings({
    int limit = 10,
    bool onlyMissing = true,
    bool includeUnpublished = true,
  });

  Future<AppResult<void>> deleteReading({required String readingId});

  Future<AppResult<AdminGrammarModuleDetail>> fetchGrammarModuleDetail({
    required int moduleId,
  });

  Future<AppResult<void>> upsertGrammarModule({
    int? moduleId,
    int? sortOrder,
    required String title,
    required String fileName,
    required int pageCount,
    required String icon,
    required String color,
    required bool isPublished,
  });

  Future<AppResult<AdminGrammarModuleDetail>> upsertGrammarModuleDetail(
    AdminGrammarModuleDetail detail,
  );

  Future<AppResult<void>> deleteGrammarModule({required int moduleId});

  Future<AppResult<void>> reorderGrammarModules({
    required List<int> moduleIdsInOrder,
  });
}
