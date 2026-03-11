import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../core/admin_console_models.dart';
import '../core/admin_providers.dart';
import '../features/common/admin_page_parts.dart';
import '../features/content/content_page.dart' deferred as content_page;
import '../features/dashboard/dashboard_page.dart' deferred as dashboard_page;
import '../features/settings/settings_page.dart' deferred as settings_page;
import '../features/users/users_page.dart' deferred as users_page;

final _adminRouterRefreshProvider = Provider<ChangeNotifier>((ref) {
  final notifier = _AdminRouterRefresh();
  ref.listen<AdminAuthState>(adminAuthStateProvider, (previous, next) {
    notifier.ping();
  });
  ref.onDispose(notifier.dispose);
  return notifier;
});

final adminConsoleRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ref.watch(_adminRouterRefreshProvider);

  return GoRouter(
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(adminAuthStateProvider);
      final location = state.uri.path;
      final isLoginRoute = location == '/login';

      if (authState.isBootstrapping || authState.isBusy) {
        return null;
      }

      if (authState.needsLogin && !isLoginRoute) {
        return '/login';
      }

      if (authState.isAuthenticated && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: dashboard_page.loadLibrary,
            builder: (context) => dashboard_page.AdminDashboardPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: users_page.loadLibrary,
            builder: (context) => users_page.AdminUsersPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/content',
        redirect: (context, state) => '/content/readings',
      ),
      GoRoute(
        path: '/content/readings',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: content_page.loadLibrary,
            builder: (context) => content_page.AdminContentPage(
              destination: AdminDestination.readings,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/content/words',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: content_page.loadLibrary,
            builder: (context) => content_page.AdminContentPage(
              destination: AdminDestination.words,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/content/grammar',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: content_page.loadLibrary,
            builder: (context) => content_page.AdminContentPage(
              destination: AdminDestination.grammar,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: settings_page.loadLibrary,
            builder: (context) => settings_page.AdminSettingsPage(),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginPage(),
      ),
    ],
  );
});

class _AdminRouterRefresh extends ChangeNotifier {
  void ping() {
    notifyListeners();
  }
}

class _AdminRouteGate extends ConsumerWidget {
  const _AdminRouteGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(adminAuthStateProvider);
    if (authState.isBootstrapping || authState.isBusy) {
      return const _AdminRouteLoadingScaffold();
    }
    return child;
  }
}

class _AdminRouteLoadingScaffold extends StatelessWidget {
  const _AdminRouteLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
