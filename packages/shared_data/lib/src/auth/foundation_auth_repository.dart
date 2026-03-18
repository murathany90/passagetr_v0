import 'dart:async';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../bootstrap/supabase_bootstrap.dart';

class FoundationAuthRepository implements AuthRepository {
  FoundationAuthRepository({
    required AppConfig config,
    required AccessContext fallbackAccessContext,
  }) : _config = config,
       _fallbackAccessContext = fallbackAccessContext,
       _current = fallbackAccessContext {
    _controller.add(_current);
  }

  final AppConfig _config;
  final AccessContext _fallbackAccessContext;
  final StreamController<AccessContext> _controller =
      StreamController<AccessContext>.broadcast();
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();
  StreamSubscription<AuthState>? _authSubscription;

  AccessContext _current;

  @override
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  @override
  void notifySessionExpired() {
    _sessionExpiredController.add(null);
  }

  @override
  Future<AuthSession> restoreSession() async {
    await _ensureSupabaseReady();

    if (!_config.supabaseEnabled) {
      _emit(_fallbackAccessContext);
      return _current.session;
    }

    _ensureAuthSubscription();
    final session = await _resolveValidSupabaseSession();
    await _emitResolvedContext(session);
    return _current.session;
  }

  @override
  Future<AppResult<AuthSession>> refreshSession() async {
    if (!_config.supabaseEnabled) {
      _emit(_current);
      return AppSuccess<AuthSession>(_current.session);
    }

    try {
      await _ensureSupabaseReady();
      _ensureAuthSubscription();

      final session = await _resolveValidSupabaseSession(forceRefresh: true);

      await _emitResolvedContext(session);
      return AppSuccess<AuthSession>(_current.session);
    } catch (error) {
      return AppFailure<AuthSession>('Session refresh failed.', cause: error);
    }
  }

  @override
  Stream<AccessContext> watchAccessContext() => _controller.stream;

  @override
  Future<AppResult<AuthSession>> signInAnonymously() async {
    if (!_config.supabaseEnabled) {
      final preview = AccessContext.preview(
        role: AppRole.user,
        plan: EntitlementPlan.free,
        isAnonymous: true,
      );
      _emit(preview);
      return AppSuccess<AuthSession>(_current.session);
    }

    try {
      await _ensureSupabaseReady();
      _ensureAuthSubscription();
      final response = await Supabase.instance.client.auth.signInAnonymously();
      await _emitResolvedContext(
        response.session ?? Supabase.instance.client.auth.currentSession,
      );
      return AppSuccess<AuthSession>(_current.session);
    } catch (error) {
      return AppFailure<AuthSession>('Anonymous sign-in failed.', cause: error);
    }
  }

  @override
  Future<AppResult<AuthSession>> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AuthSession>(
        'Supabase environment variables are not configured yet.',
      );
    }

    try {
      await _ensureSupabaseReady();
      _ensureAuthSubscription();
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );
      final resolvedSession =
          response.session ?? Supabase.instance.client.auth.currentSession;
      if (resolvedSession != null) {
        await _emitResolvedContext(resolvedSession);
        return AppSuccess<AuthSession>(_current.session);
      }

      _emit(AccessContext.anonymous());
      return AppSuccess<AuthSession>(AccessContext.anonymous().session);
    } catch (error) {
      return AppFailure<AuthSession>(
        _signUpFailureMessage(error),
        cause: error,
      );
    }
  }

  @override
  Future<AppResult<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AuthSession>(
        'Supabase environment variables are not configured yet.',
      );
    }

    try {
      await _ensureSupabaseReady();
      _ensureAuthSubscription();
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _emitResolvedContext(
        response.session ?? Supabase.instance.client.auth.currentSession,
      );
      return AppSuccess<AuthSession>(_current.session);
    } catch (error) {
      return AppFailure<AuthSession>(
        _signInFailureMessage(error),
        cause: error,
      );
    }
  }

  @override
  Future<AppResult<void>> resendSignUpConfirmation({
    required String email,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return const AppFailure<void>('E-posta zorunlu.');
    }

    if (!_config.supabaseEnabled) {
      return const AppFailure<void>(
        'Supabase environment variables are not configured yet.',
      );
    }

    try {
      await _ensureSupabaseReady();
      await Supabase.instance.client.auth.resend(
        email: normalizedEmail,
        type: OtpType.signup,
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>(
        _resendConfirmationFailureMessage(error),
        cause: error,
      );
    }
  }

  @override
  Future<AppResult<AuthSession>> updateDisplayName({
    required String displayName,
  }) async {
    final normalizedDisplayName = displayName.trim();
    if (normalizedDisplayName.isEmpty) {
      return const AppFailure<AuthSession>('Display name is required.');
    }

    final currentUser = _current.session.user;
    if (currentUser == null || currentUser.isAnonymous) {
      return const AppFailure<AuthSession>(
        'Display name update requires a registered session.',
      );
    }

    if (!_config.supabaseEnabled) {
      final updatedSession = _sessionWithDisplayName(
        _current.session,
        normalizedDisplayName,
      );
      _emit(AccessContext.fromSession(updatedSession));
      return AppSuccess<AuthSession>(_current.session);
    }

    try {
      await _ensureSupabaseReady();
      _ensureAuthSubscription();

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: <String, dynamic>{'display_name': normalizedDisplayName},
        ),
      );

      return refreshSession();
    } catch (error) {
      return AppFailure<AuthSession>(
        'Display name update failed.',
        cause: error,
      );
    }
  }

  @override
  Future<AppResult<AuthSession>> upgradeAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_config.supabaseEnabled) {
      return const AppFailure<AuthSession>(
        'Supabase environment variables are not configured yet.',
      );
    }

    try {
      await _ensureSupabaseReady();
      _ensureAuthSubscription();

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );

      return refreshSession();
    } catch (error) {
      return AppFailure<AuthSession>('Anonymous upgrade failed.', cause: error);
    }
  }

  @override
  Future<AppResult<AppRole>> fetchCurrentRole() async {
    if (!_config.supabaseEnabled) {
      return AppSuccess<AppRole>(_current.role);
    }

    try {
      final claims = await _readClaimsFromDatabase();
      final roleStr = claims['app_role'] ?? 'user';
      return AppSuccess<AppRole>(AppRole.fromName(roleStr));
    } catch (error) {
      return AppFailure<AppRole>('Failed to fetch current role.', cause: error);
    }
  }

  @override
  Future<AppResult<void>> signOut() async {
    try {
      if (_config.supabaseEnabled) {
        await _ensureSupabaseReady();
        await Supabase.instance.client.auth.signOut();
      }

      _emit(AccessContext.anonymous());
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Sign-out failed.', cause: error);
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _controller.close();
    _sessionExpiredController.close();
  }

  Future<void> _ensureSupabaseReady() async {
    if (!_config.supabaseEnabled) {
      return;
    }

    await SupabaseBootstrap.initialize(_config);
  }

  Future<Session?> _resolveValidSupabaseSession({
    bool forceRefresh = false,
  }) async {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    if (session == null) {
      return null;
    }

    final hasRefreshToken =
        session.refreshToken != null && session.refreshToken!.trim().isNotEmpty;
    if (hasRefreshToken &&
        (forceRefresh || session.isExpired || _expiresSoon(session))) {
      session = await _tryRefreshSession(auth, fallback: session);
    }

    if (await _isSessionValid(auth, session)) {
      return session;
    }

    if (hasRefreshToken) {
      session = await _tryRefreshSession(auth, fallback: session);
      if (await _isSessionValid(auth, session)) {
        return session;
      }
    }

    await _signOutSilently(auth);
    return null;
  }

  Future<Session?> _tryRefreshSession(
    GoTrueClient auth, {
    required Session? fallback,
  }) async {
    try {
      final response = await auth.refreshSession();
      return response.session ?? auth.currentSession ?? fallback;
    } catch (_) {
      return auth.currentSession ?? fallback;
    }
  }

  Future<bool> _isSessionValid(GoTrueClient auth, Session? session) async {
    final accessToken = session?.accessToken.trim();
    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    try {
      final response = await auth.getUser(accessToken);
      final user = response.user;
      return user != null && user.id.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _expiresSoon(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return false;
    }

    final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
      isUtc: true,
    );
    return expiresAtDate.isBefore(
      DateTime.now().toUtc().add(const Duration(minutes: 2)),
    );
  }

  Future<void> _signOutSilently(GoTrueClient auth) async {
    try {
      await auth.signOut();
    } catch (_) {
      _emit(AccessContext.anonymous());
    }
  }

  void _ensureAuthSubscription() {
    if (_authSubscription != null ||
        !_config.supabaseEnabled ||
        !SupabaseBootstrap.isInitialized) {
      return;
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      _emitResolvedContext(data.session);
    });
  }

  Future<void> _emitResolvedContext(Session? session) async {
    final context = await _contextFromSupabaseSession(session);
    _emit(context);
  }

  void _emit(AccessContext context) {
    _current = context;
    _controller.add(_current);
  }

  AuthSession _sessionWithDisplayName(AuthSession session, String displayName) {
    final user = session.user;
    if (user == null) {
      return session;
    }

    return AuthSession(
      user: AuthUser(
        id: user.id,
        email: user.email,
        isAnonymous: user.isAnonymous,
        displayName: displayName,
      ),
      claims: Map<String, String>.from(session.claims),
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
    );
  }

  Future<AccessContext> _contextFromSupabaseSession(Session? session) async {
    if (session == null) {
      return _fallbackAccessContext.isAuthenticated
          ? AccessContext.anonymous()
          : _fallbackAccessContext;
    }

    final user = session.user;
    final sessionRole =
        _readClaim(user.appMetadata, 'app_role') ??
        _readClaim(user.userMetadata, 'app_role');
    final sessionPlan =
        _readClaim(user.appMetadata, 'plan') ??
        _readClaim(user.userMetadata, 'plan');
    final databaseClaims = await _readClaimsFromDatabase();
    final role = databaseClaims['app_role'] ?? sessionRole ?? 'user';
    final plan = databaseClaims['plan'] ?? sessionPlan ?? 'free';

    return AccessContext.fromSession(
      AuthSession(
        user: AuthUser(
          id: user.id,
          email: user.email,
          isAnonymous: user.isAnonymous,
          displayName:
              _readClaim(user.userMetadata, 'display_name') ??
              _readClaim(user.userMetadata, 'full_name'),
        ),
        claims: <String, String>{'app_role': role, 'plan': plan},
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        expiresAt: session.expiresAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                session.expiresAt! * 1000,
                isUtc: true,
              ),
      ),
    );
  }

  Future<Map<String, String>> _readClaimsFromDatabase() async {
    if (!_config.supabaseEnabled || !SupabaseBootstrap.isInitialized) {
      return const <String, String>{};
    }

    try {
      final client = Supabase.instance.client;
      final role = _normalizeClaim(
        await client.rpc<String>('current_app_role'),
      );
      final plan = _normalizeClaim(await client.rpc<String>('current_plan'));

      final claims = <String, String>{};
      if (role != null) {
        claims['app_role'] = role;
      }
      if (plan != null) {
        claims['plan'] = plan;
      }

      return claims;
    } catch (_) {
      return const <String, String>{};
    }
  }

  String? _readClaim(Map<String, dynamic>? source, String key) {
    final value = source?[key];
    return _normalizeClaim(value);
  }

  String? _normalizeClaim(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _signInFailureMessage(Object error) {
    if (_isNetworkError(error)) {
      return 'Sunucuya ulasilamadi. Internet baglantini kontrol edip tekrar dene.';
    }
    if (error is AuthApiException || error is AuthException) {
      final message = error.toString().toLowerCase();
      final code = error is AuthException ? error.code?.toLowerCase() : null;
      if (message.contains('email not confirmed') ||
          code == 'email_not_confirmed') {
        return 'E-posta adresin henuz dogrulanmamis. Mail kutundaki linke tiklayip tekrar giris yap.';
      }
      if (message.contains('invalid login credentials') ||
          code == 'invalid_credentials') {
        return 'E-posta veya sifre hatali.';
      }
    }
    return 'Giris yapilamadi. Bilgilerini kontrol edip tekrar dene.';
  }

  String _signUpFailureMessage(Object error) {
    if (_isNetworkError(error)) {
      return 'Kayit islemi icin sunucuya ulasilamadi. Internet baglantini kontrol et.';
    }
    if (error is AuthApiException || error is AuthException) {
      final message = error.toString().toLowerCase();
      final code = error is AuthException ? error.code?.toLowerCase() : null;
      if (message.contains('user already registered') ||
          code == 'user_already_exists') {
        return 'Bu e-posta zaten kayitli. Giris yapmayi dene.';
      }
      if (message.contains('password should be at least')) {
        return 'Sifre en az 8 karakter olmali.';
      }
    }
    return 'Kayit olusturulamadi. Bilgilerini kontrol edip tekrar dene.';
  }

  String _resendConfirmationFailureMessage(Object error) {
    if (_isNetworkError(error)) {
      return 'Dogrulama maili gonderilemedi. Internet baglantini kontrol et.';
    }
    return 'Dogrulama maili yeniden gonderilemedi.';
  }

  bool _isNetworkError(Object error) {
    if (error is AuthRetryableFetchException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('network') ||
        message.contains('connection');
  }
}
