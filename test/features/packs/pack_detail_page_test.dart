import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/i18n/tr_ui_texts.dart';
import 'package:passagetr/domain/entities/pack.dart';
import 'package:passagetr/features/packs/pack_list_page.dart';

void main() {
  const Pack pack = Pack(
    id: 'pack-1',
    name: 'YDS Set 001',
    fromLang: 'en',
    toLang: 'tr',
    wordCount: 100,
  );

  testWidgets('desktop pack detail uses action grid layout', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: PackDetailPage(pack: pack)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('pack-detail-desktop-layout')),
      findsOneWidget,
    );
    expect(find.text('Kisa Ozet'), findsOneWidget);
    expect(find.text(TrUiTexts.wordStudyCta), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Kelime Listesi'), findsOneWidget);
  });
}
