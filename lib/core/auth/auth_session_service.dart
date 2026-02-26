import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class AuthSessionService {
  AuthSessionService(this._client);

  final SupabaseClient _client;

  Future<void> ensureAnonymousSession() async {
    final Session? session = _client.auth.currentSession;
    if (session != null) {
      return;
    }

    try {
      await _client.auth.signInAnonymously();
    } catch (error) {
      if (_canUseDevFallback) {
        return;
      }
      throw AuthSessionException(
        'Anonymous giris basarisiz: $error',
      );
    }

    if (_client.auth.currentSession == null) {
      if (_canUseDevFallback) {
        return;
      }
      throw const AuthSessionException('Anonymous giris olusturulamadi.');
    }
  }

  bool get _canUseDevFallback =>
      kDebugMode &&
      AppConfig.allowDemoFallback &&
      AppConfig.demoUserUuid.isNotEmpty;
}

class AuthSessionException implements Exception {
  const AuthSessionException(this.message);

  final String message;

  @override
  String toString() => message;
}
