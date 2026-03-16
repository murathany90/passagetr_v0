import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../core/admin_console_models.dart';
import '../core/admin_providers.dart';
import '../features/ai_assistant/ai_assistant_page.dart' deferred as ai_assistant_page;
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
            errorBuilder: (context, error) => const _DeferredErrorState(),
          ),
        ),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: users_page.loadLibrary,
            builder: (context) => users_page.AdminUsersPage(),
            errorBuilder: (context, error) => const _DeferredErrorState(),
          ),
        ),
      ),
      GoRoute(
        path: '/content',
        redirect: (context, state) => '/content/readings',
      ),
      GoRoute(
        path: '/content/ai-assistant',
        builder: (context, state) => _AdminRouteGate(
          child: DeferredPageLoader(
            loadLibrary: ai_assistant_page.loadLibrary,
            builder: (context) => ai_assistant_page.AdminAiAssistantPage(),
            errorBuilder: (context, error) => const _DeferredErrorState(),
          ),
        ),
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
            errorBuilder: (context, error) => const _DeferredErrorState(),
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

/// B5: Deferred page yükleme hataları için fallback widget'l.
class _DeferredErrorState extends StatelessWidget {
  const _DeferredErrorState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Sayfa yüklenemedi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ağ bağlantınızı kontrol edin ve sayfayı yenileyin.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
