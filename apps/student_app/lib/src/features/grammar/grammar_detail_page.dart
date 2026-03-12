import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
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
  bool _completionRecorded = false;
  final Map<int, String> _selectedAnswers = <int, String>{};

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final detailAsync = ref.watch(
      studentGrammarModuleDetailProvider(widget.moduleId),
    );
    final progressMap =
        ref.watch(studentGrammarProgressProvider).valueOrNull ??
        const <int, GrammarProgress>{};

    return detailAsync.when(
      data: (detail) {
        if (detail == null) {
          return _buildStateFrame(
            context: context,
            accessContext: accessContext,
            title: 'Gramer modulu bulunamadi',
            message:
                'Secilen modul veritabaninda bulunamadi. Listeye geri donup farkli bir konu secebilirsin.',
          );
        }

        if (detail.pages.isEmpty) {
          return _buildStateFrame(
            context: context,
            accessContext: accessContext,
            title: 'Bu modul icin sayfa bulunamadi',
            message:
                'Modul listede gorunuyor ancak detay sayfalari henuz yayinlanmamis.',
          );
        }

        final progress = progressMap[detail.module.id];
        final resolvedIndex = _resolvePageIndex(
          pages: detail.pages,
          progress: progress,
        );
        if (_currentPageIndex != resolvedIndex && !_completionRecorded) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentPageIndex = resolvedIndex;
            });
          });
        }

        final safeIndex = _currentPageIndex.clamp(0, detail.pages.length - 1);
        final currentPage = detail.pages[safeIndex];
        final totalPages = detail.pages.length;
        final progressPercent = totalPages == 0
            ? 0
            : (((progress?.completedPages ?? 0) / totalPages) * 100)
                  .round()
                  .clamp(0, 100);
        final isLastPage = safeIndex == totalPages - 1;

        return StudentDetailFrame(
          destination: StudentDestination.grammar,
          accessContext: accessContext,
          browserTitle: detail.module.title,
          header: WordsStudyHeader(
            title: detail.module.title,
            subtitle: '$totalPages sayfa • canli gramer icerigi',
            backLabel: 'Gramer listesine don',
            onBack: () => context.go('/grammar'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WordStudyProgressCard(
                currentIndex: currentPage.pageNumber,
                totalCount: totalPages,
                mastery: progressPercent,
                seenCount: progress?.completedPages ?? 0,
                itemLabel: 'Sayfa',
                footerText:
                    'Bu modulde ${progress?.completedPages ?? 0} sayfa tamamlandi.',
              ),
              const SizedBox(height: 20),
              StudentSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppThemeTokens.of(
                              context,
                            ).accentSoft.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Sayfa ${currentPage.pageNumber}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${currentPage.wordCount} kelime',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      currentPage.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 14),
                    HtmlWidget(
                      currentPage.htmlContent.trim().isEmpty
                          ? '<p>Bu sayfa icin icerik bulunamadi.</p>'
                          : currentPage.htmlContent,
                      textStyle: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (currentPage.examples.isNotEmpty) ...[
                const SizedBox(height: 20),
                StudentSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ornekler',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      for (final example in currentPage.examples) ...[
                        _GrammarExampleTile(example: example),
                        if (example != currentPage.examples.last)
                          const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
              if (currentPage.questions.isNotEmpty) ...[
                const SizedBox(height: 20),
                StudentSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mini test',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      for (final question in currentPage.questions) ...[
                        _GrammarQuestionCard(
                          question: question,
                          selectedAnswer: _selectedAnswers[question.id],
                          onSelected: (value) {
                            setState(() {
                              _selectedAnswers[question.id] = value;
                            });
                          },
                        ),
                        if (question != currentPage.questions.last)
                          const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: safeIndex == 0
                        ? null
                        : () {
                            setState(() {
                              _currentPageIndex = safeIndex - 1;
                            });
                          },
                    child: const Text('Onceki sayfa'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => _advance(
                      moduleId: detail.module.id,
                      pages: detail.pages,
                      currentPage: currentPage,
                      totalPages: totalPages,
                      isLastPage: isLastPage,
                    ),
                    child: Text(
                      isLastPage ? 'Modulu tamamla' : 'Sonraki sayfa',
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
      error: (error, stackTrace) => _buildStateFrame(
        context: context,
        accessContext: accessContext,
        title: 'Gramer sayfasi simdi acilamiyor',
        message:
            'Baglanti tekrar geldiginde ekrani yeniden acmayi dene veya listeye geri don.',
      ),
    );
  }

  StudentDetailFrame _buildStateFrame({
    required BuildContext context,
    required AccessContext accessContext,
    required String title,
    required String message,
  }) {
    return StudentDetailFrame(
      destination: StudentDestination.grammar,
      accessContext: accessContext,
      browserTitle: 'Gramer',
      header: WordsStudyHeader(
        title: 'Gramer',
        subtitle: 'Canli modul verisi kullanilamiyor.',
        backLabel: 'Gramer listesine don',
        onBack: () => context.go('/grammar'),
      ),
      body: _GrammarDetailStateCard(
        title: title,
        message: message,
        actionLabel: 'Gramer listesine don',
        onAction: () => context.go('/grammar'),
      ),
    );
  }

  int _resolvePageIndex({
    required List<GrammarPageDetail> pages,
    required GrammarProgress? progress,
  }) {
    if (pages.isEmpty || progress == null) {
      return _currentPageIndex.clamp(0, pages.isEmpty ? 0 : pages.length - 1);
    }

    if (progress.pageId != null) {
      final pageIdIndex = pages.indexWhere(
        (item) => item.id == progress.pageId,
      );
      if (pageIdIndex >= 0) {
        return pageIdIndex;
      }
    }

    final lastPageNo = progress.lastPageNo.clamp(1, pages.length);
    final pageNoIndex = pages.indexWhere(
      (item) => item.pageNumber == lastPageNo,
    );
    if (pageNoIndex >= 0) {
      return pageNoIndex;
    }

    return 0;
  }

  Future<void> _advance({
    required int moduleId,
    required List<GrammarPageDetail> pages,
    required GrammarPageDetail currentPage,
    required int totalPages,
    required bool isLastPage,
  }) async {
    if (!_canAdvance(currentPage)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mini testi tamamlayip dogru yanitlarla ilerle.'),
        ),
      );
      return;
    }

    final controller = ref.read(studentGrammarProgressProvider.notifier);
    final completedPages = currentPage.pageNumber.clamp(0, totalPages);
    final nextPage = isLastPage ? currentPage : pages[_currentPageIndex + 1];
    final nextPageNumber = isLastPage
        ? currentPage.pageNumber
        : nextPage.pageNumber;
    await controller.recordProgress(
      moduleId: moduleId,
      pageId: nextPage.id,
      lastPageNo: nextPageNumber,
      completedPages: completedPages,
      completed: isLastPage,
    );

    if (!mounted) {
      return;
    }

    if (isLastPage) {
      _completionRecorded = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modul ilerlemesi kaydedildi.')),
      );
      context.go('/grammar');
      return;
    }

    setState(() {
      _currentPageIndex += 1;
    });
  }

  bool _canAdvance(GrammarPageDetail page) {
    if (page.questions.isEmpty) {
      return true;
    }

    for (final question in page.questions) {
      final selectedAnswer = _selectedAnswers[question.id];
      if (selectedAnswer == null || selectedAnswer.isEmpty) {
        return false;
      }
      final correctAnswer = question.correctAnswer;
      if (correctAnswer != null && correctAnswer.isNotEmpty) {
        if (!_answersMatch(selectedAnswer, correctAnswer)) {
          return false;
        }
      }
    }

    return true;
  }

  bool _answersMatch(String selectedAnswer, String correctAnswer) {
    final selectedCanonical = _canonicalAnswer(selectedAnswer);
    final correctCanonical = _canonicalAnswer(correctAnswer);
    if (selectedCanonical == correctCanonical) {
      return true;
    }

    final selectedBody = _answerBody(selectedAnswer);
    final correctBody = _answerBody(correctAnswer);
    if (selectedBody.isNotEmpty && selectedBody == correctBody) {
      return true;
    }

    final selectedLabel = _answerLabel(selectedAnswer);
    final correctLabel = _answerLabel(correctAnswer);
    if (selectedLabel.isNotEmpty &&
        correctLabel.isNotEmpty &&
        selectedLabel == correctLabel) {
      return true;
    }

    return false;
  }

  String _canonicalAnswer(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _answerBody(String value) {
    final normalized = _canonicalAnswer(value);
    return normalized.replaceFirst(RegExp(r'^[a-z0-9]+[\)\.\:\-]\s*'), '');
  }

  String _answerLabel(String value) {
    final normalized = _canonicalAnswer(value);
    final match = RegExp(
      r'^([a-z0-9]+)(?:[\)\.\:\-].*)?$',
    ).firstMatch(normalized);
    return match?.group(1) ?? '';
  }
}

class _GrammarExampleTile extends StatelessWidget {
  const _GrammarExampleTile({required this.example});

  final GrammarExample example;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(example.english, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            example.turkish,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
          ),
          if (example.description != null &&
              example.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              example.description!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _GrammarQuestionCard extends StatelessWidget {
  const _GrammarQuestionCard({
    required this.question,
    required this.selectedAnswer,
    required this.onSelected,
  });

  final GrammarQuestion question;
  final String? selectedAnswer;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.prompt, style: Theme.of(context).textTheme.titleLarge),
        if (question.description != null &&
            question.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            question.description!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        for (final option in question.options) ...[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelected(option),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selectedAnswer == option
                        ? tokens.accent
                        : tokens.surfaceBorder,
                  ),
                  color: selectedAnswer == option
                      ? tokens.accentSoft.withValues(alpha: 0.38)
                      : Colors.transparent,
                ),
                child: Text(option),
              ),
            ),
          ),
          if (option != question.options.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GrammarDetailStateCard extends StatelessWidget {
  const _GrammarDetailStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
