import 'package:shared_core/shared_core.dart';

import '../entities/admin_console_contracts.dart';

abstract interface class AdminSettingsRepository {
  Future<AppResult<AdminSettingsSnapshot>> fetchSettings();

  Future<AppResult<AdminSettingsSnapshot>> saveSettings(
    AdminSettingsSnapshot snapshot,
  );
}
