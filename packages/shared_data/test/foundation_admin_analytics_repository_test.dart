import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

void main() {
  test(
    'fetchDashboardSnapshot returns preview coverage metrics when Supabase is disabled',
    () async {
      const repository = FoundationAdminAnalyticsRepository(
        config: AppConfig(
          appName: 'admin_console',
          environment: AppEnvironment.dev,
          platformMode: PlatformMode.web,
          supabaseUrl: '',
          supabaseAnonKey: '',
          adminConsoleUrl: '',
          adminPreviewEnabled: true,
        ),
      );

      final result = await repository.fetchDashboardSnapshot(days: 7);

      expect(result, isA<AppSuccess<AdminDashboardSnapshot>>());
      final snapshot = (result as AppSuccess<AdminDashboardSnapshot>).value;
      expect(snapshot.readingInventory.total, greaterThan(0));
      expect(snapshot.miniTestCoverage.readyCount, greaterThan(0));
      expect(snapshot.coverCoverage.missingCount, greaterThan(0));
      expect(snapshot.dictionaryEntryCount, greaterThan(0));
      expect(snapshot.contentTrend, isNotEmpty);
    },
  );
}
