import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/grammar_example.dart';
import 'package:passagetr/domain/entities/grammar_mini_test.dart';
import 'package:passagetr/domain/entities/grammar_module.dart';
import 'package:passagetr/domain/entities/grammar_page.dart';
import 'package:passagetr/domain/entities/grammar_page_detail.dart';
import 'package:passagetr/domain/repositories/grammar_repository.dart';
import 'package:passagetr/features/grammar/grammar_reader_page.dart';
import 'package:passagetr/state/grammar_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('keeps bottom CTA docked and advances pages',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const GrammarModule module = GrammarModule(
      id: 1,
      sira: 1,
      baslik: 'Temel Gramer',
      dosyaAdi: 'temel_gramer.md',
      toplamSayfa: 2,
      icon: 'book',
      renk: '#4776E6',
    );

    const List<GrammarPage> pages = <GrammarPage>[
      GrammarPage(
        id: 101,
        modulId: 1,
        sayfaNo: 1,
        baslik: 'Sayfa 1',
        icerikHtml: '<p>Intro</p>',
        kelimeSayisi: 10,
      ),
      GrammarPage(
        id: 102,
        modulId: 1,
        sayfaNo: 2,
        baslik: 'Sayfa 2',
        icerikHtml: '<p>Next</p>',
        kelimeSayisi: 12,
      ),
    ];

    final _FakeGrammarRepository grammarRepository = _FakeGrammarRepository(
      details: <int, GrammarPageDetail>{
        101: GrammarPageDetail(
          page: pages[0],
          examples: const <GrammarExample>[
            GrammarExample(
              id: 1,
              sayfaId: 101,
              sira: 1,
              ingilizce: 'She is ready.',
              turkce: 'O hazir.',
              aciklama: 'To be',
            ),
          ],
          tests: const <GrammarMiniTest>[
            GrammarMiniTest(
              id: 1,
              sayfaId: 101,
              sira: 1,
              soru: 'She ___ ready.',
              secenekler: <String, String>{'A': 'is', 'B': 'are'},
              dogruCevap: 'A',
              aciklama: 'Singular subject.',
            ),
          ],
        ),
        102: GrammarPageDetail(
          page: pages[1],
          examples: const <GrammarExample>[],
          tests: const <GrammarMiniTest>[],
        ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          grammarRepositoryProvider.overrideWith((Ref ref) => grammarRepository),
        ],
        child: const MaterialApp(
          home: GrammarReaderPage(
            module: module,
            pages: pages,
            initialIndex: 0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('1/2'), findsNWidgets(2));
    expect(find.text('Mini Test'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Devam Et'), findsOneWidget);

    final Rect ctaRect = tester.getRect(
      find.widgetWithText(FilledButton, 'Devam Et'),
    );
    expect(ctaRect.bottom, greaterThan(2300));

    await tester.tap(find.widgetWithText(FilledButton, 'Devam Et'));
    await tester.pumpAndSettle();

    expect(find.text('2/2'), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Dersi Bitir'), findsOneWidget);
    expect(find.text('Sayfa 2'), findsOneWidget);
  });
}

class _FakeGrammarRepository implements GrammarRepository {
  _FakeGrammarRepository({
    required this.details,
  });

  final Map<int, GrammarPageDetail> details;

  @override
  Future<GrammarPageDetail> getPageDetail({required int sayfaId}) async {
    final GrammarPageDetail? detail = details[sayfaId];
    if (detail == null) {
      throw StateError('missing detail for $sayfaId');
    }
    return detail;
  }

  @override
  Future<List<GrammarModule>> getModules() async => const <GrammarModule>[];

  @override
  Future<List<GrammarPage>> getPagesByModule({required int modulId}) async =>
      const <GrammarPage>[];
}
