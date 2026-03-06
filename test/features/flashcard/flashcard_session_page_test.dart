import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
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

  testWidgets('shows compact action bar and richer back face without overflow', (
    WidgetTester tester,
  ) async {
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

    await tester.tap(find.byType(FlipCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('EN Ornek'), findsOneWidget);
    expect(find.text('TR Ornek'), findsOneWidget);
    expect(find.text('Not'), findsOneWidget);
    expect(find.text('Synonyms'), findsOneWidget);
    expect(find.text('Antonyms'), findsOneWidget);
    expect(find.text('Etiketler'), findsOneWidget);
    expect(find.text('leave'), findsOneWidget);
    expect(find.text('keep'), findsOneWidget);
  });
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
  Future<int> getTodayWordCount() async => 0;

  @override
  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  }) async {
    return const <String>[];
  }
}
