import 'package:admin_console/src/features/users/users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets('users row menu exposes edit and delete actions', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2200, 1400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Duzenle'), findsOneWidget);
    expect(find.text('Kullaniciyi sil'), findsOneWidget);
  });

  testWidgets('bulk selection exposes delete chip and confirm dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2200, 1400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminUsersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('Kullanicilari Sil'), findsOneWidget);

    await tester.tap(find.text('Kullanicilari Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Secili kullanicilari sil'), findsOneWidget);
    expect(find.text('Secilenleri Sil'), findsOneWidget);

    await tester.tap(find.text('Secilenleri Sil'));
    await tester.pumpAndSettle();

    expect(find.text('3 kullanici silindi.'), findsOneWidget);
  });
}
