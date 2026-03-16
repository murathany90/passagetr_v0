import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/core/student_access_controller.dart';
import 'package:student_app/src/core/student_providers.dart';
import 'package:student_app/src/features/common/page_parts.dart';
import 'package:student_app/src/features/readings/reading_detail_page.dart';
import 'package:student_app/src/features/readings/readings_page.dart';
import 'package:student_app/src/features/words/flashcards_page.dart';
import 'package:student_app/src/features/words/mini_test_page.dart';
import 'package:student_app/src/features/words/word_pack_detail_page.dart';
import 'package:student_app/src/features/words/words_page.dart';

import '../support/fake_reading_engagement_repository.dart';
import '../support/fake_word_favorite_repository.dart';

void main() {
  testWidgets('admin launcher opens admin console callback', (tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: AdminConsoleLauncherPage(
          adminConsoleUrl: 'http://127.0.0.1:8152/',
          onOpenAdminConsole: () async {
            callCount += 1;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Admin console uygulamasını aç'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(find.text('http://127.0.0.1:8152/'), findsOneWidget);
  });

  testWidgets('tapping a word pack card opens the pack detail page', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/words',
      routes: <RouteBase>[
        GoRoute(
          path: '/words',
          builder: (context, state) => const StudentWordsPage(),
        ),
        GoRoute(
          path: '/words/packs/:packId',
          builder: (context, state) => StudentWordPackDetailPage(
            packId: state.pathParameters['packId']!,
          ),
        ),
        GoRoute(
          path: '/words/flashcards',
          builder: (context, state) => StudentFlashcardsPage(
            packId: state.uri.queryParameters['packId'],
          ),
        ),
        GoRoute(
          path: '/words/tests',
          builder: (context, state) =>
              StudentMiniTestPage(packId: state.uri.queryParameters['packId']),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Kelime Paketleri'), findsOneWidget);
    final packTitleFinder = find.text('YDS İlk 1000');
    await tester.ensureVisible(packTitleFinder);
    await tester.tap(packTitleFinder);
    await tester.pumpAndSettle();

    expect(find.text('Kelime Paketi'), findsOneWidget);
    expect(find.text('Paket Kelimeleri'), findsOneWidget);
    expect(find.text('a great deal of'), findsOneWidget);
    expect(find.text('Flashcard ile Çalış'), findsOneWidget);
  });

  testWidgets(
    'reading detail removes old translation chrome and supports word gestures',
    (tester) async {
      await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/readings/reading-silent-ocean',
        routes: <RouteBase>[
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
          GoRoute(
            path: '/readings/:readingId',
            builder: (context, state) => StudentReadingDetailPage(
              readingId: state.pathParameters['readingId']!,
            ),
          ),
        ],
        overrides: <Override>[
          studentDictionaryRepositoryProvider.overrideWithValue(
            const _FakeDictionaryRepository(<String, DictionaryEntry?>{
              'ocean': DictionaryEntry(
                enWord: 'ocean',
                trMeaning: 'buyuk su kutlesi',
                pos: 'noun',
              ),
              'mystery': DictionaryEntry(
                enWord: 'mystery',
                trMeaning: 'gizem',
                pos: 'noun',
              ),
            }),
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Okurken ceviri katmanini'), findsNothing);
      expect(find.text('Turkce Ceviriyi Goster'), findsNothing);
      expect(find.textContaining('Bolum'), findsNothing);

      final oceanFinder = find.text('ocean').first;
      await tester.ensureVisible(oceanFinder);
      await tester.tap(oceanFinder);
      await tester.pumpAndSettle();

      expect(find.text('buyuk su kutlesi'), findsOneWidget);
      expect(find.text('noun'), findsOneWidget);

      final mysteryFinder = find.text('mystery').first;
      await tester.ensureVisible(mysteryFinder);
      await tester.tap(mysteryFinder);
      await tester.pumpAndSettle();

      expect(find.text('gizem'), findsOneWidget);
      expect(find.text('buyuk su kutlesi'), findsNothing);

      await tester.longPress(mysteryFinder);
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && (widget.data?.contains('Okyanus') ?? false),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('readings page paginates after 21 items', (tester) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/readings',
      routes: <RouteBase>[
        GoRoute(
          path: '/readings',
          builder: (context, state) => const StudentReadingsPage(),
        ),
      ],
      overrides: <Override>[
        studentReadingRepositoryProvider.overrideWithValue(
          _FakeReadingRepository(
            readings: List<ReadingPassage>.generate(
              22,
              (index) => ReadingPassage(
                id: 'reading-${index + 1}',
                title: '${index + 1}-Reading Title',
                level: 'A1',
                category: 'Daily Life',
                summary: 'Summary ${index + 1}',
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('1-21 / 22 okuma'), findsOneWidget);
    expect(find.text('1-Reading Title'), findsOneWidget);
    expect(find.text('21-Reading Title'), findsOneWidget);
    expect(find.text('22-Reading Title'), findsNothing);

    final nextPageFinder = find.text('Sonraki');
    await tester.ensureVisible(nextPageFinder);
    await tester.tap(nextPageFinder);
    await tester.pumpAndSettle();

    expect(find.text('22-Reading Title'), findsOneWidget);
    expect(find.text('1-Reading Title'), findsNothing);
  });

  testWidgets(
    'readings page does not render placeholder summary text on cards',
    (tester) async {
      await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/readings',
        routes: <RouteBase>[
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
        ],
        overrides: <Override>[
          studentReadingRepositoryProvider.overrideWithValue(
            _FakeReadingRepository(
              readings: const <ReadingPassage>[
                ReadingPassage(
                  id: 'reading-without-summary',
                  title: 'Placeholder Free Reading',
                  level: 'B1',
                  category: 'Science',
                ),
              ],
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.text('Placeholder Free Reading'), findsOneWidget);
      expect(
        find.text('Bu okuma icin ozet ve ceviri destegi yakinda genisletilecek.'),
        findsNothing,
      );
      expect(find.text('Okumaya Basla ->'), findsOneWidget);
    },
  );

  testWidgets(
    'readings page filters saved and favorite items from hydrated state',
    (tester) async {
      final container = await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/readings',
        routes: <RouteBase>[
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
        ],
        overrides: <Override>[
          studentReadingRepositoryProvider.overrideWithValue(
            _FakeReadingRepository(
              readings: const <ReadingPassage>[
                ReadingPassage(
                  id: 'reading-silent-ocean',
                  title: 'Saved Reading',
                  level: 'A2',
                  category: 'Science',
                ),
                ReadingPassage(
                  id: 'reading-coffee-shops',
                  title: 'Favorite Reading',
                  level: 'A2',
                  category: 'Daily Life',
                ),
                ReadingPassage(
                  id: 'reading-brief-history',
                  title: 'Neutral Reading',
                  level: 'B1',
                  category: 'History',
                ),
              ],
            ),
          ),
          studentReadingEngagementRepositoryProvider.overrideWithValue(
            const FakeReadingEngagementRepository(<ReadingEngagement>[
              ReadingEngagement(
                passageId: 'reading-silent-ocean',
                isBookmarked: true,
                isFavorite: false,
              ),
              ReadingEngagement(
                passageId: 'reading-coffee-shops',
                isBookmarked: false,
                isFavorite: true,
              ),
            ]),
          ),
        ],
      );

      container.read(studentAccessProvider.notifier).setAnonymous(false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kayitlilar'));
      await tester.pumpAndSettle();

      expect(find.text('Saved Reading'), findsOneWidget);
      expect(find.text('Favorite Reading'), findsNothing);
      expect(find.text('Neutral Reading'), findsNothing);

      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();

      expect(find.text('Favorite Reading'), findsOneWidget);
      expect(find.text('Saved Reading'), findsNothing);
    },
  );

  testWidgets('readings page filters items by selected pack', (tester) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/readings',
      routes: <RouteBase>[
        GoRoute(
          path: '/readings',
          builder: (context, state) => const StudentReadingsPage(),
        ),
      ],
      overrides: <Override>[
        studentPackRepositoryProvider.overrideWithValue(
          const _FakePackRepository(<ContentPack>[
            ContentPack(id: 'pack-1', name: 'YDS Set 001', wordCount: 5314),
            ContentPack(id: 'pack-2', name: 'YDS Set 002', wordCount: 0),
          ]),
        ),
        studentReadingRepositoryProvider.overrideWithValue(
          _FakeReadingRepository(
            readings: const <ReadingPassage>[
              ReadingPassage(
                id: 'reading-pack-1',
                title: 'Set 001 Reading',
                level: 'A2',
                category: 'Science',
                packId: 'pack-1',
              ),
              ReadingPassage(
                id: 'reading-pack-2',
                title: 'Set 002 Reading',
                level: 'B1',
                category: 'History',
                packId: 'pack-2',
              ),
            ],
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('reading-pack-filter-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Set 001 Reading'), findsOneWidget);
    expect(find.text('Set 002 Reading'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('reading-pack-filter-dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('YDS Set 002').last);
    await tester.pumpAndSettle();

    expect(find.text('Set 002 Reading'), findsOneWidget);
    expect(find.text('Set 001 Reading'), findsNothing);
  });

  testWidgets('readings page keeps Kesfet chip in all readings only', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/readings',
      routes: <RouteBase>[
        GoRoute(
          path: '/readings',
          builder: (context, state) => const StudentReadingsPage(),
        ),
      ],
      overrides: <Override>[
        studentReadingRepositoryProvider.overrideWithValue(
          _FakeReadingRepository(
            readings: const <ReadingPassage>[
              ReadingPassage(
                id: 'reading-silent-ocean',
                title: 'Incomplete Reading',
                level: 'A2',
                category: 'Science',
              ),
              ReadingPassage(
                id: 'reading-coffee-shops',
                title: 'Completed Reading',
                level: 'A2',
                category: 'Daily Life',
              ),
            ],
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('Kesfet'), findsAtLeast(1));

    await tester.tap(find.textContaining('Kesfet').first);
    await tester.pumpAndSettle();

    expect(find.text('Incomplete Reading'), findsOneWidget);
    expect(find.text('Completed Reading'), findsNothing);

    await tester.tap(find.text('Kayitlilar'));
    await tester.pumpAndSettle();

    expect(find.text('Kesfet'), findsNothing);
  });

  testWidgets(
    'anonymous readings page shows auth state for saved and favorites',
    (tester) async {
      await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/readings',
        routes: <RouteBase>[
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
        ],
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Kayitlilar'));
      await tester.pumpAndSettle();

      expect(find.text('Kayitlilar giris gerektirir'), findsOneWidget);
      expect(find.text('Profile Git'), findsOneWidget);

      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();

      expect(find.text('Favoriler giris gerektirir'), findsOneWidget);
    },
  );

  testWidgets(
    'reading detail uses repository sentences, direct translation and hides placeholder summary',
    (tester) async {
      await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/readings/reading-live',
        routes: <RouteBase>[
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
          GoRoute(
            path: '/readings/:readingId',
            builder: (context, state) => StudentReadingDetailPage(
              readingId: state.pathParameters['readingId']!,
            ),
          ),
        ],
        overrides: <Override>[
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
                    turkishText: 'Birinci canli cumle.',
                  ),
                  ReadingSentence(
                    passageId: 'reading-live',
                    index: 2,
                    englishText: 'Second live sentence.',
                    turkishText: 'Ikinci canli cumle.',
                  ),
                ],
              },
              focusWordsByPassage: const <String, List<ReadingFocusWord>>{
                'reading-live': <ReadingFocusWord>[
                  ReadingFocusWord(
                    wordId: 'word-1',
                    enWord: 'orbit',
                    trMeaning: 'yorunge',
                    pos: 'noun',
                  ),
                ],
              },
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.text('First live sentence.'), findsNothing);
      expect(find.textContaining('First'), findsAtLeast(1));
      expect(find.textContaining('Second'), findsAtLeast(1));
      expect(find.text('Sure'), findsNothing);
      expect(
        find.text(
          'Bu okuma icin ozet ve ceviri destegi yakinda genisletilecek.',
        ),
        findsNothing,
      );
      expect(find.text('orbit'), findsOneWidget);
      expect(find.text('yorunge'), findsOneWidget);

      final firstWordFinder = find.text('First');
      await tester.ensureVisible(firstWordFinder);
      await tester.longPress(firstWordFinder);
      await tester.pumpAndSettle();

      expect(find.text('Birinci canli cumle.'), findsOneWidget);
    },
  );

  testWidgets('reading detail shows previous and next passage shortcuts', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/readings/reading-2',
      routes: <RouteBase>[
        GoRoute(
          path: '/readings',
          builder: (context, state) => const StudentReadingsPage(),
        ),
        GoRoute(
          path: '/readings/:readingId',
          builder: (context, state) => StudentReadingDetailPage(
            readingId: state.pathParameters['readingId']!,
          ),
        ),
      ],
      overrides: <Override>[
        studentReadingRepositoryProvider.overrideWithValue(
          _FakeReadingRepository(
            readings: const <ReadingPassage>[
              ReadingPassage(
                id: 'reading-1',
                title: '001-Alpha',
                level: 'A1',
                category: 'Daily Life',
              ),
              ReadingPassage(
                id: 'reading-2',
                title: '002-Beta',
                level: 'A2',
                category: 'Daily Life',
              ),
              ReadingPassage(
                id: 'reading-3',
                title: '003-Gamma',
                level: 'B1',
                category: 'Work',
              ),
            ],
            sectionsByPassage: const <String, List<ReadingSentence>>{
              'reading-1': <ReadingSentence>[
                ReadingSentence(
                  passageId: 'reading-1',
                  index: 1,
                  englishText: 'Alpha sentence.',
                ),
              ],
              'reading-2': <ReadingSentence>[
                ReadingSentence(
                  passageId: 'reading-2',
                  index: 1,
                  englishText: 'Beta sentence.',
                ),
              ],
              'reading-3': <ReadingSentence>[
                ReadingSentence(
                  passageId: 'reading-3',
                  index: 1,
                  englishText: 'Gamma sentence.',
                ),
              ],
            },
          ),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Onceki parca'), findsOneWidget);
    expect(find.text('Sonraki parca'), findsOneWidget);
    expect(find.text('001-Alpha'), findsOneWidget);
    expect(find.text('003-Gamma'), findsOneWidget);

    final nextButtonFinder = find.byKey(
      const ValueKey<String>('reading_nav_next_reading-3'),
    );
    await tester.ensureVisible(nextButtonFinder);
    await tester.tap(nextButtonFinder);
    await tester.pumpAndSettle();

    expect(find.text('003-Gamma'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('reading_nav_prev_reading-2')),
      findsOneWidget,
    );
  });

  testWidgets('reading detail renders mini test and records reading attempt', (
    tester,
  ) async {
    final progressRepository = _RecordingProgressRepository();

    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/readings/reading-quiz',
      routes: <RouteBase>[
        GoRoute(
          path: '/readings',
          builder: (context, state) => const StudentReadingsPage(),
        ),
        GoRoute(
          path: '/readings/:readingId',
          builder: (context, state) => StudentReadingDetailPage(
            readingId: state.pathParameters['readingId']!,
          ),
        ),
      ],
      overrides: <Override>[
        studentReadingRepositoryProvider.overrideWithValue(
          _FakeReadingRepository(
            readings: const <ReadingPassage>[
              ReadingPassage(
                id: 'reading-quiz',
                title: '103-Quiz Passage',
                level: 'B1',
                category: 'Science',
              ),
            ],
            sectionsByPassage: const <String, List<ReadingSentence>>{
              'reading-quiz': <ReadingSentence>[
                ReadingSentence(
                  passageId: 'reading-quiz',
                  index: 1,
                  englishText: 'Space crews prepare for long missions.',
                  turkishText: 'Uzay ekipleri uzun gorevlere hazirlanir.',
                ),
              ],
            },
            questionsByPassage: const <String, List<ReadingQuestion>>{
              'reading-quiz': <ReadingQuestion>[
                ReadingQuestion(
                  id: 'question-1',
                  passageId: 'reading-quiz',
                  sortOrder: 1,
                  question: 'What do space crews prepare for?',
                  options: <String>['Long missions', 'Cooking classes'],
                  correctOptionIndex: 0,
                  explanation:
                      'The passage states they prepare for long missions.',
                ),
                ReadingQuestion(
                  id: 'question-2',
                  passageId: 'reading-quiz',
                  sortOrder: 2,
                  question: 'Where do they prepare?',
                  options: <String>['In forests', 'In training programs'],
                  correctOptionIndex: 1,
                ),
              ],
            },
          ),
        ),
        studentProgressRepositoryProvider.overrideWithValue(progressRepository),
        _identifiedAccessOverride(),
      ],
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('reading_quiz_panel')),
      findsOneWidget,
    );
    expect(find.textContaining('Mini Test'), findsAtLeast(1));

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('reading_quiz_option_question-1_0')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('reading_quiz_option_question-1_0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('reading_quiz_option_question-2_0')),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('reading_quiz_submit')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('reading_quiz_submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Skor 50%'), findsOneWidget);
    expect(progressRepository.enqueuedEvents, hasLength(1));
    expect(
      progressRepository.enqueuedEvents.single.entityType,
      'user_test_attempts',
    );

    final payload =
        jsonDecode(progressRepository.enqueuedEvents.single.payloadJson)
            as Map<String, dynamic>;
    expect(payload['source_type'], 'reading');
    expect(payload['source_id'], 'reading-quiz');
    expect(payload['score'], 50);
    expect(payload['correct_count'], 1);
    expect(payload['wrong_count'], 1);
  });

  testWidgets(
    'focus words open the same popup and related words resolve to card or dictionary',
    (tester) async {
      await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/readings/reading-focus',
        routes: <RouteBase>[
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
          GoRoute(
            path: '/readings/:readingId',
            builder: (context, state) => StudentReadingDetailPage(
              readingId: state.pathParameters['readingId']!,
            ),
          ),
        ],
        overrides: <Override>[
          studentReadingRepositoryProvider.overrideWithValue(
            _FakeReadingRepository(
              readings: const <ReadingPassage>[
                ReadingPassage(
                  id: 'reading-focus',
                  title: '102-Focus Passage',
                  level: 'B1',
                  category: 'Science',
                ),
              ],
              sectionsByPassage: const <String, List<ReadingSentence>>{
                'reading-focus': <ReadingSentence>[
                  ReadingSentence(
                    passageId: 'reading-focus',
                    index: 1,
                    englishText: 'Orbit shapes every mission.',
                    turkishText: 'Yorunge her gorevi sekillendirir.',
                  ),
                ],
              },
              focusWordsByPassage: const <String, List<ReadingFocusWord>>{
                'reading-focus': <ReadingFocusWord>[
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
                exampleEn: 'The satellite stays in orbit.',
                exampleTr: 'Uydu yorungede kalir.',
                synonymsRaw: 'path, track',
                antonymsRaw: 'standstill',
              ),
              WordEntry(
                id: 'word-2',
                packId: 'pack-1',
                enWord: 'path',
                trMeaning: 'rota',
                pos: 'n.',
                exampleEn: 'The rover followed a narrow path.',
                exampleTr: 'Gezgin dar bir rotayi takip etti.',
              ),
            ]),
          ),
          studentDictionaryRepositoryProvider.overrideWithValue(
            const _FakeDictionaryRepository(<String, DictionaryEntry?>{
              'standstill': DictionaryEntry(
                enWord: 'standstill',
                trMeaning: 'durma noktasi',
                pos: 'n.',
              ),
            }),
          ),
        ],
      );

      await tester.pumpAndSettle();

      final focusTokenFinder = find.textContaining('Orbit');
      await tester.ensureVisible(focusTokenFinder);
      await tester.tap(focusTokenFinder);
      await tester.pumpAndSettle();

      expect(find.text('The satellite stays in orbit.'), findsOneWidget);
      expect(find.text('Uydu yorungede kalir.'), findsOneWidget);
      expect(find.text('path'), findsOneWidget);
      expect(find.text('standstill'), findsOneWidget);

      await tester.tap(find.text('path'));
      await tester.pumpAndSettle();

      expect(find.text('rota'), findsOneWidget);
      expect(find.text('The rover followed a narrow path.'), findsOneWidget);
      expect(find.text('Uydu yorungede kalir.'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('word_card_dismiss_area')),
      );
      await tester.pumpAndSettle();

      expect(find.text('rota'), findsNothing);

      final focusPanelFinder = find.textContaining('orbit').last;
      await tester.ensureVisible(focusPanelFinder);
      await tester.tap(focusPanelFinder);
      await tester.pumpAndSettle();

      expect(find.text('The satellite stays in orbit.'), findsOneWidget);
      expect(find.text('Uydu yorungede kalir.'), findsOneWidget);

      await tester.tap(find.text('standstill'));
      await tester.pumpAndSettle();

      expect(find.text('Sozluk cevirisi'), findsOneWidget);
      expect(find.text('durma noktasi'), findsOneWidget);
      expect(find.text('The satellite stays in orbit.'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('word_card_close_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('durma noktasi'), findsNothing);
    },
  );

  testWidgets(
    'anonymous reading detail disables bookmark and favorite actions',
    (tester) async {
      await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/readings/reading-silent-ocean',
        routes: <RouteBase>[
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
          GoRoute(
            path: '/readings/:readingId',
            builder: (context, state) => StudentReadingDetailPage(
              readingId: state.pathParameters['readingId']!,
            ),
          ),
        ],
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Kaydetmek icin giris yap'), findsAtLeast(1));
      final bookmarkButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.bookmark_border_rounded),
          matching: find.byType(IconButton),
        ),
      );
      final favoriteButton = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.favorite_border_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(bookmarkButton.onPressed, isNull);
      expect(favoriteButton.onPressed, isNull);
    },
  );

  testWidgets(
    'words page favorites view sorts hydrated favorites and filters active results',
    (tester) async {
      await _pumpStudentBehaviorApp(
        tester,
        initialLocation: '/words',
        routes: <RouteBase>[
          GoRoute(
            path: '/words',
            builder: (context, state) => const StudentWordsPage(),
          ),
        ],
        overrides: <Override>[
          studentWordRepositoryProvider.overrideWithValue(
            const _FakeWordRepository(<WordEntry>[
              WordEntry(
                id: 'word-1',
                packId: 'pack-1',
                enWord: 'orbit',
                trMeaning: 'yorunge',
                pos: 'n.',
                exampleEn: 'The satellite stays in orbit.',
              ),
              WordEntry(
                id: 'word-2',
                packId: 'pack-1',
                enWord: 'array',
                trMeaning: 'dizi',
                pos: 'n.',
                exampleEn: 'The data sits in an array.',
              ),
              WordEntry(
                id: 'word-3',
                packId: 'pack-1',
                enWord: 'calm',
                trMeaning: 'sakin',
                pos: 'adj.',
              ),
            ]),
          ),
          studentWordFavoriteRepositoryProvider.overrideWithValue(
            FakeWordFavoriteRepository(
              items: <WordFavorite>[
                WordFavorite(
                  wordId: 'word-2',
                  isFavorite: true,
                  favoritedAt: DateTime.utc(2026, 3, 1),
                ),
                WordFavorite(
                  wordId: 'word-1',
                  isFavorite: true,
                  favoritedAt: DateTime.utc(2026, 3, 2),
                ),
              ],
            ),
          ),
          _identifiedAccessOverride(),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Favoriler'));
      await tester.pumpAndSettle();

      expect(find.text('orbit'), findsOneWidget);
      expect(find.text('array'), findsOneWidget);
      expect(find.text('calm'), findsNothing);
      expect(
        tester.getTopLeft(find.text('orbit')).dy,
        lessThan(tester.getTopLeft(find.text('array')).dy),
      );

      await tester.ensureVisible(find.text('orbit'));
      await tester.tap(find.text('orbit'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('word_card_close_button')),
        findsOneWidget,
      );
      expect(find.text('The satellite stays in orbit.'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('word_card_close_button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'dizi');
      await tester.pumpAndSettle();

      expect(find.text('array'), findsOneWidget);
      expect(find.text('orbit'), findsNothing);
    },
  );

  testWidgets('anonymous words page shows auth state for favorites', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/words',
      routes: <RouteBase>[
        GoRoute(
          path: '/words',
          builder: (context, state) => const StudentWordsPage(),
        ),
      ],
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoriler'));
    await tester.pumpAndSettle();

    expect(find.text('Favoriler giris gerektirir'), findsOneWidget);
    expect(find.text('Profile Git'), findsOneWidget);
  });

  testWidgets('word card popup toggles favorite state immediately', (
    tester,
  ) async {
    final favoriteRepository = FakeWordFavoriteRepository();
    await _pumpStudentBehaviorApp(
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
        studentPackRepositoryProvider.overrideWithValue(
          const _FakePackRepository(<ContentPack>[
            ContentPack(id: 'pack-1', name: 'Pack One', wordCount: 1),
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
            ),
          ]),
        ),
        studentWordFavoriteRepositoryProvider.overrideWithValue(
          favoriteRepository,
        ),
        _identifiedAccessOverride(),
      ],
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('orbit'));
    await tester.tap(find.text('orbit'));
    await tester.pumpAndSettle();

    final favoriteFinder = find.byKey(
      const ValueKey<String>('word_card_favorite_word-1'),
    );
    expect(tester.widget<IconButton>(favoriteFinder).onPressed, isNotNull);
    await tester.tap(favoriteFinder);
    await tester.pumpAndSettle();

    expect(favoriteRepository.favoriteWrites, [('word-1', true)]);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('anonymous word card popup disables favorite action', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
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
        studentPackRepositoryProvider.overrideWithValue(
          const _FakePackRepository(<ContentPack>[
            ContentPack(id: 'pack-1', name: 'Pack One', wordCount: 1),
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
            ),
          ]),
        ),
      ],
    );

    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('orbit'));
    await tester.tap(find.text('orbit'));
    await tester.pumpAndSettle();

    expect(find.text('Favoriye eklemek icin giris yap'), findsOneWidget);
    final favoriteButton = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('word_card_favorite_word-1')),
    );
    expect(favoriteButton.onPressed, isNull);
  });

  testWidgets(
    'flashcard favorite toggle updates state without changing study flow',
    (tester) async {
      final favoriteRepository = FakeWordFavoriteRepository();
      await _pumpStudentBehaviorApp(
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
          studentWordFavoriteRepositoryProvider.overrideWithValue(
            favoriteRepository,
          ),
          _identifiedAccessOverride(),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('orbit'), findsOneWidget);
      expect(find.text('Bilmiyorum'), findsOneWidget);

      final favoriteFinder = find.byKey(
        const ValueKey<String>('flashcard_favorite_word-1'),
      );
      final favoriteButton = tester.widget<IconButton>(favoriteFinder);
      expect(favoriteButton.onPressed, isNotNull);
      favoriteButton.onPressed!.call();
      await tester.pumpAndSettle();

      expect(favoriteRepository.favoriteWrites, [('word-1', true)]);
      expect(find.text('orbit'), findsOneWidget);
      expect(find.text('Bilmiyorum'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    },
  );

  testWidgets('words page hides zero-word packs from student listing', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/words',
      routes: <RouteBase>[
        GoRoute(
          path: '/words',
          builder: (context, state) => const StudentWordsPage(),
        ),
      ],
      overrides: <Override>[
        studentPackRepositoryProvider.overrideWithValue(
          const _FakePackRepository(<ContentPack>[
            ContentPack(id: 'pack-full', name: 'Dolu Paket', wordCount: 24),
            ContentPack(id: 'pack-empty', name: 'Bos Paket', wordCount: 0),
          ]),
        ),
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Dolu Paket'), findsOneWidget);
    expect(find.text('Bos Paket'), findsNothing);
  });
}

Future<ProviderContainer> _pumpStudentBehaviorApp(
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
        studentReadingEngagementRepositoryProvider.overrideWithValue(
          FoundationReadingEngagementRepository.preview(),
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

  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Override _identifiedAccessOverride() {
  final accessContext = AccessContext.preview(
    role: AppRole.user,
    plan: EntitlementPlan.free,
    isAnonymous: false,
  );
  return studentAccessProvider.overrideWith(
    (ref) => StudentAccessController(
      authRepository: _StaticAuthRepository(accessContext),
      initialAccessContext: accessContext,
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

class _StaticAuthRepository implements AuthRepository {
  const _StaticAuthRepository(this.accessContext);

  final AccessContext accessContext;

  @override
  Future<AuthSession> restoreSession() async => accessContext.session;

  @override
  Future<AppResult<AuthSession>> refreshSession() async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Stream<AccessContext> watchAccessContext() =>
      const Stream<AccessContext>.empty();

  @override
  Future<AppResult<AuthSession>> signInAnonymously() async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<void>> resendSignUpConfirmation({
    required String email,
  }) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<AuthSession>> updateDisplayName({
    required String displayName,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    return AppSuccess<AuthSession>(accessContext.session);
  }

  @override
  Future<AppResult<void>> signOut() async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<AppRole>> fetchCurrentRole() async =>
      AppSuccess<AppRole>(accessContext.role);

  @override
  void notifySessionExpired() {}

  @override
  Stream<void> get onSessionExpired => const Stream<void>.empty();
}

class _FakeReadingRepository implements ReadingRepository {
  const _FakeReadingRepository({
    this.readings = const <ReadingPassage>[],
    this.sectionsByPassage = const <String, List<ReadingSentence>>{},
    this.focusWordsByPassage = const <String, List<ReadingFocusWord>>{},
    this.questionsByPassage = const <String, List<ReadingQuestion>>{},
  });

  final List<ReadingPassage> readings;
  final Map<String, List<ReadingSentence>> sectionsByPassage;
  final Map<String, List<ReadingFocusWord>> focusWordsByPassage;
  final Map<String, List<ReadingQuestion>> questionsByPassage;

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
  Future<List<ReadingQuestion>> fetchQuestions(String passageId) async {
    return questionsByPassage[passageId] ?? const <ReadingQuestion>[];
  }

  @override
  Future<String?> fetchSentenceTranslation(String passageId, int idx) async =>
      null;
}

class _RecordingProgressRepository implements ProgressRepository {
  final List<OutboxEvent> enqueuedEvents = <OutboxEvent>[];

  @override
  Future<AppResult<void>> enqueue(OutboxEvent event) async {
    enqueuedEvents.add(event);
    return const AppSuccess<void>(null);
  }

  @override
  Future<List<GrammarProgress>> fetchGrammarProgress() async =>
      const <GrammarProgress>[];

  @override
  Future<List<ReadingProgress>> fetchReadingProgress() async =>
      const <ReadingProgress>[];

  @override
  Future<List<WordProgress>> fetchWordProgress() async =>
      const <WordProgress>[];
}

class _FakeDictionaryRepository implements DictionaryRepository {
  const _FakeDictionaryRepository(this.entriesByQuery);

  final Map<String, DictionaryEntry?> entriesByQuery;

  @override
  Future<DictionaryEntry?> lookupWord(String query) async {
    return entriesByQuery[_normalizeDictionaryQuery(query)];
  }

  String _normalizeDictionaryQuery(String query) {
    return query
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'), '');
  }
}
