import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class StudentAccessController extends StateNotifier<AccessContext> {
  StudentAccessController({
    required AuthRepository authRepository,
    required AccessContext initialAccessContext,
  }) : _authRepository = authRepository,
       super(initialAccessContext) {
    _subscription = _authRepository.watchAccessContext().listen((context) {
      state = context;
    });
  }

  final AuthRepository _authRepository;
  StreamSubscription<AccessContext>? _subscription;

  Future<void> restoreSession() async {
    final session = await _authRepository.restoreSession();
    state = AccessContext.fromSession(session);
  }

  Future<AppResult<AuthSession>> refreshSession() async {
    final result = await _authRepository.refreshSession();
    _updateFromResult(result);
    return result;
  }

  Future<AppResult<AuthSession>> signInAnonymously() async {
    final result = await _authRepository.signInAnonymously();
    _updateFromResult(result);
    return result;
  }

  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
    _updateFromResult(result);
    return result;
  }

  Future<AppResult<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _authRepository.signUpWithEmail(
      email: email,
      password: password,
    );
    _updateFromResult(result);
    return result;
  }

  Future<AppResult<void>> resendSignUpConfirmation({required String email}) {
    return _authRepository.resendSignUpConfirmation(email: email);
  }

  Future<AppResult<AuthSession>> updateDisplayName({
    required String displayName,
  }) async {
    final result = await _authRepository.updateDisplayName(
      displayName: displayName,
    );
    if (result is AppFailure<AuthSession> &&
        result.message ==
            'Display name update requires a registered session.' &&
        state.hasIdentifiedProfile &&
        state.session.user != null) {
      final session = AuthSession(
        user: AuthUser(
          id: state.session.user!.id,
          email: state.session.user!.email,
          isAnonymous: state.session.user!.isAnonymous,
          displayName: displayName.trim(),
        ),
        claims: Map<String, String>.from(state.session.claims),
        accessToken: state.session.accessToken,
        refreshToken: state.session.refreshToken,
        expiresAt: state.session.expiresAt,
      );
      state = AccessContext.fromSession(session);
      return AppSuccess<AuthSession>(session);
    }

    _updateFromResult(result);
    return result;
  }

  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _authRepository.upgradeAnonymousWithEmail(
      email: email,
      password: password,
    );
    _updateFromResult(result);
    return result;
  }

  Future<AppResult<void>> signOut() async {
    final result = await _authRepository.signOut();
    if (result is AppSuccess<void>) {
      state = AccessContext.anonymous();
    }
    return result;
  }

  void setRole(AppRole role) {
    state = AccessContext.preview(
      role: role,
      plan: state.plan,
      isAnonymous: role == AppRole.user ? state.isAnonymous : false,
    );
  }

  void setPlan(EntitlementPlan plan) {
    state = AccessContext.preview(
      role: state.role,
      plan: plan,
      isAnonymous: state.isAnonymous,
    );
  }

  void setAnonymous(bool isAnonymous) {
    state = AccessContext.preview(
      role: state.role,
      plan: state.plan,
      isAnonymous: isAnonymous,
    );
  }

  void _updateFromResult(AppResult<AuthSession> result) {
    if (result is AppSuccess<AuthSession>) {
      state = AccessContext.fromSession(result.value);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
