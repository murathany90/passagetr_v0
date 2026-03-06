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
  test('wordLevelProgressProvider batches large progress queries', () async {
    final _BatchingWordRepository wordRepository = _BatchingWordRepository(
      levels: const <WordLevelSummary>[
        WordLevelSummary(level: 'A1', wordCount: 600),
      ],
      wordIdsByLevel: <String, List<String>>{
        'A1': List<String>.generate(600, (int index) => 'w$index'),
      },
    );
    final _RecordingProgressRepository progressRepository =
        _RecordingProgressRepository(
      seenWordIds: <String>{
        for (int index = 0; index < 120; index++) 'w$index',
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

    expect(result, hasLength(1));
    expect(result.first.level, 'A1');
    expect(result.first.wordCount, 600);
    expect(result.first.studiedWordCount, 120);
    expect(progressRepository.requestSizes, <int>[250, 250, 100]);
  });
}

class _BatchingWordRepository implements WordRepository {
  _BatchingWordRepository({
    required this.levels,
    required this.wordIdsByLevel,
  });

  final List<WordLevelSummary> levels;
  final Map<String, List<String>> wordIdsByLevel;

  @override
  Future<List<WordLevelSummary>> getLevelsWithWordCount() async => levels;

  @override
  Future<List<String>> getWordIdsByLevel(String level) async =>
      wordIdsByLevel[level] ?? const <String>[];

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
    required this.seenWordIds,
  });

  final Set<String> seenWordIds;
  final List<int> requestSizes = <int>[];

  @override
  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  }) async {
    requestSizes.add(wordIds.length);
    return <String, UserWordProgress>{
      for (final String wordId in wordIds)
        if (seenWordIds.contains(wordId))
          wordId: UserWordProgress(
            userId: 'u1',
            wordId: wordId,
            mastery: 10,
            seenCount: 1,
            correctCount: 1,
            wrongCount: 0,
            lastSeenAt: null,
            lastAnswer: 'known',
          ),
    };
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
