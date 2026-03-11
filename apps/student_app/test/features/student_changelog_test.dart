import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/core/student_providers.dart';
import 'package:student_app/src/features/changelog/changelog_page.dart';
import 'package:student_app/src/features/common/page_parts.dart';
import 'package:student_app/src/features/profile/profile_page.dart';

void main() {
  Future<ProviderContainer> pumpProfileRoute(
    WidgetTester tester, {
    required Size size,
    bool authenticated = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    if (authenticated) {
      container.read(studentAccessProvider.notifier).setAnonymous(false);
    }

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              StudentAppShell(state: state, child: child),
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const StudentProfilePage(),
            ),
            GoRoute(
              path: '/changelog',
              builder: (context, state) => const StudentChangelogPage(),
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

  testWidgets('sidebar version chip opens changelog page', (tester) async {
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
                title: 'Home',
                subtitle: 'Body',
                accessContext: AccessContext.preview(
                  role: AppRole.user,
                  plan: EntitlementPlan.free,
                  isAnonymous: true,
                ),
                body: const SizedBox(height: 120, child: Text('Home body')),
              ),
            ),
            GoRoute(
              path: '/changelog',
              builder: (context, state) => const StudentChangelogPage(),
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

    expect(find.text(WorkspaceInfo.appVersion), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('sidebar_version_chip')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Surum Notlari'), findsOneWidget);
    expect(find.text('Canli release surum standardi'), findsAtLeastNWidgets(1));
    expect(find.text(WorkspaceInfo.appVersion), findsWidgets);
  });

  testWidgets('mobile guest profile shows release card and opens changelog', (
    tester,
  ) async {
    await pumpProfileRoute(tester, size: const Size(390, 844));

    expect(
      find.byKey(const ValueKey<String>('profile_release_info_card')),
      findsOneWidget,
    );
    expect(find.text(WorkspaceInfo.appVersion), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('sidebar_version_chip')),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('profile_release_notes_button')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('profile_release_notes_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Surum Notlari'), findsOneWidget);
    expect(find.text(WorkspaceInfo.appVersion), findsWidgets);
  });

  testWidgets('mobile authenticated profile also shows release card', (
    tester,
  ) async {
    await pumpProfileRoute(
      tester,
      size: const Size(390, 844),
      authenticated: true,
    );

    expect(find.text('Profil'), findsAtLeastNWidgets(1));
    expect(
      find.byKey(const ValueKey<String>('profile_release_info_card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile_release_notes_button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'wide profile keeps sidebar chip and avoids duplicate release card',
    (tester) async {
      await pumpProfileRoute(tester, size: const Size(1280, 900));

      expect(
        find.byKey(const ValueKey<String>('sidebar_version_chip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('profile_release_info_card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('profile_release_notes_button')),
        findsNothing,
      );
    },
  );
}
