import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
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
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matching')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Matching verisi yuklenemedi'),
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

    final bool completed = _matched.length == _left.length;
    if (completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matching Sonuc')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Dogru: $_correctCount'),
              Text('Yanlis deneme: $_wrongCount'),
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

    return Scaffold(
      appBar:
          AppBar(title: Text('Matching ${_matched.length}/${_left.length}')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: ListView.separated(
                itemCount: _left.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  final WordItem word = _left[index];
                  final bool isMatched = _matched.containsKey(word.id);
                  final bool isSelected = _selectedLeftIndex == index;
                  return ListTile(
                    tileColor: isMatched
                        ? Colors.green.withValues(alpha: 0.18)
                        : isSelected
                            ? Colors.blue.withValues(alpha: 0.18)
                            : null,
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
            const SizedBox(width: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _right.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  final String meaning = _right[index];
                  final bool isUsed = _usedRightIndices.contains(index);
                  return ListTile(
                    tileColor:
                        isUsed ? Colors.green.withValues(alpha: 0.12) : null,
                    title: Text(meaning),
                    onTap: isUsed ? null : () => _onMeaningTap(index),
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
