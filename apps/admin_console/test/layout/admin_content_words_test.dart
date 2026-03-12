import 'package:admin_console/src/features/common/admin_page_parts.dart';
import 'package:admin_console/src/features/content/content_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('words CMS renders pack centric actions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1100);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminContentPage(destination: AdminDestination.words),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paketler'), findsOneWidget);
    expect(find.text('Yeni Paket'), findsOneWidget);
    expect(find.text('CSV Yukle'), findsOneWidget);
    expect(find.text('Filtreleri sifirla'), findsOneWidget);
    expect(find.textContaining('Kelimeleri'), findsOneWidget);
  });
}
