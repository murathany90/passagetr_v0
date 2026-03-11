import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';

class FoundationAdminSettingsRepository implements AdminSettingsRepository {
  const FoundationAdminSettingsRepository({required AppConfig config})
    : _config = config;

  final AppConfig _config;

  @override
  Future<AppResult<AdminSettingsSnapshot>> fetchSettings() async {
    if (!_config.supabaseEnabled) {
      return const AppSuccess<AdminSettingsSnapshot>(AdminSettingsSnapshot());
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final response = await Supabase.instance.client.rpc<dynamic>(
        'admin_get_settings',
      );
      return AppSuccess<AdminSettingsSnapshot>(
        AdminSettingsSnapshot.fromJson(_coerceMap(response)),
      );
    } catch (error) {
      return AppFailure<AdminSettingsSnapshot>('Ayarlar yuklenemedi: $error');
    }
  }

  @override
  Future<AppResult<AdminSettingsSnapshot>> saveSettings(
    AdminSettingsSnapshot snapshot,
  ) async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AdminSettingsSnapshot>(snapshot);
    }

    try {
      await SupabaseBootstrap.initialize(_config);
      final response = await Supabase.instance.client.rpc<dynamic>(
        'admin_upsert_settings',
        params: <String, dynamic>{'p_payload': snapshot.toJson()},
      );
      return AppSuccess<AdminSettingsSnapshot>(
        AdminSettingsSnapshot.fromJson(_coerceMap(response)),
      );
    } catch (error) {
      return AppFailure<AdminSettingsSnapshot>('Ayarlar kaydedilemedi: $error');
    }
  }
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
