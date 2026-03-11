import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

class FoundationAdminAnalyticsRepository implements AdminAnalyticsRepository {
  const FoundationAdminAnalyticsRepository({required AppConfig config})
    : _config = config;

  final AppConfig _config;

  @override
  Future<AppResult<AdminDashboardSnapshot>> fetchDashboardSnapshot({
    required int days,
  }) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminDashboardSnapshot>(_previewSnapshot(days));
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final response = await Supabase.instance.client.rpc<dynamic>(
        'admin_fetch_dashboard_snapshot',
        params: <String, dynamic>{'p_days': days},
      );
      return AppSuccess<AdminDashboardSnapshot>(
        AdminDashboardSnapshot.fromJson(_coerceMap(response)),
      );
    } catch (error) {
      return AppFailure<AdminDashboardSnapshot>(
        'Dashboard verisi yuklenemedi: $error',
      );
    }
  }
}

AdminDashboardSnapshot _previewSnapshot(int days) {
  final normalizedDays = switch (days) {
    30 => 30,
    90 => 90,
    _ => 7,
  };
  final baseTrend = switch (normalizedDays) {
    90 => const <double>[0.12, 0.19, 0.23, 0.28, 0.31, 0.41, 0.46],
    30 => const <double>[0.2, 0.24, 0.27, 0.35, 0.38, 0.44, 0.5],
    _ => const <double>[0.32, 0.35, 0.28, 0.47, 0.51, 0.63, 0.71],
  };
  return AdminDashboardSnapshot(
    windowDays: normalizedDays,
    userCount: const AdminDashboardMetric(total: 128, delta: 18),
    proUserCount: const AdminDashboardMetric(total: 46, delta: 6),
    wordCount: const AdminDashboardMetric(total: 842, delta: 52),
    readingCount: const AdminDashboardMetric(total: 118, delta: 9),
    grammarCount: const AdminDashboardMetric(total: 27, delta: 1),
    auditCount: const AdminDashboardMetric(total: 64, delta: 14),
    userTrend: List<AdminTrendPoint>.generate(
      baseTrend.length,
      (index) =>
          AdminTrendPoint(label: 'G${index + 1}', value: baseTrend[index]),
      growable: false,
    ),
    maintenanceMode: false,
  );
}

Map<String, dynamic> _coerceMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}
