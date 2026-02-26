import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/text_normalizer.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';

class TypingSessionPage extends ConsumerStatefulWidget {
  const TypingSessionPage({required this.pack, super.key});

  final Pack pack;

  @override
  ConsumerState<TypingSessionPage> createState() => _TypingSessionPageState();
}

class _TypingSessionPageState extends ConsumerState<TypingSessionPage> {
  final Random _random = Random();
  final TextEditingController _answerController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<WordItem> _questions = <WordItem>[];
  int _index = 0;
  int _correct = 0;
  int _wrong = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _questions = <WordItem>[];
      _index = 0;
      _correct = 0;
      _wrong = 0;
    });
    try {
      final WordRepository repository = ref.read(wordRepositoryProvider);
      final List<WordItem> pool = await repository.getSessionBatch(
        widget.pack.id,
        limit: AppConstants.testPoolSize,
      );
      if (pool.isEmpty) {
        throw Exception('Typing icin kelime bulunamadi.');
      }

      pool.shuffle(_random);
      final int count = min(AppConstants.testTargetQuestionCount, pool.length);

      if (!mounted) {
        return;
      }
      setState(() {
        _questions = pool.take(count).toList();
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

  Future<void> _submit() async {
    if (_index >= _questions.length || _saving) {
      return;
    }
    final WordItem current = _questions[_index];
    final String expected = normalizeTypingAnswer(current.enWord);
    final String actual = normalizeTypingAnswer(_answerController.text);
    final bool isCorrect = actual == expected;

    setState(() {
      _saving = true;
    });

    await _saveResultWithRetry(wordId: current.id, isCorrect: isCorrect);

    if (!mounted) {
      return;
    }

    if (isCorrect) {
      _correct++;
    } else {
      _wrong++;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dogru cevap: ${current.enWord}')),
      );
    }

    _answerController.clear();
    setState(() {
      _index++;
      _saving = false;
    });
  }

  Future<void> _saveResultWithRetry({
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
                  title: const Text('Kayit hatasi'),
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
        appBar: AppBar(title: const Text('Typing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Typing verisi yuklenemedi'),
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
        appBar: AppBar(title: const Text('Typing Sonuc')),
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

    final WordItem q = _questions[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Typing ${_index + 1}/${_questions.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('TR anlam:', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(q.trMeaning, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _answerController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'English kelimeyi yaz',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: const Text('Gonder'),
            ),
          ],
        ),
      ),
    );
  }
}
