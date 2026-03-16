import 'package:admin_console/src/core/admin_console_models.dart';
import 'package:admin_console/src/core/admin_providers.dart';
import 'package:admin_console/src/features/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

void main() {
  testWidgets(
    'dashboard renders content coverage cards and content trend labels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1800, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const snapshot = AdminDashboardSnapshot(
        windowDays: 7,
        userCount: AdminDashboardMetric(total: 44, delta: -7),
        proUserCount: AdminDashboardMetric(total: 3, delta: 3),
        readingInventory: AdminDashboardInventoryMetric(
          total: 666,
          publishedCount: 644,
        ),
        wordInventory: AdminDashboardInventoryMetric(
          total: 5346,
          publishedCount: 5314,
        ),
        grammarInventory: AdminDashboardInventoryMetric(
          total: 12,
          publishedCount: 12,
        ),
        miniTestCoverage: AdminDashboardCoverageMetric(
          total: 666,
          readyCount: 644,
          missingCount: 22,
        ),
        coverCoverage: AdminDashboardCoverageMetric(
          total: 666,
          readyCount: 633,
          missingCount: 33,
        ),
        linkedWordCoverage: AdminDashboardCoverageMetric(
          total: 666,
          readyCount: 650,
          missingCount: 16,
        ),
        dictionaryMatchCoverage: AdminDashboardCoverageMetric(
          total: 5314,
          readyCount: 4800,
          missingCount: 514,
        ),
        dictionaryEntryCount: 18240,
        auditCount: AdminDashboardMetric(total: 964, delta: 964),
        contentTrend: <AdminTrendPoint>[
          AdminTrendPoint(label: '08 Mar', value: 11),
          AdminTrendPoint(label: '09 Mar', value: 4),
          AdminTrendPoint(label: '10 Mar', value: 9),
        ],
        maintenanceMode: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAccessProvider.overrideWith(
              (ref) => AccessContext.preview(
                role: AppRole.admin,
                plan: EntitlementPlan.pro,
                isAnonymous: false,
              ),
            ),
            adminDashboardSnapshotProvider.overrideWith(
              (ref) async => snapshot,
            ),
            adminAuditFeedProvider.overrideWith(
              (ref) async =>
                  const AdminAuditFeed.empty('Henuz audit kaydi olusmadi.'),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AdminDashboardPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Icerik Operasyon Trendi'), findsOneWidget);
      expect(find.text('Mini Test Hazirligi'), findsOneWidget);
      expect(find.text('Kapak Hazirligi'), findsOneWidget);
      expect(find.text('Sozluk Eslesmesi'), findsOneWidget);
      expect(find.text('644 / 22'), findsOneWidget);
      expect(find.text('633 / 33'), findsOneWidget);
      expect(find.text('Yayinda 5314'), findsOneWidget);
      expect(find.text('08 Mar: 11'), findsOneWidget);
      expect(find.text('-674'), findsNothing);
    },
  );
}
