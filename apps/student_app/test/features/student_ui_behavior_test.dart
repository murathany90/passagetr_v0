import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/core/student_providers.dart';
import 'package:student_app/src/features/common/page_parts.dart';
import 'package:student_app/src/features/readings/reading_detail_page.dart';
import 'package:student_app/src/features/readings/readings_page.dart';
import 'package:student_app/src/features/words/flashcards_page.dart';
import 'package:student_app/src/features/words/mini_test_page.dart';
import 'package:student_app/src/features/words/word_pack_detail_page.dart';
import 'package:student_app/src/features/words/words_page.dart';

void main() {
  testWidgets('admin launcher opens admin console callback', (tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: AdminConsoleLauncherPage(
          adminConsoleUrl: 'http://127.0.0.1:8152/',
          onOpenAdminConsole: () async {
            callCount += 1;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Admin console uygulamasini ac'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(find.text('http://127.0.0.1:8152/'), findsOneWidget);
  });

  testWidgets('tapping a word pack card opens the pack detail page', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/words',
      routes: <RouteBase>[
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
      ],
    );

    await tester.pumpAndSettle();

    expect(find.text('Kelime Paketleri'), findsOneWidget);
    final packTitleFinder = find.text('YDS Ilk 1000');
    await tester.ensureVisible(packTitleFinder);
    await tester.tap(packTitleFinder);
    await tester.pumpAndSettle();

    expect(find.text('Kelime Paketi'), findsOneWidget);
    expect(find.text('Paket Kelimeleri'), findsOneWidget);
    expect(find.text('a great deal of'), findsOneWidget);
    expect(find.text('Flashcard ile Çalış'), findsOneWidget);
  });

  testWidgets('reading detail reveals and hides cached translation', (
    tester,
  ) async {
    await _pumpStudentBehaviorApp(
      tester,
      initialLocation: '/readings/reading-silent-ocean',
      routes: <RouteBase>[
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
      ],
    );

    await tester.pumpAndSettle();

    final showTranslationFinder = find.text('Türkçe Çeviriyi Göster').first;
    expect(showTranslationFinder, findsOneWidget);

    await tester.ensureVisible(showTranslationFinder);
    await tester.tap(showTranslationFinder);
    await tester.pumpAndSettle();

    final translationFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          (widget.data?.contains(
                'Okyanus, Dünya yüzeyinin yüzde yetmişinden fazlasını',
              ) ??
              false),
    );

    expect(find.text('Türkçe Çeviriyi Gizle'), findsAtLeastNWidgets(1));
    expect(translationFinder, findsOneWidget);

    final hideTranslationFinder = find.text('Türkçe Çeviriyi Gizle').first;
    await tester.ensureVisible(hideTranslationFinder);
    await tester.tap(hideTranslationFinder);
    await tester.pumpAndSettle();

    expect(translationFinder, findsNothing);
  });
}

Future<void> _pumpStudentBehaviorApp(
  WidgetTester tester, {
  required String initialLocation,
  required List<RouteBase> routes,
}) async {
  final router = GoRouter(initialLocation: initialLocation, routes: routes);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentPackRepositoryProvider.overrideWithValue(
          const FoundationPackRepository.preview(),
        ),
        studentWordRepositoryProvider.overrideWithValue(
          const FoundationWordRepository.preview(),
        ),
        studentReadingRepositoryProvider.overrideWithValue(
          const FoundationReadingRepository.preview(),
        ),
        studentProgressRepositoryProvider.overrideWithValue(
          const FoundationProgressRepository.preview(),
        ),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
}
