import 'package:shared_core/shared_core.dart';

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.displayName,
    required this.preferredLocale,
    required this.themeMode,
    required this.accessContext,
  });

  final String userId;
  final String displayName;
  final String preferredLocale;
  final String themeMode;
  final AccessContext accessContext;
}
