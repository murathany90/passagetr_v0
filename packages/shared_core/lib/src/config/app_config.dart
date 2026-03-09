import '../workspace_info.dart';
import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.environment,
    required this.platformMode,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.adminConsoleUrl,
    required this.adminPreviewEnabled,
  });

  final String appName;
  final AppEnvironment environment;
  final PlatformMode platformMode;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String adminConsoleUrl;
  final bool adminPreviewEnabled;

  String get branchName => WorkspaceInfo.branchName;
  bool get supabaseEnabled =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
  bool get adminConsoleEnabled => adminConsoleUrl.trim().isNotEmpty;

  factory AppConfig.fromEnvironment({
    required String appName,
    required PlatformMode platformMode,
    bool adminPreviewEnabled = false,
  }) {
    const platformModeOverride = String.fromEnvironment('PLATFORM_MODE');
    final environment = AppEnvironment.fromValue(
      const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
    );
    final resolvedPlatformMode = platformModeOverride.isEmpty
        ? platformMode
        : PlatformMode.fromValue(platformModeOverride);
    const adminConsoleUrl = String.fromEnvironment('ADMIN_CONSOLE_URL');
    final fallbackAdminConsoleUrl = environment == AppEnvironment.dev
        ? switch (resolvedPlatformMode) {
            PlatformMode.web => 'http://127.0.0.1:8152/',
            PlatformMode.mobile => 'http://10.0.2.2:8152/',
          }
        : '';

    return AppConfig(
      appName: appName,
      environment: environment,
      platformMode: resolvedPlatformMode,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      adminConsoleUrl: adminConsoleUrl.isEmpty
          ? fallbackAdminConsoleUrl
          : adminConsoleUrl,
      adminPreviewEnabled: adminPreviewEnabled,
    );
  }
}
