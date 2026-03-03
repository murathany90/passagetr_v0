import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';

class MatchingSessionPage extends ConsumerStatefulWidget {
  const MatchingSessionPage({required this.pack, super.key});

  final Pack pack;

  @override
  ConsumerState<MatchingSessionPage> createState() =>
      _MatchingSessionPageState();
}

class _MatchingSessionPageState extends ConsumerState<MatchingSessionPage> {
  final Random _random = Random();
  bool _loading = true;
  String? _error;

  List<WordItem> _left = <WordItem>[];
  List<String> _right = <String>[];
  final Map<String, String> _matched = <String, String>{};
  final Set<int> _usedRightIndices = <int>{};
  int? _selectedLeftIndex;
  bool _saving = false;

  int _correctCount = 0;
  int _wrongCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _left = <WordItem>[];
      _right = <String>[];
      _matched.clear();
      _usedRightIndices.clear();
      _selectedLeftIndex = null;
      _correctCount = 0;
      _wrongCount = 0;
    });

    try {
      final WordRepository repo = ref.read(wordRepositoryProvider);
      final List<WordItem> pool = await repo.getSessionBatch(
        widget.pack.id,
        limit: AppConstants.testPoolSize,
      );
      if (pool.length < 2) {
        throw Exception('Matching icin en az 2 kelime gerekli.');
      }

      pool.shuffle(_random);
      final int count = min(AppConstants.testTargetQuestionCount, pool.length);
      final List<WordItem> selected = pool.take(count).toList();
      final List<String> meanings =
          selected.map((WordItem e) => e.trMeaning).toList()..shuffle(_random);

      if (!mounted) {
        return;
      }
      setState(() {
        _left = selected;
        _right = meanings;
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

  Future<void> _onMeaningTap(int rightIndex) async {
    if (_selectedLeftIndex == null || _saving) {
      return;
    }
    final int leftIndex = _selectedLeftIndex!;
    final WordItem selectedWord = _left[leftIndex];

    if (_matched.containsKey(selectedWord.id)) {
      return;
    }
    if (_usedRightIndices.contains(rightIndex)) {
      return;
    }

    final String selectedMeaning = _right[rightIndex];
    final bool isCorrect = selectedMeaning == selectedWord.trMeaning;

    setState(() {
      _saving = true;
    });

    await _saveResultWithRetry(wordId: selectedWord.id, isCorrect: isCorrect);

    if (!mounted) {
      return;
    }

    if (isCorrect) {
      _correctCount++;
      _matched[selectedWord.id] = selectedMeaning;
      _usedRightIndices.add(rightIndex);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dogru eslestirme')),
      );
    } else {
      _wrongCount++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yanlis, tekrar dene')),
      );
    }

    setState(() {
      _selectedLeftIndex = null;
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
        body: AppLoadingBlock(message: 'Matching yukleniyor...'),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matching')),
        body: AppErrorState(
          title: 'Matching verisi yuklenemedi',
          detail: _error!,
          onRetry: _load,
        ),
      );
    }

    final bool completed = _matched.length == _left.length;
    if (completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matching Sonuc')),
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
                    _MetricRow(label: 'Dogru', value: _correctCount),
                    _MetricRow(label: 'Yanlis deneme', value: _wrongCount),
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

    final double progress = _left.isEmpty ? 0 : _matched.length / _left.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Matching ${_matched.length}/${_left.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: <Widget>[
            AppSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tiklamali Eslestirme',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        const _ColumnHeader(
                          title: 'EN',
                          subtitle: 'Kelime sec',
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _left.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (BuildContext context, int index) {
                              final WordItem word = _left[index];
                              final bool isMatched =
                                  _matched.containsKey(word.id);
                              final bool isSelected =
                                  _selectedLeftIndex == index;
                              final Color? tint = isMatched
                                  ? Colors.green.withValues(alpha: 0.16)
                                  : isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.7)
                                      : null;

                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                  ),
                                ),
                                tileColor: tint,
                                title: Text(word.enWord),
                                subtitle: Text(word.pos),
                                onTap: isMatched
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedLeftIndex = index;
                                        });
                                      },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        const _ColumnHeader(
                          title: 'TR',
                          subtitle: 'Anlam sec',
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _right.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (BuildContext context, int index) {
                              final String meaning = _right[index];
                              final bool isUsed =
                                  _usedRightIndices.contains(index);
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                ),
                                tileColor: isUsed
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : null,
                                title: Text(meaning),
                                onTap:
                                    isUsed ? null : () => _onMeaningTap(index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
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
