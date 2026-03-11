import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_ui/shared_ui.dart';

import '../core/admin_console_models.dart';
import '../core/admin_providers.dart';
import 'admin_console_router.dart';

class AdminConsoleApp extends ConsumerWidget {
  const AdminConsoleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminConsoleRouterProvider);

    return MaterialApp.router(
      title: 'PASSAGETR Admin Console',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        return _AdminSessionActivityScope(child: child ?? const SizedBox());
      },
    );
  }
}

class _AdminSessionActivityScope extends ConsumerStatefulWidget {
  const _AdminSessionActivityScope({required this.child});

  final Widget child;

  @override
  ConsumerState<_AdminSessionActivityScope> createState() =>
      _AdminSessionActivityScopeState();
}

class _AdminSessionActivityScopeState
    extends ConsumerState<_AdminSessionActivityScope> {
  Timer? _idleTimer;
  int _currentTimeoutMinutes = 30;

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(adminAuthStateProvider);
    final timeoutMinutes = ref
        .watch(adminActiveSettingsProvider)
        .security
        .sessionIdleTimeoutMinutes;
    _syncTimer(authState, timeoutMinutes);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _markInteraction(),
      onPointerMove: (_) => _markInteraction(),
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          _markInteraction();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }

  void _syncTimer(AdminAuthState authState, int timeoutMinutes) {
    if (!authState.isAuthenticated) {
      _idleTimer?.cancel();
      _idleTimer = null;
      return;
    }

    final normalizedTimeout = timeoutMinutes < 5 ? 5 : timeoutMinutes;
    if (_idleTimer == null || normalizedTimeout != _currentTimeoutMinutes) {
      _currentTimeoutMinutes = normalizedTimeout;
      _restartTimer();
    }
  }

  void _markInteraction() {
    if (!ref.read(adminAuthStateProvider).isAuthenticated) {
      return;
    }
    _restartTimer();
  }

  void _restartTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(
      Duration(minutes: _currentTimeoutMinutes),
      () => ref.read(adminAuthStateProvider.notifier).expireSession(),
    );
  }
}
