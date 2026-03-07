import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../utils/network_error_classifier.dart';

class AuthSessionService {
  AuthSessionService(this._client);

  final SupabaseClient _client;

  /// Whether the last auth attempt was skipped due to network unavailability.
  bool _offlineSkipped = false;
  bool get isOfflineSkipped => _offlineSkipped;

  Future<void> ensureAnonymousSession() async {
    final Session? session = _client.auth.currentSession;
    if (session != null) {
      _offlineSkipped = false;
      return;
    }

    try {
      await _client.auth.signInAnonymously();
      _offlineSkipped = false;
    } catch (error) {
      // Network errors → offline mode, skip auth silently
      if (_isNetworkError(error)) {
        _offlineSkipped = true;
        return;
      }
      if (_canUseDevFallback) {
        return;
      }
      throw AuthSessionException(
        'Anonymous giris basarisiz: $error',
      );
    }

    if (_client.auth.currentSession == null) {
      if (_canUseDevFallback || _offlineSkipped) {
        return;
      }
      throw const AuthSessionException('Anonymous giris olusturulamadi.');
    }
  }

  bool get _canUseDevFallback =>
      kDebugMode &&
      AppConfig.allowDemoFallback &&
      AppConfig.demoUserUuid.isNotEmpty;

  /// Checks if the error is a network connectivity issue.
  static bool _isNetworkError(Object error) {
    return NetworkErrorClassifier.isNetworkLikeError(error);
  }
}

class AuthSessionException implements Exception {
  const AuthSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}
