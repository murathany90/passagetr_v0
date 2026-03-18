import 'dart:async';

import 'package:admin_console/src/core/admin_access_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

void main() {
  group('AdminAccessController', () {
    test(
      'refreshSession grants admin access when refreshed claims include admin role',
      () async {
        final repository = _FakeAuthRepository(
          refreshResult: AppSuccess<AuthSession>(
            _authenticatedSession(
              role: AppRole.admin,
              plan: EntitlementPlan.pro,
              email: 'admin@passagetr.dev',
            ),
          ),
        );

        final controller = AdminAccessController(
          authRepository: repository,
          initialAccessContext: AccessContext.anonymous(),
        );

        final result = await controller.refreshSession();

        expect(result, isA<AppSuccess<AuthSession>>());
        expect(controller.state.accessContext.canAccessAdmin, isTrue);
        expect(controller.state.accessContext.canViewPremium, isTrue);
        expect(controller.state.accessContext.email, 'admin@passagetr.dev');

        controller.dispose();
        repository.dispose();
      },
    );

    test('signOut resets access context to anonymous', () async {
      final repository = _FakeAuthRepository();
      final controller = AdminAccessController(
        authRepository: repository,
        initialAccessContext: AccessContext.preview(
          role: AppRole.admin,
          plan: EntitlementPlan.pro,
          isAnonymous: false,
        ),
      );

      final result = await controller.signOut();

      expect(result, isA<AppSuccess<void>>());
      expect(controller.state.accessContext.isAnonymous, isTrue);
      expect(controller.state.accessContext.canAccessAdmin, isFalse);

      controller.dispose();
      repository.dispose();
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AppResult<AuthSession>? refreshResult})
    : _refreshResult =
          refreshResult ?? AppSuccess<AuthSession>(AuthSession.anonymous());

  final StreamController<AccessContext> _controller =
      StreamController<AccessContext>.broadcast();
  final AppResult<AuthSession> _refreshResult;

  @override
  Future<AuthSession> restoreSession() async => AuthSession.anonymous();

  @override
  Future<AppResult<AuthSession>> refreshSession() async => _refreshResult;

  @override
  Stream<AccessContext> watchAccessContext() => _controller.stream;

  @override
  Future<AppResult<AppRole>> fetchCurrentRole() async => AppSuccess(AppRole.user);

  @override
  void notifySessionExpired() {}

  @override
  Stream<void> get onSessionExpired => Stream.empty();

  @override
  Future<AppResult<AuthSession>> signInAnonymously() async {
    return AppSuccess<AuthSession>(AuthSession.anonymous());
  }

  @override
  Future<AppResult<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return AppFailure<AuthSession>('not used in test');
  }

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return AppFailure<AuthSession>('not used in test');
  }

  @override
  Future<AppResult<void>> resendSignUpConfirmation({
    required String email,
  }) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<AuthSession>> updateDisplayName({
    required String displayName,
  }) async {
    return AppFailure<AuthSession>('not used in test');
  }

  @override
  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    return AppFailure<AuthSession>('not used in test');
  }

  @override
  Future<AppResult<void>> signOut() async => const AppSuccess<void>(null);

  void dispose() {
    _controller.close();
  }
}

AuthSession _authenticatedSession({
  required AppRole role,
  required EntitlementPlan plan,
  required String email,
}) {
  return AuthSession(
    user: AuthUser(id: '${role.value}-user', email: email, isAnonymous: false),
    claims: <String, String>{'app_role': role.value, 'plan': plan.value},
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );
}
