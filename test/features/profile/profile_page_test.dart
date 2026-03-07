import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/home_dashboard_data.dart';
import 'package:passagetr/domain/entities/pack.dart';
import 'package:passagetr/features/profile/profile_page.dart';
import 'package:passagetr/state/dashboard_providers.dart';
import 'package:passagetr/state/pack_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          homeMetricsProvider.overrideWith((Ref ref) async {
            return const HomeMetricsData(
              todayWordCount: 8,
              todayReadSentenceCount: 5,
              todaySolvedQuestionText: '3',
            );
          }),
          packListProvider.overrideWith((Ref ref) async {
            return const <Pack>[
              Pack(
                id: 'pack-1',
                name: 'YDS Set 001',
                fromLang: 'en',
                toLang: 'tr',
                wordCount: 1000,
              ),
            ];
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('desktop profile shows split layout with settings panel', (
    WidgetTester tester,
  ) async {
    await configureViewport(tester);
    await pumpPage(tester);

    expect(
      find.byKey(const ValueKey<String>('profile-page-desktop-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('profile-settings-panel')),
      findsOneWidget,
    );
    expect(find.text('Bugunun Ozeti'), findsOneWidget);
    expect(find.text('Sistem Durumu'), findsOneWidget);
    expect(find.text('Profil Ayarlari'), findsOneWidget);
  });
}
