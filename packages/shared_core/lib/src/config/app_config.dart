import '../workspace_info.dart';
import 'app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.appName,
    required this.environment,
    required this.platformMode,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.adminPreviewEnabled,
  });

  final String appName;
  final AppEnvironment environment;
  final PlatformMode platformMode;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool adminPreviewEnabled;

  String get branchName => WorkspaceInfo.branchName;
  bool get supabaseEnabled =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  factory AppConfig.fromEnvironment({
    required String appName,
    required PlatformMode platformMode,
    bool adminPreviewEnabled = false,
  }) {
    const platformModeOverride = String.fromEnvironment('PLATFORM_MODE');

    return AppConfig(
      appName: appName,
      environment: AppEnvironment.fromValue(
        const String.fromEnvironment('APP_ENV', defaultValue: 'dev'),
      ),
      platformMode: platformModeOverride.isEmpty
          ? platformMode
          : PlatformMode.fromValue(platformModeOverride),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      adminPreviewEnabled: adminPreviewEnabled,
    );
  }
}
