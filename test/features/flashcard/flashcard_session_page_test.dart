import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/pack.dart';
import 'package:passagetr/domain/entities/user_word_progress.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/domain/repositories/progress_repository.dart';
import 'package:passagetr/domain/value_objects/flashcard_answer.dart';
import 'package:passagetr/features/flashcard/flashcard_session_page.dart';
import 'package:passagetr/state/providers.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  const Pack pack = Pack(
    id: 'pack-1',
    name: 'YDS Set 001',
    fromLang: 'en',
    toLang: 'tr',
    wordCount: 1,
  );

  const WordItem word = WordItem(
    id: 'w1',
    packId: 'pack-1',
    enWord: 'abandon',
    trMeaning: 'terk etmek',
    pos: 'verb',
    exampleEn: 'He abandoned the plan.',
    exampleTr: 'Plani terk etti.',
    synonymsRaw: 'leave; quit',
    antonymsRaw: 'keep',
    level: 'B2',
    tagsRaw: 'travel; exam',
    notes: 'Genelde bir seyden vazgecmek icin kullanilir.',
  );

  testWidgets(
    'shows compact action bar and richer back face without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            wordRepositoryProvider.overrideWith(
              (Ref ref) => FakeWordRepository(
                globalWords: const <String, WordItem>{'abandon': word},
                globalIndex: const <WordItem>[word],
              ),
            ),
            dictionaryRepositoryProvider.overrideWith(
              (Ref ref) => FakeDictionaryRepository(),
            ),
            progressRepositoryProvider.overrideWith(
              (Ref ref) => _FakeProgressRepository(),
            ),
          ],
          child: const MaterialApp(
            home: FlashcardSessionPage(
              pack: pack,
              customWordIds: <String>['w1'],
              sessionLabel: 'Odak Kelimeler',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('flashcard-action-bar')),
        findsOneWidget,
      );
      expect(find.text('Bilmem'), findsOneWidget);
      expect(find.text('Kararsiz'), findsOneWidget);
      expect(find.text('Bilirim'), findsOneWidget);
      expect(find.textContaining('Sola: Bilmem'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final FlipCardState flipState = tester.state<FlipCardState>(
        find.byKey(const ValueKey<String>('flashcard-w1')),
      );
      flipState.toggleCardWithoutAnimation();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('EN Ornek', skipOffstage: false), findsOneWidget);
      expect(find.text('TR Ornek', skipOffstage: false), findsOneWidget);
      expect(find.text('Not', skipOffstage: false), findsOneWidget);
      final ScrollableState backFaceScrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('flashcard-back-face-list')),
          matching: find.byType(Scrollable),
        ),
      );
      backFaceScrollable.position.jumpTo(
        backFaceScrollable.position.maxScrollExtent,
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Synonyms', skipOffstage: false), findsOneWidget);
      expect(find.text('Antonyms', skipOffstage: false), findsOneWidget);
      expect(find.text('Etiketler', skipOffstage: false), findsOneWidget);
      expect(find.text('leave', skipOffstage: false), findsOneWidget);
      expect(find.text('keep', skipOffstage: false), findsOneWidget);
    },
  );

  testWidgets('desktop constrains action bar and supports keyboard answers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          wordRepositoryProvider.overrideWith(
            (Ref ref) => FakeWordRepository(
              globalWords: const <String, WordItem>{'abandon': word},
              globalIndex: const <WordItem>[word],
            ),
          ),
          dictionaryRepositoryProvider.overrideWith(
            (Ref ref) => FakeDictionaryRepository(),
          ),
          progressRepositoryProvider.overrideWith(
            (Ref ref) => _FakeProgressRepository(),
          ),
        ],
        child: const MaterialApp(
          home: FlashcardSessionPage(
            pack: pack,
            customWordIds: <String>['w1'],
            sessionLabel: 'Odak Kelimeler',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('flashcard-desktop-layout')),
      findsOneWidget,
    );

    final Rect actionBarContentRect = tester.getRect(
      find.byKey(const ValueKey<String>('flashcard-action-bar-content')),
    );
    expect(actionBarContentRect.width, lessThan(1100));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('Oturum bitti'), findsOneWidget);
  });

  testWidgets(
    'desktop pack flow renders the word and opens the back face on tap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            wordRepositoryProvider.overrideWith(
              (Ref ref) => FakeWordRepository(
                globalWords: const <String, WordItem>{'abandon': word},
                globalIndex: const <WordItem>[word],
                packWords: const <String, WordItem>{'pack-1|abandon': word},
              ),
            ),
            dictionaryRepositoryProvider.overrideWith(
              (Ref ref) => FakeDictionaryRepository(),
            ),
            progressRepositoryProvider.overrideWith(
              (Ref ref) => _FakeProgressRepository(),
            ),
          ],
          child: const MaterialApp(home: FlashcardSessionPage(pack: pack)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('abandon'), findsOneWidget);
      expect(find.text('terk etmek'), findsNothing);
      final Rect sceneRect = tester.getRect(
        find.byKey(const ValueKey<String>('flashcard-static-scene')),
      );
      expect(sceneRect.width, greaterThan(500));
      expect(sceneRect.height, greaterThan(500));

      await tester.tap(
        find.byKey(const ValueKey<String>('flashcard-static-scene')),
      );
      await tester.pumpAndSettle();

      expect(find.text('terk etmek'), findsOneWidget);
      expect(find.text('EN Ornek'), findsOneWidget);
    },
  );

  testWidgets(
    'desktop custom session renders the word and opens the back face on tap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            wordRepositoryProvider.overrideWith(
              (Ref ref) => FakeWordRepository(
                globalWords: const <String, WordItem>{'abandon': word},
                globalIndex: const <WordItem>[word],
              ),
            ),
            dictionaryRepositoryProvider.overrideWith(
              (Ref ref) => FakeDictionaryRepository(),
            ),
            progressRepositoryProvider.overrideWith(
              (Ref ref) => _FakeProgressRepository(),
            ),
          ],
          child: const MaterialApp(
            home: FlashcardSessionPage(
              pack: pack,
              customWordIds: <String>['w1'],
              sessionLabel: 'Odak Kelimeler',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('abandon'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('flashcard-static-scene')),
      );
      await tester.pumpAndSettle();

      expect(find.text('terk etmek'), findsOneWidget);
    },
  );
}

class _FakeProgressRepository implements ProgressRepository {
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
  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  }) async {
    return const <String, UserWordProgress>{};
  }

  @override
  Future<Map<String, int>> getStudiedWordCountByLevel({
    required List<String> levels,
  }) async {
    return const <String, int>{};
  }

  @override
  Future<int> getTodayWordCount() async => 0;

  @override
  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  }) async {
    return const <String>[];
  }
}
