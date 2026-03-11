import 'package:shared_core/shared_core.dart';

import '../entities/admin_console_contracts.dart';

abstract interface class AdminAnalyticsRepository {
  Future<AppResult<AdminDashboardSnapshot>> fetchDashboardSnapshot({
    required int days,
  });
}
