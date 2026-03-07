import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/grammar_module.dart';
import 'package:passagetr/domain/entities/grammar_page.dart';
import 'package:passagetr/domain/entities/grammar_page_detail.dart';
import 'package:passagetr/domain/repositories/grammar_repository.dart';
import 'package:passagetr/features/grammar/grammar_home_page.dart';
import 'package:passagetr/state/grammar_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<GrammarModule> kModules = <GrammarModule>[
  GrammarModule(
    id: 1,
    sira: 1,
    baslik: 'Tenses',
    dosyaAdi: 'tenses',
    toplamSayfa: 12,
    icon: 'T',
    renk: '#4776E6',
  ),
  GrammarModule(
    id: 2,
    sira: 2,
    baslik: 'Clauses',
    dosyaAdi: 'clauses',
    toplamSayfa: 10,
    icon: 'C',
    renk: '#4CAF50',
  ),
  GrammarModule(
    id: 3,
    sira: 3,
    baslik: 'Prepositions',
    dosyaAdi: 'prepositions',
    toplamSayfa: 8,
    icon: 'P',
    renk: '#F59E0B',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> configureViewport(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          grammarRepositoryProvider.overrideWith((Ref ref) {
            return _FakeGrammarRepository();
          }),
          grammarModulesProvider.overrideWith((Ref ref) async => kModules),
        ],
        child: const MaterialApp(
          home: Scaffold(body: GrammarHomePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('desktop grammar page shows overview and grid', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);
    await pumpPage(tester);

    expect(
      find.byKey(const ValueKey<String>('grammar-home-desktop-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('grammar-home-grid')),
      findsOneWidget,
    );
    expect(find.text('Gramer Kutuphanesi'), findsOneWidget);
    expect(find.text('3 modul'), findsOneWidget);
    expect(find.text('30 sayfa'), findsOneWidget);
    expect(find.text('Tenses'), findsOneWidget);
    expect(find.text('Clauses'), findsOneWidget);
    expect(find.text('Prepositions'), findsOneWidget);
  });
}

class _FakeGrammarRepository implements GrammarRepository {
  @override
  Future<GrammarPageDetail> getPageDetail({required int sayfaId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<GrammarModule>> getModules() async => kModules;

  @override
  Future<List<GrammarPage>> getPagesByModule({required int modulId}) async {
    return const <GrammarPage>[];
  }
}
