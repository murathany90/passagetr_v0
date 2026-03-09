import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';

import '../core/admin_providers.dart';
import '../features/common/admin_page_parts.dart';
import '../features/content/content_page.dart' deferred as content_page;
import '../features/dashboard/dashboard_page.dart' deferred as dashboard_page;
import '../features/settings/settings_page.dart' deferred as settings_page;
import '../features/users/users_page.dart' deferred as users_page;

final adminConsoleRouterProvider = Provider<GoRouter>((ref) {
  final accessContext = ref.watch(adminAccessProvider);

  return GoRouter(
    redirect: (context, state) {
      final location = state.uri.path;
      final isLoginRoute = location == '/login';

      if (!accessContext.canAccessAdmin && !isLoginRoute) {
        return '/login';
      }

      if (accessContext.canAccessAdmin && isLoginRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => DeferredPageLoader(
          loadLibrary: dashboard_page.loadLibrary,
          builder: (context) => dashboard_page.AdminDashboardPage(),
        ),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => DeferredPageLoader(
          loadLibrary: users_page.loadLibrary,
          builder: (context) => users_page.AdminUsersPage(),
        ),
      ),
      GoRoute(
        path: '/content',
        redirect: (context, state) => '/content/readings',
      ),
      GoRoute(
        path: '/content/readings',
        builder: (context, state) => DeferredPageLoader(
          loadLibrary: content_page.loadLibrary,
          builder: (context) => content_page.AdminContentPage(
            destination: AdminDestination.readings,
          ),
        ),
      ),
      GoRoute(
        path: '/content/words',
        builder: (context, state) => DeferredPageLoader(
          loadLibrary: content_page.loadLibrary,
          builder: (context) => content_page.AdminContentPage(
            destination: AdminDestination.words,
          ),
        ),
      ),
      GoRoute(
        path: '/content/grammar',
        builder: (context, state) => DeferredPageLoader(
          loadLibrary: content_page.loadLibrary,
          builder: (context) => content_page.AdminContentPage(
            destination: AdminDestination.grammar,
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => DeferredPageLoader(
          loadLibrary: settings_page.loadLibrary,
          builder: (context) => settings_page.AdminSettingsPage(),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginPage(),
      ),
    ],
  );
});
