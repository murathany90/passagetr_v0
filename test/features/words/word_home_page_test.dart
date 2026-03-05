import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/dictionary_lookup_result.dart';
import 'package:passagetr/domain/entities/pack.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/features/words/word_home_page.dart';
import 'package:passagetr/state/content_providers.dart';
import 'package:passagetr/state/pack_providers.dart';
import 'package:passagetr/state/word_providers.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  const Pack pack = Pack(
    id: 'pack-1',
    name: 'YDS Set 001',
    fromLang: 'en',
    toLang: 'tr',
    wordCount: 10,
  );

  WordItem buildWord() {
    return const WordItem(
      id: 'w1',
      packId: 'pack-1',
      enWord: 'abandon',
      trMeaning: 'terk etmek',
      pos: 'verb',
      exampleEn: 'He abandoned the plan.',
      exampleTr: 'Plani terk etti.',
      synonymsRaw: null,
      antonymsRaw: null,
      level: 'B2',
      tagsRaw: null,
      notes: null,
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required FakeWordRepository wordRepository,
    required FakeDictionaryRepository dictionaryRepository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appContentDatasetVersionProvider.overrideWith(
            (Ref ref) async => 'test-v1',
          ),
          packListProvider.overrideWith((Ref ref) async => const <Pack>[pack]),
          wordRepositoryProvider.overrideWith((Ref ref) => wordRepository),
          dictionaryRepositoryProvider.overrideWith(
            (Ref ref) => dictionaryRepository,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: WordHomePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> configureViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('shows Kelime Kartı and Sözlük actions when word card exists', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);

    final FakeWordRepository wordRepository = FakeWordRepository(
      globalWords: <String, WordItem>{'abandon': buildWord()},
      packWords: <String, WordItem>{'pack-1|abandon': buildWord()},
      globalIndex: <WordItem>[buildWord()],
    );
    final FakeDictionaryRepository dictionaryRepository =
        FakeDictionaryRepository(
      lookupResult: DictionaryLookupResult.fallback(
        translatedText: 'terk etmek',
        fromServerCache: false,
        fromDeepL: true,
      ),
    );

    await pumpPage(
      tester,
      wordRepository: wordRepository,
      dictionaryRepository: dictionaryRepository,
    );

    await tester.enterText(find.byType(TextField), 'abandon');
    tester.testTextInput.hide();
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kelime kartında bulundu'), findsOneWidget);
    expect(find.text('Kelime Kartı'), findsOneWidget);
    expect(find.text('Sözlük'), findsOneWidget);
  });

  testWidgets('shows only Sözlük action when word card does not exist', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);

    final FakeWordRepository wordRepository = FakeWordRepository(
      globalWords: const <String, WordItem>{},
      packWords: const <String, WordItem>{},
      globalIndex: const <WordItem>[],
    );
    final FakeDictionaryRepository dictionaryRepository =
        FakeDictionaryRepository(
      lookupResult: DictionaryLookupResult.fallback(
        translatedText: 'deneme',
        fromServerCache: true,
        fromDeepL: false,
      ),
    );

    await pumpPage(
      tester,
      wordRepository: wordRepository,
      dictionaryRepository: dictionaryRepository,
    );

    await tester.enterText(find.byType(TextField), 'foobar');
    tester.testTextInput.hide();
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kelime kartında bulunamadı'), findsOneWidget);
    expect(find.text('Kelime Kartı'), findsNothing);
    expect(find.text('Sözlük'), findsOneWidget);
  });
}

