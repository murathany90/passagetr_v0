import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../core/student_providers.dart';
import '../features/changelog/changelog_page.dart';
import '../features/common/page_parts.dart';
import '../features/grammar/grammar_detail_page.dart';
import '../features/grammar/grammar_page.dart';
import '../features/home/home_page.dart';
import '../features/premium/premium_page.dart' deferred as premium_page;
import '../features/profile/dev_access_page.dart';
import '../features/profile/profile_page.dart';
import '../features/readings/reading_detail_page.dart';
import '../features/readings/readings_page.dart';
import '../features/words/flashcards_page.dart';
import '../features/words/mini_test_page.dart';
import '../features/words/word_pack_detail_page.dart';
import '../features/words/words_page.dart';

final studentRouterProvider = Provider<GoRouter>((ref) {
  final appConfig = ref.read(studentAppConfigProvider);

  return GoRouter(
    errorBuilder: (context, state) =>
        _StudentNotFoundPage(location: state.uri.toString()),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            StudentAppShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const StudentHomePage(),
          ),
          GoRoute(
            path: '/words',
            builder: (context, state) => const StudentWordsPage(),
          ),
          GoRoute(
            path: '/words/packs/:packId',
            builder: (context, state) => StudentWordPackDetailPage(
              packId: state.pathParameters['packId']!,
            ),
          ),
          GoRoute(
            path: '/words/flashcards',
            builder: (context, state) => StudentFlashcardsPage(
              packId: state.uri.queryParameters['packId'],
            ),
          ),
          GoRoute(
            path: '/words/tests',
            builder: (context, state) => StudentMiniTestPage(
              packId: state.uri.queryParameters['packId'],
            ),
          ),
          GoRoute(
            path: '/readings',
            builder: (context, state) => const StudentReadingsPage(),
          ),
          GoRoute(
            path: '/readings/:readingId',
            builder: (context, state) => StudentReadingDetailPage(
              readingId: state.pathParameters['readingId']!,
            ),
          ),
          GoRoute(
            path: '/grammar',
            builder: (context, state) => const StudentGrammarPage(),
          ),
          GoRoute(
            path: '/grammar/:moduleId',
            builder: (context, state) => StudentGrammarDetailPage(
              moduleId:
                  int.tryParse(state.pathParameters['moduleId'] ?? '') ?? 1,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const StudentProfilePage(),
          ),
          GoRoute(
            path: '/changelog',
            builder: (context, state) => const StudentChangelogPage(),
          ),
          GoRoute(
            path: '/dev-access',
            builder: (context, state) => Consumer(
              builder: (context, ref, child) {
                final accessContext = ref.watch(studentAccessProvider);
                return AccessGate(
                  canAccess: accessContext.canAccessAdmin,
                  fallback: const LockedPage(
                    title: 'Dev access',
                    message:
                        'Bu sayfa yalnızca admin veya developer oturumları için açıktır.',
                  ),
                  child: const StudentDevAccessPage(),
                );
              },
            ),
          ),
          GoRoute(
            path: '/premium',
            builder: (context, state) => DeferredPageLoader(
              loadLibrary: premium_page.loadLibrary,
              builder: (context) => premium_page.StudentPremiumPage(),
            ),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => Consumer(
              builder: (context, ref, child) {
                final accessContext = ref.watch(studentAccessProvider);
                return AccessGate(
                  canAccess: accessContext.canAccessAdmin,
                  fallback: const LockedPage(
                    title: 'Admin launcher',
                    message:
                        'Student app içindeki admin görünürlüğü yalnızca launcher seviyesindedir.',
                  ),
                  child: AdminConsoleLauncherPage(
                    adminConsoleUrl: appConfig.adminConsoleUrl,
                    onOpenAdminConsole: () {
                      if (!appConfig.adminConsoleEnabled) {
                        return Future<bool>.value(false);
                      }

                      return launchUrlString(
                        appConfig.adminConsoleUrl,
                        mode: kIsWeb
                            ? LaunchMode.platformDefault
                            : LaunchMode.externalApplication,
                        webOnlyWindowName: '_blank',
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ],
  );
});

class _StudentNotFoundPage extends StatelessWidget {
  const _StudentNotFoundPage({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Title(
      title: 'PASSAGETR | Sayfa Bulunamadı',
      color: tokens.accent,
      child: Scaffold(
        backgroundColor: tokens.appBackground,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 72,
                  color: tokens.secondaryText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sayfa bulunamadı',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Aradığın adres ($location) mevcut değil veya kaldırılmış olabilir.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => GoRouter.of(context).go('/'),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Ana Sayfaya Dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
