import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/tag_count.dart';
import 'package:passagetr/domain/entities/user_word_progress.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/domain/entities/word_level_progress_summary.dart';
import 'package:passagetr/domain/entities/word_level_summary.dart';
import 'package:passagetr/domain/repositories/progress_repository.dart';
import 'package:passagetr/domain/repositories/word_repository.dart';
import 'package:passagetr/domain/value_objects/flashcard_answer.dart';
import 'package:passagetr/domain/value_objects/paged_result.dart';
import 'package:passagetr/state/progress_providers.dart';
import 'package:passagetr/state/word_providers.dart';

void main() {
  test('wordLevelProgressProvider uses aggregated studied counts', () async {
    final _BatchingWordRepository wordRepository = _BatchingWordRepository(
      levels: const <WordLevelSummary>[
        WordLevelSummary(level: 'A1', wordCount: 600),
        WordLevelSummary(level: 'B1', wordCount: 320),
      ],
    );
    final _RecordingProgressRepository progressRepository =
        _RecordingProgressRepository(
      studiedCounts: <String, int>{
        'A1': 120,
        'B1': 45,
      },
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        wordRepositoryProvider.overrideWith((Ref ref) => wordRepository),
        progressRepositoryProvider
            .overrideWith((Ref ref) => progressRepository),
      ],
    );
    addTearDown(container.dispose);

    final List<WordLevelProgressSummary> result =
        await container.read(wordLevelProgressProvider.future);

    expect(result, hasLength(2));
    expect(result.first.level, 'A1');
    expect(result.first.wordCount, 600);
    expect(result.first.studiedWordCount, 120);
    expect(result.last.level, 'B1');
    expect(result.last.studiedWordCount, 45);
    expect(progressRepository.requestedLevels, <String>['A1', 'B1']);
  });
}

class _BatchingWordRepository implements WordRepository {
  _BatchingWordRepository({
    required this.levels,
  });

  final List<WordLevelSummary> levels;

  @override
  Future<List<WordLevelSummary>> getLevelsWithWordCount() async => levels;

  @override
  Future<List<String>> getWordIdsByLevel(String level) async =>
      const <String>[];

  @override
  Future<List<String>> getDistinctPosValues({
    String? packId,
    String? level,
  }) async =>
      const <String>[];

  @override
  Future<WordItem?> getWordByEnWord({
    required String packId,
    required String enWord,
  }) async =>
      null;

  @override
  Future<WordItem?> getWordByEnWordGlobal(String enWord) async => null;

  @override
  Future<WordItem?> getWordById(String wordId) async => null;

  @override
  Future<List<WordItem>> getWordsByIds(List<String> wordIds) async =>
      const <WordItem>[];

  @override
  Future<PagedResult<WordItem>> getWordsByPack(
    String packId, {
    String? query,
    String? pos,
    String? tag,
    int limit = 50,
    int offset = 0,
  }) async =>
      const PagedResult<WordItem>(
        items: <WordItem>[],
        hasMore: false,
        nextOffset: 0,
      );

  @override
  Future<List<WordItem>> getSessionBatch(
    String packId, {
    int limit = 100,
    int offset = 0,
  }) async =>
      const <WordItem>[];

  @override
  Future<List<WordItem>> getGlobalWordIndex({int limit = 7000}) async =>
      const <WordItem>[];

  @override
  Future<List<TagCount>> getTagsByLevel(
    String level, {
    String? search,
  }) async =>
      const <TagCount>[];

  @override
  Future<PagedResult<WordItem>> getWordsByLevel({
    required String level,
    String? tag,
    String? query,
    String? pos,
    int limit = 50,
    int offset = 0,
  }) async =>
      const PagedResult<WordItem>(
        items: <WordItem>[],
        hasMore: false,
        nextOffset: 0,
      );
}

class _RecordingProgressRepository implements ProgressRepository {
  _RecordingProgressRepository({
    required this.studiedCounts,
  });

  final Map<String, int> studiedCounts;
  final List<String> requestedLevels = <String>[];

  @override
  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  }) async {
    return const <String, UserWordProgress>{};
  }

  @override
  Future<Map<String, int>> getStudiedWordCountByLevel({
    required List<String> levels,
  }) async {
    requestedLevels
      ..clear()
      ..addAll(levels);
    return studiedCounts;
  }

  @override
  Future<void> applyFlashcardResult({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {}

  @override
  Future<void> applyTestResult({
    required String wordId,
    required bool isCorrect,
  }) async {}

  @override
  Future<int> getTodayWordCount() async => 0;

  @override
  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  }) async =>
      const <String>[];
}
