import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../core/student_providers.dart';
import '../features/common/page_parts.dart';
import '../features/grammar/grammar_detail_page.dart';
import '../features/grammar/grammar_page.dart';
import '../features/home/home_page.dart';
import '../features/profile/profile_page.dart';
import '../features/readings/reading_detail_page.dart';
import '../features/readings/readings_page.dart';
import '../features/words/flashcards_page.dart';
import '../features/words/mini_test_page.dart';
import '../features/words/word_pack_detail_page.dart';
import '../features/words/words_page.dart';
import '../features/premium/premium_page.dart' deferred as premium_page;

final studentRouterProvider = Provider<GoRouter>((ref) {
  final accessContext = ref.watch(studentAccessProvider);
  final appConfig = ref.watch(studentAppConfigProvider);

  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const StudentHomePage()),
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
          moduleId: int.tryParse(state.pathParameters['moduleId'] ?? '') ?? 1,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const StudentProfilePage(),
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
        builder: (context, state) => AccessGate(
          canAccess: accessContext.canAccessAdmin,
          fallback: const LockedPage(
            title: 'Admin launcher',
            message:
                'Student app icindeki admin gorunurlugu yalnizca launcher seviyesindedir.',
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
        ),
      ),
    ],
  );
});
