import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/features/common/page_parts.dart';

void main() {
  testWidgets('wide light-theme sidebar keeps readable nav labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
                title: 'Sidebar Test',
                subtitle: 'Light theme rail',
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
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final okumaLabel = tester.widget<Text>(find.text('Okuma').first);

    expect(okumaLabel.style?.color, const Color(0xFF5A6D8B));
  });
}
