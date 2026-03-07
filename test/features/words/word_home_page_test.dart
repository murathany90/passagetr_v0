import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/dictionary_lookup_result.dart';
import 'package:passagetr/domain/entities/pack.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/features/packs/pack_list_page.dart';
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
        child: const MaterialApp(home: Scaffold(body: WordHomePage())),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> configureViewport(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('search enters results mode and filter toggles sections', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester, size: const Size(390, 1400));

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

    expect(find.byType(PackListPage), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'abandon');
    tester.testTextInput.hide();
    await tester.tap(
      find.byKey(const ValueKey<String>('word-search-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PackListPage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('word-search-results-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('word-card-result-section')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('dictionary-result-section')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('dictionary-result-section')),
      findsOneWidget,
    );
    expect(find.text('Filtre: Tumu'), findsOneWidget);

    final Finder filterBar = find.byKey(
      const ValueKey<String>('word-search-filter-bar'),
    );
    await tester.tap(
      find.descendant(of: filterBar, matching: find.text('Sozluk')).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('word-card-result-section')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('dictionary-result-section')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: filterBar, matching: find.text('Kelime Karti')).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('word-card-result-section')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('dictionary-result-section')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('word-search-clear-button')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PackListPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('word-search-results-view')),
      findsNothing,
    );
  });

  testWidgets(
    'dictionary-only results keep dictionary visible and hide empty card after filter',
    (WidgetTester tester) async {
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
      await tester.tap(
        find.byKey(const ValueKey<String>('word-search-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('word-card-empty-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dictionary-result-section')),
        findsOneWidget,
      );

      final Finder filterBar = find.byKey(
        const ValueKey<String>('word-search-filter-bar'),
      );
      await tester.tap(
        find.descendant(of: filterBar, matching: find.text('Sozluk')).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('word-card-empty-section')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('dictionary-result-section')),
        findsOneWidget,
      );
    },
  );

  testWidgets('partial query still resolves the closest word card match', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);

    final WordItem abandon = buildWord();
    final FakeWordRepository wordRepository = FakeWordRepository(
      globalWords: <String, WordItem>{'abandon': abandon},
      packWords: <String, WordItem>{'pack-1|abandon': abandon},
      globalIndex: <WordItem>[abandon],
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

    await tester.enterText(find.byType(TextField), 'aban');
    tester.testTextInput.hide();
    await tester.tap(
      find.byKey(const ValueKey<String>('word-search-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('word-card-result-section')),
      findsOneWidget,
    );
    expect(find.text('abandon'), findsOneWidget);
  });

  testWidgets('word card still appears when dictionary lookup fails', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester, size: const Size(390, 1400));

    final WordItem abandon = buildWord();
    final FakeWordRepository wordRepository = FakeWordRepository(
      globalWords: <String, WordItem>{'abandon': abandon},
      packWords: <String, WordItem>{'pack-1|abandon': abandon},
      globalIndex: <WordItem>[abandon],
    );
    final FakeDictionaryRepository dictionaryRepository =
        FakeDictionaryRepository(
      lookupError: StateError('dictionary unavailable'),
    );

    await pumpPage(
      tester,
      wordRepository: wordRepository,
      dictionaryRepository: dictionaryRepository,
    );

    await tester.enterText(find.byType(TextField), 'abandon');
    tester.testTextInput.hide();
    await tester.tap(
      find.byKey(const ValueKey<String>('word-search-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('word-card-result-section')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('dictionary-result-section')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('dictionary-result-section')),
      findsOneWidget,
    );
    expect(find.textContaining('dictionary unavailable'), findsOneWidget);
  });

  testWidgets('keyboard submit opens results mode', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);

    final WordItem abandon = buildWord();
    final FakeWordRepository wordRepository = FakeWordRepository(
      globalWords: <String, WordItem>{'abandon': abandon},
      packWords: <String, WordItem>{'pack-1|abandon': abandon},
      globalIndex: <WordItem>[abandon],
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

    await tester.tap(find.byKey(const ValueKey<String>('word-search-field')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'abandon');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('word-search-results-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('word-search-filter-bar')),
      findsOneWidget,
    );
  });

  testWidgets(
    'empty word and dictionary results show a single no-results card',
    (WidgetTester tester) async {
      await configureViewport(tester);

      final FakeWordRepository wordRepository = FakeWordRepository(
        globalWords: const <String, WordItem>{},
        packWords: const <String, WordItem>{},
        globalIndex: const <WordItem>[],
      );
      final FakeDictionaryRepository dictionaryRepository =
          FakeDictionaryRepository(
        lookupResult: DictionaryLookupResult.empty(),
      );

      await pumpPage(
        tester,
        wordRepository: wordRepository,
        dictionaryRepository: dictionaryRepository,
      );

      await tester.enterText(find.byType(TextField), 'missing');
      tester.testTextInput.hide();
      await tester.tap(
        find.byKey(const ValueKey<String>('word-search-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('word-search-empty-results-section')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('word-card-empty-section')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('dictionary-result-section')),
        findsNothing,
      );
    },
  );

  testWidgets('search button stays separate and meets minimum hit target', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);

    final FakeWordRepository wordRepository = FakeWordRepository(
      globalWords: const <String, WordItem>{},
      packWords: const <String, WordItem>{},
      globalIndex: const <WordItem>[],
    );
    final FakeDictionaryRepository dictionaryRepository =
        FakeDictionaryRepository(lookupResult: DictionaryLookupResult.empty());

    await pumpPage(
      tester,
      wordRepository: wordRepository,
      dictionaryRepository: dictionaryRepository,
    );

    final Finder submitButton = find.byKey(
      const ValueKey<String>('word-search-submit-button'),
    );
    final Size size = tester.getSize(submitButton);
    expect(size.height, greaterThanOrEqualTo(48));

    final SemanticsHandle handle = tester.ensureSemantics();
    try {
      final SemanticsNode node = tester.getSemantics(submitButton);
      final SemanticsData data = node.getSemanticsData();
      expect(data.label, 'Ara');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled != ui.Tristate.none, isTrue);
      expect(data.flagsCollection.isEnabled == ui.Tristate.isTrue, isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('desktop shows sidebar and pack list side by side', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester, size: const Size(1440, 900));

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

    expect(
      find.byKey(const ValueKey<String>('word-home-desktop-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('word-search-sidebar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('word-pack-list-desktop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('word-results-panel')),
      findsNothing,
    );
  });

  testWidgets(
    'desktop search keeps controls left and renders results on right',
    (WidgetTester tester) async {
      await configureViewport(tester, size: const Size(1440, 900));

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
      await tester.tap(
        find.byKey(const ValueKey<String>('word-search-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('word-search-sidebar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('word-results-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('word-pack-list-desktop')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('word-search-filter-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('word-search-results-view')),
        findsOneWidget,
      );
    },
  );
}
