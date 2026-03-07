import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/grammar_module.dart';
import 'package:passagetr/domain/entities/grammar_page.dart';
import 'package:passagetr/domain/entities/grammar_page_detail.dart';
import 'package:passagetr/domain/repositories/grammar_repository.dart';
import 'package:passagetr/features/grammar/grammar_module_pages_page.dart';
import 'package:passagetr/state/grammar_providers.dart';

const GrammarModule _module = GrammarModule(
  id: 1,
  sira: 1,
  baslik: 'Ingilizcede Temel Kavramlar',
  dosyaAdi: 'temel.md',
  toplamSayfa: 2,
  icon: 'abc',
  renk: '#4776E6',
);

const List<GrammarPage> _pages = <GrammarPage>[
  GrammarPage(
    id: 101,
    modulId: 1,
    sayfaNo: 1,
    baslik: 'Cumlenin Temel Unsurlari',
    icerikHtml: '<p>One</p>',
    kelimeSayisi: 206,
  ),
  GrammarPage(
    id: 102,
    modulId: 1,
    sayfaNo: 2,
    baslik: 'Fiil Turleri',
    icerikHtml: '<p>Two</p>',
    kelimeSayisi: 215,
  ),
];

void main() {
  testWidgets('desktop grammar module pages split summary and dense list', (
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
          grammarRepositoryProvider.overrideWith(
            (Ref ref) => _FakeGrammarRepository(),
          ),
        ],
        child: const MaterialApp(
          home: GrammarModulePagesPage(module: _module, initialPageId: 102),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('grammar-module-pages-desktop-layout')),
      findsOneWidget,
    );
    expect(find.text('Kaldigin sayfa'), findsOneWidget);
    expect(find.text('Son'), findsOneWidget);
    expect(find.text('206 kelime'), findsOneWidget);
    expect(find.text('215 kelime'), findsOneWidget);
  });
}

class _FakeGrammarRepository implements GrammarRepository {
  @override
  Future<GrammarPageDetail> getPageDetail({required int sayfaId}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<GrammarModule>> getModules() async => const <GrammarModule>[];

  @override
  Future<List<GrammarPage>> getPagesByModule({required int modulId}) async =>
      _pages;
}
