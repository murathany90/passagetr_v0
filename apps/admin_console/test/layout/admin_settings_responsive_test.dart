import 'package:admin_console/src/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  Future<void> pumpSettings(WidgetTester tester, {required Size size}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('stacks settings panels on narrow widths', (tester) async {
    await pumpSettings(tester, size: const Size(920, 1100));

    final editorOffset = tester.getTopLeft(find.text('Product Config'));
    final envOffset = tester.getTopLeft(find.text('Sistem Ozeti'));

    expect(envOffset.dy, greaterThan(editorOffset.dy + 200));
  });

  testWidgets('places settings panels side by side on wide widths', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(1440, 1100));

    final editorOffset = tester.getTopLeft(find.text('Product Config'));
    final envOffset = tester.getTopLeft(find.text('Sistem Ozeti'));
    final auditOffset = tester.getTopLeft(find.text('Audit Akisi'));

    expect(envOffset.dx, greaterThan(editorOffset.dx + 120));
    expect(auditOffset.dy, greaterThan(envOffset.dy + 40));
  });
}
