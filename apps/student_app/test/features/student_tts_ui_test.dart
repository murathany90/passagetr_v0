import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/core/student_providers.dart';
import 'package:student_app/src/core/tts/student_tts_engine.dart';
import 'package:student_app/src/features/common/page_parts.dart';
import 'package:student_app/src/features/readings/reading_detail_page.dart';
import 'package:student_app/src/features/words/flashcards_page.dart';
import 'package:student_app/src/features/words/word_pack_detail_page.dart';

void main() {
  testWidgets('word pack detail row and popup expose TTS controls', (
    tester,
  ) async {
    final fakeTtsEngine = _FakeStudentTtsEngine();

    await _pumpStudentTtsApp(
      tester,
      initialLocation: '/words/packs/pack-1',
      routes: <RouteBase>[
        GoRoute(
          path: '/words/packs/:packId',
          builder: (context, state) => StudentWordPackDetailPage(
            packId: state.pathParameters['packId']!,
          ),
        ),
      ],
      overrides: <Override>[
        studentTtsEngineProvider.overrideWithValue(fakeTtsEngine),
        studentPackRepositoryProvider.overrideWithValue(
          const _FakePackRepository(<ContentPack>[
            ContentPack(id: 'pack-1', name: 'YDS Ilk 1000', wordCount: 1),
          ]),
        ),
        studentWordRepositoryProvider.overrideWithValue(
          const _FakeWordRepository(<WordEntry>[
            WordEntry(
              id: 'word-1',
              packId: 'pack-1',
              enWord: 'orbit',
              trMeaning: 'yorunge',
              pos: 'n.',
              exampleEn: 'The satellite stays in orbit.',
              exampleTr: 'Uydu yorungede kalir.',
            ),
          ]),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('word_pack_tts_word-1')),
      findsOne,
    );

    final packTtsButton = find.descendant(
      of: find.byKey(const ValueKey<String>('word_pack_tts_word-1')),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(packTtsButton);
    await tester.tap(packTtsButton);
    await tester.pump();

    expect(fakeTtsEngine.spokenTexts, ['orbit']);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    fakeTtsEngine.completeCurrent();
    await tester.pumpAndSettle();

    await tester.tap(find.text('orbit'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('word_card_tts_word-1')),
      findsOne,
    );
  });

  testWidgets('flashcard TTS always reads enWord on both card faces', (
    tester,
  ) async {
    final fakeTtsEngine = _FakeStudentTtsEngine();

    await _pumpStudentTtsApp(
      tester,
      initialLocation: '/words/flashcards',
      routes: <RouteBase>[
        GoRoute(
          path: '/words/flashcards',
          builder: (context, state) => StudentFlashcardsPage(
            packId: state.uri.queryParameters['packId'],
          ),
        ),
      ],
      overrides: <Override>[
        studentTtsEngineProvider.overrideWithValue(fakeTtsEngine),
        studentWordRepositoryProvider.overrideWithValue(
          const _FakeWordRepository(<WordEntry>[
            WordEntry(
              id: 'word-1',
              packId: 'pack-1',
              enWord: 'orbit',
              trMeaning: 'yorunge',
              pos: 'n.',
            ),
          ]),
        ),
      ],
    );

    await tester.pumpAndSettle();

    final flashcardTtsButton = find.descendant(
      of: find.byKey(const ValueKey<String>('flashcard_tts_word-1')),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(flashcardTtsButton);
    await tester.tap(flashcardTtsButton);
    await tester.pump();
    expect(fakeTtsEngine.spokenTexts, ['orbit']);

    fakeTtsEngine.completeCurrent();
    await tester.pumpAndSettle();

    final flipButton = find.byIcon(Icons.flip_to_back_rounded);
    await tester.ensureVisible(flipButton);
    await tester.tap(flipButton);
    await tester.pumpAndSettle();
    await tester.tap(flashcardTtsButton);
    await tester.pump();

    expect(fakeTtsEngine.spokenTexts, ['orbit', 'orbit']);
  });

  testWidgets('reading detail supports passage and sentence TTS', (
    tester,
  ) async {
    final fakeTtsEngine = _FakeStudentTtsEngine();

    await _pumpStudentTtsApp(
      tester,
      initialLocation: '/readings/reading-live',
      routes: <RouteBase>[
        GoRoute(
          path: '/readings/:readingId',
          builder: (context, state) => StudentReadingDetailPage(
            readingId: state.pathParameters['readingId']!,
          ),
        ),
      ],
      overrides: <Override>[
        studentTtsEngineProvider.overrideWithValue(fakeTtsEngine),
        studentReadingRepositoryProvider.overrideWithValue(
          _FakeReadingRepository(
            readings: const <ReadingPassage>[
              ReadingPassage(
                id: 'reading-live',
                title: '101-Live Passage',
                level: 'B1',
                category: 'Science',
              ),
            ],
            sectionsByPassage: const <String, List<ReadingSentence>>{
              'reading-live': <ReadingSentence>[
                ReadingSentence(
                  passageId: 'reading-live',
                  index: 1,
                  englishText: 'First live sentence.',
                ),
                ReadingSentence(
                  passageId: 'reading-live',
                  index: 2,
                  englishText: 'Second live sentence.',
                ),
              ],
            },
            focusWordsByPassage: const <String, List<ReadingFocusWord>>{
              'reading-live': <ReadingFocusWord>[
                ReadingFocusWord(
                  wordId: 'word-1',
                  enWord: 'orbit',
                  trMeaning: 'yorunge',
                  pos: 'n.',
                ),
              ],
            },
          ),
        ),
        studentWordRepositoryProvider.overrideWithValue(
          const _FakeWordRepository(<WordEntry>[
            WordEntry(
              id: 'word-1',
              packId: 'pack-1',
              enWord: 'orbit',
              trMeaning: 'yorunge',
              pos: 'n.',
            ),
          ]),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('reading_passage_tts_reading-live')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reading_sentence_tts_0')),
      findsOneWidget,
    );

    final passageButton = find.byKey(
      const ValueKey<String>('reading_passage_tts_reading-live'),
    );
    await tester.ensureVisible(passageButton);
    await tester.tap(passageButton);
    await tester.pump();

    expect(fakeTtsEngine.spokenTexts.first, 'First live sentence.');
    expect(
      find.byKey(const ValueKey<String>('reading_section_0_active')),
      findsOneWidget,
    );

    fakeTtsEngine.completeCurrent();
    await tester.pump();

    expect(fakeTtsEngine.spokenTexts.last, 'Second live sentence.');
    expect(
      find.byKey(const ValueKey<String>('reading_section_1_active')),
      findsOneWidget,
    );

    fakeTtsEngine.completeCurrent();
    await tester.pumpAndSettle();

    final sentenceTtsButton = find.descendant(
      of: find.byKey(const ValueKey<String>('reading_sentence_tts_0')),
      matching: find.byType(IconButton),
    );
    await tester.ensureVisible(sentenceTtsButton);
    await tester.tap(sentenceTtsButton);
    await tester.pump();

    expect(fakeTtsEngine.spokenTexts.last, 'First live sentence.');
  });
}

Future<void> _pumpStudentTtsApp(
  WidgetTester tester, {
  required String initialLocation,
  required List<RouteBase> routes,
  List<Override> overrides = const <Override>[],
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            StudentAppShell(state: state, child: child),
        routes: routes,
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentPackRepositoryProvider.overrideWithValue(
          const FoundationPackRepository.preview(),
        ),
        studentWordRepositoryProvider.overrideWithValue(
          const FoundationWordRepository.preview(),
        ),
        studentReadingRepositoryProvider.overrideWithValue(
          const FoundationReadingRepository.preview(),
        ),
        studentWordFavoriteRepositoryProvider.overrideWithValue(
          FoundationWordFavoriteRepository.preview(),
        ),
        studentSyncRepositoryProvider.overrideWithValue(
          const FoundationSyncRepository.preview(),
        ),
        studentProgressRepositoryProvider.overrideWithValue(
          const FoundationProgressRepository.preview(),
        ),
        ...overrides,
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
}

class _FakePackRepository implements PackRepository {
  const _FakePackRepository(this.packs);

  final List<ContentPack> packs;

  @override
  Future<List<ContentPack>> fetchPacks() async => packs;
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
  const _FakeReadingRepository({
    this.readings = const <ReadingPassage>[],
    this.sectionsByPassage = const <String, List<ReadingSentence>>{},
    this.focusWordsByPassage = const <String, List<ReadingFocusWord>>{},
  });

  final List<ReadingPassage> readings;
  final Map<String, List<ReadingSentence>> sectionsByPassage;
  final Map<String, List<ReadingFocusWord>> focusWordsByPassage;

  @override
  Future<List<ReadingPassage>> fetchReadings() async => readings;

  @override
  Future<List<ReadingSentence>> fetchReadingSections(String passageId) async {
    return sectionsByPassage[passageId] ?? const <ReadingSentence>[];
  }

  @override
  Future<List<ReadingFocusWord>> fetchFocusWords(String passageId) async {
    return focusWordsByPassage[passageId] ?? const <ReadingFocusWord>[];
  }

  @override
  Future<String?> fetchSentenceTranslation(String passageId, int idx) async =>
      null;
}

class _FakeStudentTtsEngine implements StudentTtsEngine {
  @override
  Future<StudentTtsAvailability> ensureInitialized() async =>
      StudentTtsAvailability.available;

  final List<String> spokenTexts = <String>[];
  final List<Completer<void>> _speakCompleters = <Completer<void>>[];

  @override
  Future<void> speak(String text) {
    spokenTexts.add(text);
    final completer = Completer<void>();
    _speakCompleters.add(completer);
    return completer.future;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  void completeCurrent() {
    for (final completer in _speakCompleters) {
      if (completer.isCompleted) {
        continue;
      }
      completer.complete();
      return;
    }
  }
}
