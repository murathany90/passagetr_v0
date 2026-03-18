import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/student_providers.dart';

void main() {
  test(
    'studentReadingsProvider sorts passage numbers from small to large',
    () async {
      final container = ProviderContainer(
        overrides: [
          studentReadingRepositoryProvider.overrideWithValue(
            const _FakeReadingRepository(<ReadingPassage>[
              ReadingPassage(
                id: 'reading-120',
                title: '120-Advanced Topics',
                level: 'C1',
                category: 'Science',
              ),
              ReadingPassage(
                id: 'reading-7',
                title: '7-Starter Story',
                level: 'A1',
                category: 'Daily Life',
              ),
              ReadingPassage(
                id: 'reading-42',
                title: '42-Travel Notes',
                level: 'B1',
                category: 'Travel',
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      final readings = await container.read(studentReadingsProvider.future);

      expect(
        readings.map((reading) => reading.title).toList(growable: false),
        <String>['7-Starter Story', '42-Travel Notes', '120-Advanced Topics'],
      );
    },
  );

  test('studentWordSummaryProvider uses one shared snapshot', () async {
    final container = ProviderContainer(
      overrides: [
        studentWordRepositoryProvider.overrideWithValue(
          const _FakeWordRepository(<WordEntry>[
            WordEntry(
              id: 'word-1',
              packId: 'pack-1',
              enWord: 'alpha',
              trMeaning: 'alfa',
              pos: 'noun',
            ),
            WordEntry(
              id: 'word-2',
              packId: 'pack-1',
              enWord: 'beta',
              trMeaning: 'beta',
              pos: 'noun',
            ),
            WordEntry(
              id: 'word-3',
              packId: 'pack-2',
              enWord: 'gamma',
              trMeaning: 'gama',
              pos: 'noun',
            ),
          ]),
        ),
        studentProgressRepositoryProvider.overrideWithValue(
          const _FakeProgressRepository(
            wordProgress: <WordProgress>[
              WordProgress(wordId: 'word-1', mastery: 72, seenCount: 3),
              WordProgress(wordId: 'word-2', mastery: 28, seenCount: 1),
              WordProgress(wordId: 'external-word', mastery: 10, seenCount: 9),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(studentWordsProvider.future);
    await container.read(studentWordProgressProvider.notifier).load();

    final summary = container.read(studentWordSummaryProvider);

    expect(summary.totalCount, 3);
    expect(summary.studiedCount, 2);
    expect(summary.reviewCount, 1);
  });

  test(
    'studentContinueReadingSummaryProvider prioritizes in-progress items',
    () async {
      final container = ProviderContainer(
        overrides: [
          studentReadingRepositoryProvider.overrideWithValue(
            const _FakeReadingRepository(<ReadingPassage>[
              ReadingPassage(
                id: 'reading-complete',
                title: 'Completed Reading',
                level: 'B1',
                category: 'History',
              ),
              ReadingPassage(
                id: 'reading-active',
                title: 'Active Reading',
                level: 'B2',
                category: 'Science',
              ),
              ReadingPassage(
                id: 'reading-fresh',
                title: 'Fresh Reading',
                level: 'A2',
                category: 'Travel',
              ),
            ]),
          ),
          studentProgressRepositoryProvider.overrideWithValue(
            const _FakeProgressRepository(
              readingProgress: <ReadingProgress>[
                ReadingProgress(
                  passageId: 'reading-complete',
                  completed: true,
                  lastIndex: 25,
                ),
                ReadingProgress(
                  passageId: 'reading-active',
                  completed: false,
                  lastIndex: 4,
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(studentReadingsProvider.future);
      await container.read(studentReadingProgressProvider.notifier).load();

      final summary = container.read(studentContinueReadingSummaryProvider);

      expect(summary.reading.id, 'reading-active');
      expect(summary.progressPercent, 16);
      expect(summary.ctaLabel, 'Kaldığın Yerden Devam Et');
      expect(summary.isCompleted, isFalse);
    },
  );

  test(
    'studentContinueReadingSummaryProvider uses review CTA for completed reading',
    () async {
      final container = ProviderContainer(
        overrides: [
          studentReadingRepositoryProvider.overrideWithValue(
            const _FakeReadingRepository(<ReadingPassage>[
              ReadingPassage(
                id: 'reading-complete',
                title: 'Completed Reading',
                level: 'B1',
                category: 'History',
              ),
            ]),
          ),
          studentProgressRepositoryProvider.overrideWithValue(
            const _FakeProgressRepository(
              readingProgress: <ReadingProgress>[
                ReadingProgress(
                  passageId: 'reading-complete',
                  completed: true,
                  lastIndex: 25,
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(studentReadingsProvider.future);
      await container.read(studentReadingProgressProvider.notifier).load();

      final summary = container.read(studentContinueReadingSummaryProvider);

      expect(summary.reading.id, 'reading-complete');
      expect(summary.progressPercent, 100);
      expect(summary.ctaLabel, 'Gözden Geçir');
      expect(summary.isCompleted, isTrue);
    },
  );
}

class _FakeWordRepository implements WordRepository {
  const _FakeWordRepository(this.words);

  final List<WordEntry> words;

  @override
  Future<List<WordEntry>> fetchWords({String? packId}) async => words;

  @override
  Future<List<WordEntry>> fetchWordsByIds(Iterable<String> ids) async {
    final idSet = ids.toSet();
    return words
        .where((item) => idSet.contains(item.id))
        .toList(growable: false);
  }
}

class _FakeReadingRepository implements ReadingRepository {
  const _FakeReadingRepository(this.readings);

  final List<ReadingPassage> readings;

  @override
  Future<List<ReadingPassage>> fetchReadings() async => readings;

  @override
  Future<List<ReadingSentence>> fetchReadingSections(String passageId) async {
    return const <ReadingSentence>[];
  }

  @override
  Future<List<ReadingFocusWord>> fetchFocusWords(String passageId) async {
    return const <ReadingFocusWord>[];
  }

  @override
  Future<List<ReadingQuestion>> fetchQuestions(String passageId) async {
    return const <ReadingQuestion>[];
  }

  @override
  Future<String?> fetchSentenceTranslation(String passageId, int idx) async {
    return null;
  }
}

class _FakeProgressRepository implements ProgressRepository {
  const _FakeProgressRepository({
    this.wordProgress = const <WordProgress>[],
    this.readingProgress = const <ReadingProgress>[],
  });

  final List<WordProgress> wordProgress;
  final List<ReadingProgress> readingProgress;

  @override
  Future<AppResult<void>> enqueue(OutboxEvent event) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<List<GrammarProgress>> fetchGrammarProgress() async =>
      const <GrammarProgress>[];

  @override
  Future<List<ReadingProgress>> fetchReadingProgress() async => readingProgress;

  @override
  Future<List<WordProgress>> fetchWordProgress() async => wordProgress;
}
