import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:student_app/src/core/student_providers.dart';
import 'package:student_app/src/features/grammar/grammar_detail_page.dart';
import 'package:student_app/src/features/grammar/grammar_page.dart';

void main() {
  testWidgets(
    'grammar timeline normalizes visible order and alternates cards on wide layouts',
    (tester) async {
      final grammarRepository = _FakeGrammarRepository();
      final progressRepository = _FakeProgressRepository(
        grammarProgress: const <GrammarProgress>[
          GrammarProgress(
            moduleId: 57,
            pageId: 501,
            lastPageNo: 1,
            completedPages: 1,
            completed: false,
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(1280, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentGrammarRepositoryProvider.overrideWithValue(
              grammarRepository,
            ),
            studentProgressRepositoryProvider.overrideWithValue(
              progressRepository,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const StudentGrammarPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Konu 1'), findsOneWidget);
      expect(find.text('Konu 2'), findsOneWidget);
      expect(find.textContaining('57.'), findsNothing);

      final firstCard = find.byKey(
        const ValueKey<String>('grammar_timeline_card_57'),
      );
      final secondCard = find.byKey(
        const ValueKey<String>('grammar_timeline_card_58'),
      );
      final firstOffset = tester.getTopLeft(firstCard);
      final secondOffset = tester.getTopLeft(secondCard);

      expect(firstOffset.dx, lessThan(secondOffset.dx));
    },
  );

  testWidgets(
    'grammar timeline stacks cards on narrow layouts',
    (tester) async {
      final grammarRepository = _FakeGrammarRepository();
      final progressRepository = _FakeProgressRepository();

      await tester.binding.setSurfaceSize(const Size(420, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentGrammarRepositoryProvider.overrideWithValue(
              grammarRepository,
            ),
            studentProgressRepositoryProvider.overrideWithValue(
              progressRepository,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const StudentGrammarPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstCard = find.byKey(
        const ValueKey<String>('grammar_timeline_card_57'),
      );
      final secondCard = find.byKey(
        const ValueKey<String>('grammar_timeline_card_58'),
      );
      final firstOffset = tester.getTopLeft(firstCard);
      final secondOffset = tester.getTopLeft(secondCard);

      expect((firstOffset.dx - secondOffset.dx).abs(), lessThan(8));
    },
  );

  testWidgets(
    'grammar detail uses DB detail and resumes by lastPageNo when pageId is stale',
    (tester) async {
      final grammarRepository = _FakeGrammarRepository();
      final progressRepository = _FakeProgressRepository(
        grammarProgress: const <GrammarProgress>[
          GrammarProgress(
            moduleId: 57,
            pageId: 9999,
            lastPageNo: 2,
            completedPages: 1,
            completed: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentGrammarRepositoryProvider.overrideWithValue(
              grammarRepository,
            ),
            studentProgressRepositoryProvider.overrideWithValue(
              progressRepository,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const StudentGrammarDetailPage(moduleId: 57),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Present Perfect'), findsOneWidget);
      expect(
        find.text('Which sentence is present perfect?'),
        findsOneWidget,
      );
      expect(find.textContaining('Icerik hazirlaniyor'), findsNothing);
    },
  );
}

class _FakeGrammarRepository implements GrammarRepository {
  const _FakeGrammarRepository();

  @override
  Future<List<GrammarModule>> fetchModules() async {
    return const <GrammarModule>[
      GrammarModule(
        id: 57,
        sortOrder: 2,
        title: 'Tense System in English',
        pageCount: 2,
        icon: 'schedule',
        color: '#2563EB',
      ),
      GrammarModule(
        id: 58,
        sortOrder: 3,
        title: 'Modality',
        pageCount: 1,
        icon: 'school',
        color: '#10B981',
      ),
    ];
  }

  @override
  Future<GrammarModuleDetail?> fetchModuleDetail(int moduleId) async {
    if (moduleId != 57) {
      return null;
    }

    return const GrammarModuleDetail(
      module: GrammarModule(
        id: 57,
        sortOrder: 2,
        title: 'Tense System in English',
        pageCount: 2,
        icon: 'schedule',
        color: '#2563EB',
      ),
      pages: <GrammarPageDetail>[
        GrammarPageDetail(
          id: 501,
          pageNumber: 1,
          title: 'Present Simple',
          htmlContent: '<p>Habits and routines.</p>',
          wordCount: 12,
        ),
        GrammarPageDetail(
          id: 502,
          pageNumber: 2,
          title: 'Present Perfect',
          htmlContent: '<p>Actions that connect past and present.</p>',
          wordCount: 15,
          questions: <GrammarQuestion>[
            GrammarQuestion(
              id: 9101,
              sortOrder: 1,
              prompt: 'Which sentence is present perfect?',
              options: <String>[
                'I work daily.',
                'I have finished my homework.',
              ],
              correctAnswer: 'I have finished my homework.',
            ),
          ],
        ),
      ],
    );
  }
}

class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository({
    this.grammarProgress = const <GrammarProgress>[],
  });

  final List<GrammarProgress> grammarProgress;

  @override
  Future<AppResult<void>> enqueue(OutboxEvent event) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<List<GrammarProgress>> fetchGrammarProgress() async => grammarProgress;

  @override
  Future<List<ReadingProgress>> fetchReadingProgress() async =>
      const <ReadingProgress>[];

  @override
  Future<List<WordProgress>> fetchWordProgress() async =>
      const <WordProgress>[];
}
