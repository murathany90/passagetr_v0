import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import 'grammar_seed_data.dart';
import '../words/flashcards_page.dart';

class StudentGrammarDetailPage extends ConsumerStatefulWidget {
  const StudentGrammarDetailPage({super.key, required this.moduleId});

  final int moduleId;

  @override
  ConsumerState<StudentGrammarDetailPage> createState() =>
      _StudentGrammarDetailPageState();
}

class _StudentGrammarDetailPageState
    extends ConsumerState<StudentGrammarDetailPage> {
  int _currentPageIndex = 0;
  String? _selectedAnswer;
  bool _completionRecorded = false;

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final modules = ref.watch(studentGrammarModulesProvider);
    final progressMap =
        ref.watch(studentGrammarProgressProvider).valueOrNull ??
        const <int, GrammarProgress>{};

    return modules.when(
      data: (items) {
        final module = items.firstWhere(
          (item) => item.id == widget.moduleId,
          orElse: () => items.first,
        );
        final seed = grammarSeedFor(module.id);
        final readerSeed = grammarReaderSeedFor(module.id);
        final progress = progressMap[module.id];
        final isLocked =
            seed.state == GrammarModuleState.locked &&
            !accessContext.canViewPremium;
        final resolvedPageIndex = progress == null
            ? _currentPageIndex
            : progress.lastPageNo.clamp(1, readerSeed.pages.length) - 1;

        if (_currentPageIndex != resolvedPageIndex && !_completionRecorded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentPageIndex = resolvedPageIndex;
            });
          });
        }

        if (isLocked) {
          return StudentDetailFrame(
            destination: StudentDestination.grammar,
            accessContext: accessContext,
            header: WordsStudyHeader(
              title: module.title,
              subtitle: 'Bu modül Pro üyelik gerektirir.',
              onBack: () => context.go('/grammar'),
            ),
            body: const LockedPage(
              title: 'Premium gramer modülü',
              message:
                  'Bu reader yalnızca Pro, Admin veya Developer hesapları için açık.',
            ),
          );
        }

        final currentPage = readerSeed.pages[_currentPageIndex];
        final quiz = readerSeed.quiz;
        final isLastPage = _currentPageIndex == readerSeed.pages.length - 1;

        return StudentDetailFrame(
          destination: StudentDestination.grammar,
          accessContext: accessContext,
          header: WordsStudyHeader(
            title: module.title,
            subtitle: readerSeed.summary,
            onBack: () => context.go('/grammar'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WordStudyProgressCard(
                currentIndex: _currentPageIndex + 1,
                totalCount: readerSeed.pages.length,
                mastery: progress == null
                    ? seed.progressPercent
                    : ((progress.completedPages / module.pageCount) * 100)
                          .round(),
                seenCount: progress?.completedPages ?? 0,
              ),
              const SizedBox(height: 20),
              StudentSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPage.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentPage.body,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppThemeTokens.of(
                          context,
                        ).accentSoft.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        currentPage.highlight,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLastPage) ...[
                const SizedBox(height: 20),
                StudentSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mini Quiz',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        quiz.prompt,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 18),
                      for (final option in quiz.options) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            setState(() {
                              _selectedAnswer = option;
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: _selectedAnswer == option
                                    ? AppThemeTokens.of(context).accent
                                    : AppThemeTokens.of(context).surfaceBorder,
                              ),
                            ),
                            child: Text(option),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _currentPageIndex == 0
                        ? null
                        : () {
                            setState(() {
                              _currentPageIndex -= 1;
                            });
                          },
                    child: const Text('Önceki Sayfa'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => _advance(
                      module: module,
                      pageCount: readerSeed.pages.length,
                      requiresQuizAnswer: isLastPage,
                      quiz: quiz,
                    ),
                    child: Text(
                      isLastPage ? 'Modülü Tamamla' : 'Sonraki Sayfa',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
    );
  }

  Future<void> _advance({
    required GrammarModule module,
    required int pageCount,
    required bool requiresQuizAnswer,
    required GrammarQuizQuestionSeed quiz,
  }) async {
    if (requiresQuizAnswer && _selectedAnswer != quiz.correctAnswer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğru cevabı seçip modülü tamamla.')),
      );
      return;
    }

    final controller = ref.read(studentGrammarProgressProvider.notifier);
    final nextPageNo = _currentPageIndex + 1;
    final completed = nextPageNo >= pageCount;
    await controller.recordProgress(
      moduleId: module.id,
      pageId: nextPageNo,
      lastPageNo: nextPageNo,
      completedPages: nextPageNo,
      completed: completed,
    );

    if (!mounted) {
      return;
    }

    if (completed) {
      _completionRecorded = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modül ilerlemesi kaydedildi.')),
      );
      context.go('/grammar');
      return;
    }

    setState(() {
      _currentPageIndex += 1;
    });
  }
}
