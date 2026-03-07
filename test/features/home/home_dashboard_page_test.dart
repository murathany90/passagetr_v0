import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/home_dashboard_data.dart';
import 'package:passagetr/features/home/home_dashboard_page.dart';
import 'package:passagetr/state/dashboard_providers.dart';

void main() {
  Future<void> configureViewport(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    required HomeDashboardData data,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          homeMetricsProvider.overrideWith((Ref ref) async {
            return HomeMetricsData(
              todayWordCount: data.todayWordCount,
              todayReadSentenceCount: data.todayReadSentenceCount,
              todaySolvedQuestionText: data.todaySolvedQuestionText,
            );
          }),
          homeQuickStartProvider.overrideWith((Ref ref) async => data.quickStart),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HomeDashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop home dashboard shows split hero and metrics layout', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);
    await pumpPage(
      tester,
      data: const HomeDashboardData(
        todayWordCount: 12,
        todayReadSentenceCount: 7,
        todaySolvedQuestionText: '4',
        quickStart: QuickStartSuggestion(type: QuickStartType.unavailable),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('home-dashboard-desktop-layout')),
      findsOneWidget,
    );
    expect(find.text('Bugunku Egitim'), findsOneWidget);
    expect(find.text('Gunluk Metrikler'), findsOneWidget);
    expect(find.text('Gunluk Seri'), findsOneWidget);
    expect(find.text('Hizli Basla'), findsOneWidget);
  });
}
