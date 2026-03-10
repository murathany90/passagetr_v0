import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_console/src/bootstrap/admin_console_bootstrap.dart';

void main() {
  testWidgets('admin foundation shell renders', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      const ProviderScope(child: AdminConsoleBootstrap()),
    );
    await tester.pumpAndSettle();

    expect(find.text('PASSAGETR Dashboard'), findsOneWidget);
    expect(find.textContaining('Aksiyonlar'), findsOneWidget);
  });
}
