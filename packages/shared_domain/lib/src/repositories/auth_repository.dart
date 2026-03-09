import 'dart:async';

import 'package:shared_core/shared_core.dart';

abstract interface class AuthRepository {
  Future<AuthSession> restoreSession();
  Future<AppResult<AuthSession>> refreshSession();
  Stream<AccessContext> watchAccessContext();
  Future<AppResult<AuthSession>> signInAnonymously();
  Future<AppResult<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  });
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  });
  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  });
  Future<AppResult<void>> signOut();
}
