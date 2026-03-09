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
  StreamSubscription<AuthState>? _authSubscription;

  AccessContext _current;

  @override
  Future<AuthSession> restoreSession() async {
    await _ensureSupabaseReady();

    if (!_config.supabaseEnabled) {
      _emit(_fallbackAccessContext);
      return _current.session;
    }

    _ensureAuthSubscription();
    final session = Supabase.instance.client.auth.currentSession;
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

      Session? session = Supabase.instance.client.auth.currentSession;
      if (session?.refreshToken != null) {
        final response = await Supabase.instance.client.auth.refreshSession();
        session =
            response.session ?? Supabase.instance.client.auth.currentSession;
      }

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
      await _emitResolvedContext(
        response.session ?? Supabase.instance.client.auth.currentSession,
      );
      return AppSuccess<AuthSession>(_current.session);
    } catch (error) {
      return AppFailure<AuthSession>('Sign-up failed.', cause: error);
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
      return AppFailure<AuthSession>('Sign-in failed.', cause: error);
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
  }

  Future<void> _ensureSupabaseReady() async {
    if (!_config.supabaseEnabled) {
      return;
    }

    await SupabaseBootstrap.initialize(_config);
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
      unawaited(_emitResolvedContext(data.session));
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
}
