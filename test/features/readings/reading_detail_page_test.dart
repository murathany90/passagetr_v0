import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingilizce_app1/domain/entities/pack.dart';
import 'package:ingilizce_app1/domain/entities/passage_sentence.dart';
import 'package:ingilizce_app1/domain/entities/reading_passage.dart';
import 'package:ingilizce_app1/domain/entities/word_item.dart';
import 'package:ingilizce_app1/features/readings/reading_detail_page.dart';
import 'package:ingilizce_app1/state/content_providers.dart';
import 'package:ingilizce_app1/state/reading_providers.dart';
import 'package:ingilizce_app1/state/translation_providers.dart';
import 'package:ingilizce_app1/state/word_providers.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  const Pack pack = Pack(
    id: 'pack-1',
    name: 'YDS Set 001',
    fromLang: 'en',
    toLang: 'tr',
    wordCount: 100,
  );

  const ReadingPassage passage = ReadingPassage(
    id: 'passage-1',
    packId: 'pack-1',
    packName: 'YDS Set 001',
    title: 'Reading 001',
    level: 'B1',
    tagsRaw: 'daily',
    category: 'general',
  );

  const PassageSentence sentence = PassageSentence(
    id: 's1',
    passageId: 'passage-1',
    passageTitle: 'Reading 001',
    idx: 1,
    sentenceEn: 'The clean place is calm.',
    sentenceTr: null,
  );

  const WordItem knownWord = WordItem(
    id: 'w-clean',
    packId: 'pack-1',
    enWord: 'clean',
    trMeaning: 'temiz',
    pos: 'adj',
    exampleEn: 'The room is clean.',
    exampleTr: 'Oda temiz.',
    synonymsRaw: null,
    antonymsRaw: null,
    level: 'A2',
    tagsRaw: null,
    notes: null,
  );

  testWidgets(
      'renders reading sentence and keeps focus panel collapsed by default', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final FakeReadingRepository readingRepository = FakeReadingRepository(
      sentences: const <PassageSentence>[sentence],
      passageWords: const <WordItem>[knownWord],
    );
    final FakeWordRepository wordRepository = FakeWordRepository(
      globalWords: const <String, WordItem>{'clean': knownWord},
      globalIndex: const <WordItem>[knownWord],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appContentDatasetVersionProvider.overrideWith(
            (Ref ref) async => 'v-test',
          ),
          readingRepositoryProvider
              .overrideWith((Ref ref) => readingRepository),
          wordRepositoryProvider.overrideWith((Ref ref) => wordRepository),
          translationServiceProvider.overrideWith(
            (Ref ref) => FakeTranslationService(),
          ),
        ],
        child: const MaterialApp(
          home: ReadingDetailPage(
            passage: passage,
            pack: pack,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('clean place is calm'),
      ),
      findsWidgets,
    );
    expect(find.text('Ceviriyi Goster'), findsOneWidget);
    expect(find.text('Odak Kelimeler'), findsOneWidget);
    expect(find.text('Kelime Calis'), findsNothing);
  });
}
