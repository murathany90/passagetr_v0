import 'package:shared_core/shared_core.dart';

import '../entities/admin_ai_reading_contracts.dart';
import '../entities/admin_console_contracts.dart';

abstract interface class AdminAiReadingRepository {
  Future<AppResult<AdminAiGeneratedReadingDraft>> generateReadingDraft(
    AdminAiGenerateReadingRequest request,
  );

  Future<AppResult<AdminAiGeneratedReadingQuestions>> generateReadingQuestions(
    AdminAiGenerateReadingQuestionsRequest request,
  );

  Future<AppResult<AdminReadingDetail>> generateReadingCover(
    AdminAiGenerateReadingCoverRequest request,
  );

  Future<AppResult<AdminAiCoverPoolStatus>> fetchAiCoverPoolStatus();

  Future<AppResult<AdminAiReadingRun>> createReadingAiRun(
    AdminAiReadingRunRequest request,
  );

  Future<AppResult<AdminAiReadingRun>> getReadingAiRun(String runId);

  Future<AppResult<List<AdminAiReadingRun>>> listActiveReadingAiRuns();

  Future<AppResult<AdminAiReadingRun>> processReadingAiRun({
    required String runId,
    int batchSize = 3,
  });

  Future<AppResult<AdminAiReadingRun>> controlReadingAiRun({
    required String runId,
    required String action,
    String? provider,
    String? model,
    int? questionCount,
  });
}
