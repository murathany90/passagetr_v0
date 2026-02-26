import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';

class McqSessionPage extends ConsumerStatefulWidget {
  const McqSessionPage({required this.pack, super.key});

  final Pack pack;

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
      final List<WordItem> pool = await wordRepository.getSessionBatch(
        widget.pack.id,
        limit: AppConstants.testPoolSize,
      );

      if (pool.isEmpty) {
        throw Exception('Pack icinde soru uretilecek kelime yok.');
      }

      pool.shuffle(_random);
      final int questionCount = min(AppConstants.testTargetQuestionCount, pool.length);
      final List<WordItem> selected = pool.take(questionCount).toList();
      final List<_McqQuestion> built = selected
          .map((WordItem word) => _McqQuestion(word: word, options: _buildOptions(word, pool)))
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

    final List<WordItem> fallback = pool.where((WordItem w) => w.id != target.id).toList()
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
        final bool retry = await showDialog<bool>(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Progress kaydi basarisiz'),
                  content: Text(error.toString()),
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
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('MCQ')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('MCQ yuklenemedi'),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_index >= _questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('MCQ Sonuc')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Dogru: $_correct'),
              Text('Yanlis: $_wrong'),
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

    final _McqQuestion q = _questions[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('MCQ ${_index + 1}/${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(q.word.enWord, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Chip(label: Text(q.word.pos)),
            const SizedBox(height: 16),
            for (final String option in q.options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: _locked ? null : () => _answer(option),
                  child: Text(option),
                ),
              ),
          ],
        ),
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
