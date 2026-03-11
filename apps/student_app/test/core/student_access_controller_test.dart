import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/student_access_controller.dart';

void main() {
  group('StudentAccessController', () {
    test(
      'refreshSession updates access context from refreshed claims',
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

        final controller = StudentAccessController(
          authRepository: repository,
          initialAccessContext: AccessContext.anonymous(),
        );

        final result = await controller.refreshSession();

        expect(result, isA<AppSuccess<AuthSession>>());
        expect(controller.state.canAccessAdmin, isTrue);
        expect(controller.state.canViewPremium, isTrue);
        expect(controller.state.email, 'admin@passagetr.dev');

        controller.dispose();
        repository.dispose();
      },
    );

    test(
      'upgradeAnonymousWithEmail updates anonymous session to registered user',
      () async {
        final repository = _FakeAuthRepository(
          upgradeResult: AppSuccess<AuthSession>(
            _authenticatedSession(
              role: AppRole.user,
              plan: EntitlementPlan.free,
              email: 'user@passagetr.dev',
            ),
          ),
        );

        final controller = StudentAccessController(
          authRepository: repository,
          initialAccessContext: AccessContext.anonymous(),
        );

        final result = await controller.upgradeAnonymousWithEmail(
          email: 'user@passagetr.dev',
          password: 'PassageTR#2026',
        );

        expect(result, isA<AppSuccess<AuthSession>>());
        expect(controller.state.isAnonymous, isFalse);
        expect(controller.state.isAuthenticated, isTrue);
        expect(controller.state.email, 'user@passagetr.dev');

        controller.dispose();
        repository.dispose();
      },
    );

    test(
      'updateDisplayName refreshes the access context display name',
      () async {
        final repository = _FakeAuthRepository(
          updateDisplayNameResult: AppSuccess<AuthSession>(
            _authenticatedSession(
              role: AppRole.user,
              plan: EntitlementPlan.free,
              email: 'user@passagetr.dev',
              displayName: 'Ada Lovelace',
            ),
          ),
        );

        final controller = StudentAccessController(
          authRepository: repository,
          initialAccessContext: AccessContext.preview(
            role: AppRole.user,
            plan: EntitlementPlan.free,
            isAnonymous: false,
          ),
        );

        final result = await controller.updateDisplayName(
          displayName: 'Ada Lovelace',
        );

        expect(result, isA<AppSuccess<AuthSession>>());
        expect(controller.state.session.user?.displayName, 'Ada Lovelace');

        controller.dispose();
        repository.dispose();
      },
    );
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    AppResult<AuthSession>? refreshResult,
    AppResult<AuthSession>? upgradeResult,
    AppResult<AuthSession>? updateDisplayNameResult,
  }) : _refreshResult =
           refreshResult ?? AppSuccess<AuthSession>(AuthSession.anonymous()),
       _upgradeResult =
           upgradeResult ?? AppSuccess<AuthSession>(AuthSession.anonymous()),
       _updateDisplayNameResult =
           updateDisplayNameResult ??
           AppSuccess<AuthSession>(AuthSession.anonymous());

  final StreamController<AccessContext> _controller =
      StreamController<AccessContext>.broadcast();
  final AppResult<AuthSession> _refreshResult;
  final AppResult<AuthSession> _upgradeResult;
  final AppResult<AuthSession> _updateDisplayNameResult;

  @override
  Future<AuthSession> restoreSession() async => AuthSession.anonymous();

  @override
  Future<AppResult<AuthSession>> refreshSession() async => _refreshResult;

  @override
  Stream<AccessContext> watchAccessContext() => _controller.stream;

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
    return _updateDisplayNameResult;
  }

  @override
  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    return _upgradeResult;
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
  String? displayName,
}) {
  return AuthSession(
    user: AuthUser(
      id: '${role.value}-user',
      email: email,
      isAnonymous: false,
      displayName: displayName,
    ),
    claims: <String, String>{'app_role': role.value, 'plan': plan.value},
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );
}
