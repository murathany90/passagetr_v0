import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

import 'admin_console_models.dart';

class AdminAccessController extends StateNotifier<AdminAuthState> {
  AdminAccessController({
    required AuthRepository authRepository,
    AccessContext? initialAccessContext,
  }) : _authRepository = authRepository,
       super(
         AdminAuthState(
           status: AdminAuthStatus.bootstrapping,
           accessContext: initialAccessContext ?? AccessContext.anonymous(),
         ),
       ) {
    _subscription = _authRepository.watchAccessContext().listen((context) {
      if (_suspendStreamUpdates) {
        return;
      }
      state = _stateForContext(context);
    });
  }

  final AuthRepository _authRepository;
  StreamSubscription<AccessContext>? _subscription;
  bool _suspendStreamUpdates = false;

  Future<void> restoreSession() async {
    state = state.copyWith(
      status: AdminAuthStatus.bootstrapping,
      clearMessage: true,
    );
    _suspendStreamUpdates = true;
    final session = await _authRepository.restoreSession();
    _suspendStreamUpdates = false;
    state = _stateForContext(AccessContext.fromSession(session));
  }

  Future<AppResult<AuthSession>> refreshSession() async {
    state = state.copyWith(status: AdminAuthStatus.busy, clearMessage: true);
    _suspendStreamUpdates = true;
    final result = await _authRepository.refreshSession();
    _suspendStreamUpdates = false;
    _updateFromResult(result);
    return result;
  }

  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AdminAuthStatus.busy, clearMessage: true);
    _suspendStreamUpdates = true;
    final signInResult = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );
    if (signInResult case AppFailure<AuthSession>()) {
      _suspendStreamUpdates = false;
      state = AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        accessContext: AccessContext.anonymous(),
        message: signInResult.message,
      );
      return signInResult;
    }

    final signedInContext = AccessContext.fromSession(
      (signInResult as AppSuccess<AuthSession>).value,
    );
    final refreshResult = await _authRepository.refreshSession();
    final resolvedContext = switch (refreshResult) {
      AppSuccess<AuthSession>() => AccessContext.fromSession(
        refreshResult.value,
      ),
      AppFailure<AuthSession>() => signedInContext,
    };
    _suspendStreamUpdates = false;

    if (!resolvedContext.canAccessAdmin) {
      await _authRepository.signOut();
      state = AdminAuthState(
        status: AdminAuthStatus.unauthorized,
        accessContext: AccessContext.anonymous(),
        message: 'Bu hesap admin console yetkisine sahip degil.',
      );
      return const AppFailure<AuthSession>(
        'Bu hesap admin console yetkisine sahip degil.',
      );
    }

    state = _stateForContext(resolvedContext);
    return AppSuccess<AuthSession>(resolvedContext.session);
  }

  Future<AppResult<void>> signOut() async {
    _suspendStreamUpdates = true;
    final result = await _authRepository.signOut();
    _suspendStreamUpdates = false;
    if (result is AppSuccess<void>) {
      state = AdminAuthState(
        status: AdminAuthStatus.unauthenticated,
        accessContext: AccessContext.anonymous(),
      );
    }
    return result;
  }

  Future<void> expireSession({
    String message = 'Oturum suresi doldu. Lutfen tekrar giris yap.',
  }) async {
    _suspendStreamUpdates = true;
    await _authRepository.signOut();
    _suspendStreamUpdates = false;
    state = AdminAuthState(
      status: AdminAuthStatus.sessionExpired,
      accessContext: AccessContext.anonymous(),
      message: message,
    );
  }

  void clearMessage() {
    if (state.message == null) {
      return;
    }
    state = state.copyWith(clearMessage: true);
  }

  void setRole(AppRole role) {
    final accessContext = AccessContext.preview(
      role: role,
      plan: state.accessContext.plan,
      isAnonymous: false,
    );
    state = AdminAuthState(
      status: AdminAuthStatus.authenticated,
      accessContext: accessContext,
    );
  }

  void setPlan(EntitlementPlan plan) {
    final accessContext = AccessContext.preview(
      role: state.accessContext.role,
      plan: plan,
      isAnonymous: false,
    );
    state = AdminAuthState(
      status: AdminAuthStatus.authenticated,
      accessContext: accessContext,
    );
  }

  void _updateFromResult(AppResult<AuthSession> result) {
    if (result is AppSuccess<AuthSession>) {
      state = _stateForContext(AccessContext.fromSession(result.value));
    } else if (result is AppFailure<AuthSession>) {
      state = state.copyWith(
        status: _statusForContext(state.accessContext),
        message: result.message,
      );
    }
  }

  AdminAuthState _stateForContext(AccessContext context, {String? message}) {
    return AdminAuthState(
      status: _statusForContext(context),
      accessContext: context,
      message: message,
    );
  }

  AdminAuthStatus _statusForContext(AccessContext context) {
    if (context.canAccessAdmin) {
      return AdminAuthStatus.authenticated;
    }
    if (!context.isAuthenticated || context.isAnonymous) {
      return AdminAuthStatus.unauthenticated;
    }
    return AdminAuthStatus.unauthorized;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
