import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/network_error_classifier.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';

class McqSessionPage extends ConsumerStatefulWidget {
  const McqSessionPage({
    required this.pack,
    this.customWordIds,
    this.sessionLabel,
    this.questionCount = 5,
    super.key,
  });

  final Pack pack;
  final List<String>? customWordIds;
  final String? sessionLabel;
  final int questionCount;

  @override
  ConsumerState<McqSessionPage> createState() => _McqSessionPageState();
}

class _McqSessionPageState extends ConsumerState<McqSessionPage> {
  final Random _random = Random();

  bool _loading = true;
  String? _error;
  List<_McqQuestion> _questions = <_McqQuestion>[];
  int _index = 0;
  int _correct = 0;
  int _wrong = 0;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _questions = <_McqQuestion>[];
      _index = 0;
      _correct = 0;
      _wrong = 0;
    });

    try {
      final WordRepository wordRepository = ref.read(wordRepositoryProvider);
      final List<String> requestedWordIds = (widget.customWordIds ?? <String>[])
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList(growable: false);

      final List<WordItem> pool = requestedWordIds.isEmpty
          ? await wordRepository.getSessionBatch(
              widget.pack.id,
              limit: AppConstants.testPoolSize,
            )
          : await wordRepository.getWordsByIds(requestedWordIds);

      if (pool.isEmpty) {
        throw Exception('Pack icinde soru uretilecek kelime yok.');
      }

      pool.shuffle(_random);
      final int targetCount = widget.questionCount <= 0 ? 5 : widget.questionCount;
      final int questionCount = min(targetCount, pool.length);
      final List<WordItem> selected = pool.take(questionCount).toList();
      final List<_McqQuestion> built = selected
          .map((WordItem word) =>
              _McqQuestion(word: word, options: _buildOptions(word, pool)))
          .toList();

      if (!mounted) {
        return;
      }
      setState(() {
        _questions = built;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<String> _buildOptions(WordItem target, List<WordItem> pool) {
    final Set<String> optionSet = <String>{target.trMeaning};

    final List<WordItem> samePos = pool
        .where((WordItem w) => w.id != target.id && w.pos == target.pos)
        .toList()
      ..shuffle(_random);
    for (final WordItem item in samePos) {
      if (optionSet.length >= 4) {
        break;
      }
      optionSet.add(item.trMeaning);
    }

    final List<WordItem> fallback = pool
        .where((WordItem w) => w.id != target.id)
        .toList()
      ..shuffle(_random);
    for (final WordItem item in fallback) {
      if (optionSet.length >= 4) {
        break;
      }
      optionSet.add(item.trMeaning);
    }

    final List<String> options = optionSet.toList()..shuffle(_random);
    return options;
  }

  Future<void> _answer(String selected) async {
    if (_locked || _index >= _questions.length) {
      return;
    }
    _locked = true;
    try {
      final _McqQuestion q = _questions[_index];
      final bool isCorrect = selected == q.word.trMeaning;

      if (isCorrect) {
        _correct++;
      } else {
        _wrong++;
      }

      await _recordResultWithRetry(
        wordId: q.word.id,
        isCorrect: isCorrect,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _index++;
      });
    } finally {
      _locked = false;
    }
  }

  Future<void> _recordResultWithRetry({
    required String wordId,
    required bool isCorrect,
  }) async {
    final ProgressRepository progress = ref.read(progressRepositoryProvider);

    while (true) {
      try {
        await progress.applyTestResult(wordId: wordId, isCorrect: isCorrect);
        return;
      } catch (error) {
        if (!mounted) {
          return;
        }
        if (NetworkErrorClassifier.isNetworkLikeError(error) ||
            NetworkErrorClassifier.isAuthTransientError(error)) {
          return;
        }
        final String message = NetworkErrorClassifier.toUserSafeMessage(
          error,
          fallback: 'Ilerleme su an kaydedilemedi.',
        );
        final bool retry = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Progress kaydi basarisiz'),
                  content: Text(message),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Skip'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Retry'),
                    ),
                  ],
                );
              },
            ) ??
            false;

        if (!retry) {
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String rawLabel = (widget.sessionLabel ?? 'MCQ').trim();
    final String label = rawLabel.isEmpty ? 'MCQ' : rawLabel;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(label)),
        body: const AppLoadingBlock(message: 'MCQ yukleniyor...'),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text(label)),
        body: AppErrorState(
          title: 'MCQ yuklenemedi',
          detail: _error!,
          onRetry: _load,
        ),
      );
    }

    if (_index >= _questions.length) {
      return _ResultView(
        title: '$label Sonuc',
        correct: _correct,
        wrong: _wrong,
      );
    }

    final _McqQuestion q = _questions[_index];
    final double progress =
        _questions.isEmpty ? 0 : (_index + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('$label ${_index + 1}/${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Soru ${_index + 1}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Text(
                    q.word.enWord,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Chip(label: Text(q.word.pos)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: q.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int optionIndex) {
                  final String option = q.options[optionIndex];
                  final String prefix =
                      String.fromCharCode('A'.codeUnitAt(0) + optionIndex);
                  return OutlinedButton(
                    onPressed: _locked ? null : () => _answer(option),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            prefix,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(option)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.title,
    required this.correct,
    required this.wrong,
  });

  final String title;
  final int correct;
  final int wrong;

  @override
  Widget build(BuildContext context) {
    final int total = correct + wrong;
    final int score = total == 0 ? 0 : ((correct / total) * 100).round();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppSurfaceCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Skor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '%$score',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _MetricRow(label: 'Dogru', value: '$correct'),
                  _MetricRow(label: 'Yanlis', value: '$wrong'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _McqQuestion {
  const _McqQuestion({
    required this.word,
    required this.options,
  });

  final WordItem word;
  final List<String> options;
}
