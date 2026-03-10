import 'package:shared_core/shared_core.dart';

abstract interface class AdminContentRepository {
  Future<AppResult<void>> setContentPublished({
    required String entityType,
    required String entityId,
    required bool isPublished,
  });

  Future<AppResult<void>> upsertPack({
    String? packId,
    required String name,
    required bool isPublished,
  });

  Future<AppResult<void>> deletePack({required String packId});

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

  Future<AppResult<void>> deleteWord({required String wordId});

  Future<AppResult<void>> importWords({
    required String packId,
    required List<Map<String, dynamic>> rows,
  });

  Future<AppResult<void>> upsertReading({
    String? readingId,
    String? packId,
    String? packName,
    required String title,
    String? level,
    String? category,
    String? tagsRaw,
    required bool isPublished,
  });

  Future<AppResult<void>> deleteReading({required String readingId});

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

  Future<AppResult<void>> deleteGrammarModule({required int moduleId});

  Future<AppResult<void>> reorderGrammarModules({
    required List<int> moduleIdsInOrder,
  });
}
