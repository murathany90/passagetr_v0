import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/core/student_providers.dart';
import 'package:student_app/src/features/common/page_parts.dart';

void main() {
  Future<ProviderContainer> pumpShell(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              StudentAppShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => StudentShellFrame(
                destination: StudentDestination.home,
                title: 'Responsive Test',
                subtitle: 'Layout behavior',
                accessContext: AccessContext.preview(
                  role: AppRole.user,
                  plan: EntitlementPlan.free,
                  isAnonymous: true,
                ),
                body: const SizedBox(height: 120, child: Text('Body')),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return container;
  }

  testWidgets('uses giriş entry on narrow anonymous layouts', (tester) async {
    await pumpShell(tester, size: const Size(390, 844));

    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Giriş'), findsOneWidget);
    expect(find.text('Profil'), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.text(WorkspaceInfo.appVersion), findsNothing);
  });

  testWidgets('uses sidebar rail on wide anonymous layouts', (tester) async {
    await pumpShell(tester, size: const Size(1280, 900));

    expect(find.text(WorkspaceInfo.appVersion), findsOneWidget);
    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Giriş'), findsOneWidget);
    expect(find.text('Profil'), findsNothing);
    expect(find.text('12'), findsNothing);
    expect(find.text('Çıkış Yap'), findsNothing);
  });

  testWidgets('switches giriş entry to profil after authentication', (
    tester,
  ) async {
    final container = await pumpShell(tester, size: const Size(390, 844));

    container.read(studentAccessProvider.notifier).setAnonymous(false);
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Giriş'), findsNothing);
  });

  testWidgets('shows sidebar logout action on wide authenticated layouts', (
    tester,
  ) async {
    final container = await pumpShell(tester, size: const Size(1280, 900));

    container.read(studentAccessProvider.notifier).setAnonymous(false);
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsAtLeastNWidgets(1));
    expect(find.text('Çıkış Yap'), findsOneWidget);

    await tester.tap(find.text('Çıkış Yap'));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsNothing);
    expect(find.text('Giriş'), findsAtLeastNWidgets(1));
  });
}
