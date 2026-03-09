import 'package:shared_core/shared_core.dart';

import '../entities/grammar_progress.dart';
import '../entities/reading_progress.dart';
import '../entities/word_progress.dart';
import '../value_objects/outbox_event.dart';

abstract interface class ProgressRepository {
  Future<AppResult<void>> enqueue(OutboxEvent event);
  Future<List<WordProgress>> fetchWordProgress();
  Future<List<ReadingProgress>> fetchReadingProgress();
  Future<List<GrammarProgress>> fetchGrammarProgress();
}
