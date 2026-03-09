import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import 'flashcards_page.dart';

class StudentMiniTestPage extends ConsumerStatefulWidget {
  const StudentMiniTestPage({super.key, this.packId});

  final String? packId;

  @override
  ConsumerState<StudentMiniTestPage> createState() =>
      _StudentMiniTestPageState();
}

class _StudentMiniTestPageState extends ConsumerState<StudentMiniTestPage> {
  int _currentIndex = 0;
  int _correctCount = 0;
  int _wrongCount = 0;
  String? _selectedMeaning;
  bool _isAnswered = false;
  bool _attemptRecorded = false;
  late final String _attemptId;

  @override
  void initState() {
    super.initState();
    _attemptId = 'mini-test-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final words = ref.watch(studentWordsProvider);
    final progress = ref.watch(studentWordProgressProvider);

    return StudentDetailFrame(
      destination: StudentDestination.words,
      accessContext: accessContext,
      header: WordsStudyHeader(
        title: 'Mini Test',
        subtitle: widget.packId == null
            ? 'Kısa çoktan seçmeli tur ile kelime bilgisini ölç.'
            : 'Seçili pakette kısa çoktan seçmeli tur ile kelimeleri ölç.',
        onBack: () => context.go(
          widget.packId == null ? '/words' : '/words/packs/${widget.packId}',
        ),
      ),
      body: words.when(
        data: (items) {
          final progressMap =
              progress.valueOrNull ?? const <String, WordProgress>{};
          final scopedItems = widget.packId == null
              ? items
              : items
                    .where((item) => item.packId == widget.packId)
                    .toList(growable: false);
          final questions = _buildQuestions(scopedItems, progressMap);

          if (questions.isEmpty) {
            return StudentSurfaceCard(
              child: Text(
                widget.packId == null
                    ? 'Mini test için yeterli kelime bulunamadı.'
                    : 'Seçili pakette mini test için yeterli kelime bulunamadı.',
              ),
            );
          }

          if (_currentIndex >= questions.length) {
            return _MiniTestSummaryCard(
              totalCount: questions.length,
              correctCount: _correctCount,
              wrongCount: _wrongCount,
              score: ((_correctCount / questions.length) * 100).round(),
              onRestart: () {
                setState(() {
                  _currentIndex = 0;
                  _correctCount = 0;
                  _wrongCount = 0;
                  _selectedMeaning = null;
                  _isAnswered = false;
                  _attemptRecorded = false;
                });
              },
              onBack: () => context.go(
                widget.packId == null ? '/words' : '/words/packs/${widget.packId}',
              ),
            );
          }

          final question = questions[_currentIndex];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WordStudyProgressCard(
                currentIndex: _currentIndex + 1,
                totalCount: questions.length,
                mastery: question.currentMastery,
                seenCount: question.seenCount,
              ),
              const SizedBox(height: 20),
              StudentSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aşağıdaki kelimenin doğru anlamını seç',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      question.word.enWord,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.word.pos,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppThemeTokens.of(context).secondaryText,
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (final option in question.options) ...[
                      _TestOptionTile(
                        label: option,
                        isSelected: _selectedMeaning == option,
                        isCorrect: option == question.word.trMeaning,
                        revealAnswer: _isAnswered,
                        onTap: _isAnswered
                            ? null
                            : () => _selectAnswer(question, option),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _isAnswered
                            ? () => _goNext(questionCount: questions.length)
                            : null,
                        child: Text(
                          _currentIndex == questions.length - 1
                              ? 'Sonucu Gör'
                              : 'Sonraki Soru',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }

  List<_MiniTestQuestion> _buildQuestions(
    List<WordEntry> items,
    Map<String, WordProgress> progressMap,
  ) {
    if (items.length < 4) {
      return const <_MiniTestQuestion>[];
    }

    final orderedWords = [...items]
      ..sort((left, right) {
        final leftMastery = progressMap[left.id]?.mastery ?? 0;
        final rightMastery = progressMap[right.id]?.mastery ?? 0;
        return leftMastery.compareTo(rightMastery);
      });

    final selectedWords = orderedWords
        .take(math.min(5, orderedWords.length))
        .toList();
    return selectedWords
        .map((word) {
          final distractors = orderedWords
              .where((candidate) => candidate.id != word.id)
              .map((candidate) => candidate.trMeaning)
              .take(3)
              .toList(growable: true);
          final options = <String>[word.trMeaning, ...distractors]..sort();
          final snapshot = progressMap[word.id];
          return _MiniTestQuestion(
            word: word,
            options: options,
            currentMastery: snapshot?.mastery ?? 0,
            seenCount: snapshot?.seenCount ?? 0,
          );
        })
        .toList(growable: false);
  }

  Future<void> _selectAnswer(_MiniTestQuestion question, String option) async {
    final isCorrect = option == question.word.trMeaning;
    final controller = ref.read(studentWordProgressProvider.notifier);
    await controller.recordMiniTestAnswer(
      word: question.word,
      isCorrect: isCorrect,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedMeaning = option;
      _isAnswered = true;
      if (isCorrect) {
        _correctCount += 1;
      } else {
        _wrongCount += 1;
      }
    });
  }

  Future<void> _goNext({required int questionCount}) async {
    if (_currentIndex == questionCount - 1 && !_attemptRecorded) {
      _attemptRecorded = true;
      final controller = ref.read(studentWordProgressProvider.notifier);
      await controller.recordTestAttempt(
        sourceType: 'mini_test',
        sourceId: _attemptId,
        score: ((_correctCount / questionCount) * 100).round(),
        correctCount: _correctCount,
        wrongCount: _wrongCount,
        payload: <String, dynamic>{
          'question_count': questionCount,
          'attempt_id': _attemptId,
        },
      );
    }

    setState(() {
      _currentIndex += 1;
      _selectedMeaning = null;
      _isAnswered = false;
    });
  }
}

class _MiniTestQuestion {
  const _MiniTestQuestion({
    required this.word,
    required this.options,
    required this.currentMastery,
    required this.seenCount,
  });

  final WordEntry word;
  final List<String> options;
  final int currentMastery;
  final int seenCount;
}

class _TestOptionTile extends StatelessWidget {
  const _TestOptionTile({
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.revealAnswer,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool revealAnswer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final borderColor = revealAnswer
        ? (isCorrect
              ? tokens.green
              : (isSelected ? tokens.pink : tokens.surfaceBorder))
        : (isSelected ? tokens.accent : tokens.surfaceBorder);
    final backgroundColor = revealAnswer
        ? (isCorrect
              ? tokens.green.withValues(alpha: 0.12)
              : (isSelected
                    ? tokens.pink.withValues(alpha: 0.12)
                    : tokens.surface))
        : (isSelected
              ? tokens.accentSoft.withValues(alpha: 0.16)
              : tokens.surface);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _MiniTestSummaryCard extends StatelessWidget {
  const _MiniTestSummaryCard({
    required this.totalCount,
    required this.correctCount,
    required this.wrongCount,
    required this.score,
    required this.onRestart,
    required this.onBack,
  });

  final int totalCount;
  final int correctCount;
  final int wrongCount;
  final int score;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mini test tamamlandı',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            '$totalCount soruda $correctCount doğru, $wrongCount yanlış yaptın. Skorun %$score.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton(
                onPressed: onRestart,
                child: const Text('Bir Tur Daha'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onBack,
                child: const Text('Kelime Merkezine Dön'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
