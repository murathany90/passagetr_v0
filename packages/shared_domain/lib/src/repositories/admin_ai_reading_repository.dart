import 'package:shared_core/shared_core.dart';

import '../entities/admin_ai_reading_contracts.dart';

abstract interface class AdminAiReadingRepository {
  Future<AppResult<AdminAiGeneratedReadingDraft>> generateReadingDraft(
    AdminAiGenerateReadingRequest request,
  );
}
