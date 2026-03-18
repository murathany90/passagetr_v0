import 'dart:async';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class FakeAuthRepo implements AuthRepository {
  @override
  Future<AuthSession> restoreSession() async => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> refreshSession() async =>
      throw UnimplementedError();

  @override
  Stream<AccessContext> watchAccessContext() =>
      const Stream<AccessContext>.empty();

  @override
  Future<AppResult<AuthSession>> signInAnonymously() async =>
      throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<void>> resendSignUpConfirmation({
    required String email,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> updateDisplayName({
    required String displayName,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  }) async => throw UnimplementedError();

  @override
  Future<AppResult<void>> signOut() async => throw UnimplementedError();

  @override
  Future<AppResult<AppRole>> fetchCurrentRole() async =>
      const AppSuccess<AppRole>(AppRole.admin);

  @override
  void notifySessionExpired() {}

  @override
  Stream<void> get onSessionExpired => const Stream<void>.empty();
}
