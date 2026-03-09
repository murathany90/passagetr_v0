import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.claims,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final AuthUser? user;
  final Map<String, String> claims;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  bool get isAuthenticated => user != null;
  bool get isAnonymous => user?.isAnonymous ?? true;

  factory AuthSession.anonymous({
    Map<String, String> claims = const <String, String>{
      'app_role': 'user',
      'plan': 'free',
    },
  }) {
    return AuthSession(user: null, claims: claims);
  }
}
