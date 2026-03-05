import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/levenshtein.dart';
import '../../core/utils/network_error_classifier.dart';
import '../../core/utils/text_normalizer.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_surface_card.dart';
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
    final TypingResult result = checkTypingAnswer(expected, actual);

    // Both exact and near-match count as correct for progress tracking.
    final bool isCorrect = result != TypingResult.wrong;

    setState(() {
      _saving = true;
    });

    await _saveResultWithRetry(wordId: current.id, isCorrect: isCorrect);

    if (!mounted) {
      return;
    }

    switch (result) {
      case TypingResult.exact:
        _correct++;
      case TypingResult.nearMatch:
        _correct++;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.amber.shade800,
            content: Text('Yakin! Dogru yazilisi: ${current.enWord}'),
          ),
        );
      case TypingResult.wrong:
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
                  title: const Text('Kayit hatasi'),
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
    if (_loading) {
      return const Scaffold(
        body: AppLoadingBlock(message: 'Typing yukleniyor...'),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Typing')),
        body: AppErrorState(
          title: 'Typing verisi yuklenemedi',
          detail: _error!,
          onRetry: _load,
        ),
      );
    }

    if (_index >= _questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Typing Sonuc')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              AppSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Oturum Tamamlandi',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(label: 'Dogru', value: _correct),
                    _MetricRow(label: 'Yanlis', value: _wrong),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
    final double progress =
        _questions.isEmpty ? 0 : (_index + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Typing ${_index + 1}/${_questions.length}'),
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
                    'TR anlam',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    q.trMeaning,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'English kelimeyi yaz',
                prefixIcon: Icon(Icons.keyboard_alt_outlined),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Gonder'),
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
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
