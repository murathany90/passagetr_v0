import 'package:admin_console/src/features/common/admin_page_parts.dart';
import 'package:admin_console/src/features/content/content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('readings CMS renders CSV import actions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminContentPage(destination: AdminDestination.readings),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Okuma Operasyonlari'), findsOneWidget);
    expect(find.text('Tumune Ata'), findsOneWidget);
    expect(find.text('CSV Yukle'), findsOneWidget);
    expect(find.text('Yeni Parca Ekle'), findsOneWidget);
    expect(find.text('Eksik Mini Testler'), findsOneWidget);
    expect(find.text('Eksik Kapaklar'), findsOneWidget);
    expect(find.text('Mini Test'), findsOneWidget);
    expect(find.text('Gorsel'), findsOneWidget);
    expect(find.text('Filtreleri sifirla'), findsOneWidget);
    expect(find.textContaining('odak 0'), findsWidgets);
  });
}
