import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passagetr/domain/entities/home_dashboard_data.dart';
import 'package:passagetr/features/shell/main_shell_page.dart';
import 'package:passagetr/state/auth_providers.dart';
import 'package:passagetr/state/dashboard_providers.dart';
import 'package:passagetr/state/nav_badge_providers.dart';

void main() {
  Future<void> configureViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('MainShellPage shows 5 tabs without Sozluk tab', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authBootstrapProvider.overrideWith((Ref ref) async {}),
          weakWordCountProvider.overrideWith((Ref ref) async => 0),
          homeDashboardProvider.overrideWith((Ref ref) async {
            return const HomeDashboardData(
              todayWordCount: 0,
              todayReadSentenceCount: 0,
              todaySolvedQuestionText: 'Yakinda',
              quickStart: QuickStartSuggestion(
                type: QuickStartType.randomWords,
                wordIds: <String>['w1'],
              ),
            );
          }),
        ],
        child: const MaterialApp(
          home: MainShellPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Kelime'), findsOneWidget);
    expect(find.text('Okuma'), findsOneWidget);
    expect(find.text('Gramer'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Sozluk'), findsNothing);
  });
}

