import 'package:shared_core/shared_core.dart';

abstract interface class AdminContentRepository {
  Future<AppResult<void>> setContentPublished({
    required String entityType,
    required String entityId,
    required bool isPublished,
  });
}
