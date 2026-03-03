import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../core/utils/raw_splitter.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/value_objects/flashcard_answer.dart';
import '../../state/providers.dart';
import '../tests/test_hub_page.dart';

class FlashcardSessionPage extends ConsumerStatefulWidget {
  const FlashcardSessionPage({
    required this.pack,
    this.customWordIds,
    this.sessionLabel,
    super.key,
  });

  final Pack pack;
  final List<String>? customWordIds;
  final String? sessionLabel;

  @override
  ConsumerState<FlashcardSessionPage> createState() =>
      _FlashcardSessionPageState();
}

class _FlashcardSessionPageState extends ConsumerState<FlashcardSessionPage> {
  final List<WordItem> _words = <WordItem>[];

  bool _loading = true;
  bool _loadingMore = false;
  bool _showBack = false;
  bool _saving = false;
  bool _hasMore = true;
  int _offset = 0;
  int _index = 0;
  String? _errorMessage;

  int _knownCount = 0;
  int _unsureCount = 0;
  int _unknownCount = 0;

  bool get _isCustomSession =>
      (widget.customWordIds ?? const <String>[]).isNotEmpty;

  String get _title => widget.sessionLabel ?? 'Flashcard';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _words.clear();
      _offset = 0;
      _hasMore = true;
      _index = 0;
      _showBack = false;
      _knownCount = 0;
      _unsureCount = 0;
      _unknownCount = 0;
    });

    if (_isCustomSession) {
      await _loadCustomWords();
    } else {
      await _loadMore();
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadCustomWords() async {
    final List<String> ids = widget.customWordIds ?? const <String>[];
    if (ids.isEmpty) {
      setState(() {
        _hasMore = false;
      });
      return;
    }

    try {
      final WordRepository repository = ref.read(wordRepositoryProvider);
      final List<WordItem> words = await repository.getWordsByIds(ids);
      if (!mounted) {
        return;
      }
      setState(() {
        _words.addAll(words);
        _offset = words.length;
        _hasMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isCustomSession) {
      return;
    }
    if (_loadingMore || !_hasMore) {
      return;
    }
    setState(() {
      _loadingMore = true;
    });
    try {
      final WordRepository repository = ref.read(wordRepositoryProvider);
      final List<WordItem> batch = await repository.getSessionBatch(
        widget.pack.id,
        limit: AppConstants.sessionBatchSize,
        offset: _offset,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _words.addAll(batch);
        _offset += batch.length;
        _hasMore = batch.length == AppConstants.sessionBatchSize;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _submit(FlashcardAnswer answer) async {
    if (_saving || _index >= _words.length) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      final ProgressRepository progress = ref.read(progressRepositoryProvider);
      await progress.applyFlashcardResult(
        wordId: _words[_index].id,
        answer: answer,
      );

      if (!mounted) {
        return;
      }

      switch (answer) {
        case FlashcardAnswer.known:
          _knownCount++;
        case FlashcardAnswer.unsure:
          _unsureCount++;
        case FlashcardAnswer.unknown:
          _unknownCount++;
      }

      setState(() {
        _index++;
        _showBack = false;
      });

      if (!_isCustomSession && _words.length - _index < 8 && _hasMore) {
        _loadMore();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Progress kaydi basarisiz: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
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

    if (_errorMessage != null && _words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Flashcard verileri yuklenemedi.'),
                const SizedBox(height: 8),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _loadInitial, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Bu oturum icin gosterilecek kelime bulunamadi.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _loadInitial, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    if (_index >= _words.length) {
      return _SummaryView(
        pack: widget.pack,
        knownCount: _knownCount,
        unsureCount: _unsureCount,
        unknownCount: _unknownCount,
        onRetry: _loadInitial,
      );
    }

    final WordItem word = _words[_index];
    final List<String> synonyms = parseRawList(word.synonymsRaw);
    final List<String> antonyms = parseRawList(word.antonymsRaw);

    return Scaffold(
      appBar: AppBar(
        title: Text('$_title ${_index + 1}/${_words.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showBack = !_showBack;
                  });
                },
                child: AppSurfaceCard(
                  padding: const EdgeInsets.all(18),
                  child: _showBack
                      ? _BackFace(
                          word: word,
                          synonyms: synonyms,
                          antonyms: antonyms,
                        )
                      : _FrontFace(word: word),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppGradientCtaButton(
              enabled: !_saving,
              onTap: _saving ? null : () => _submit(FlashcardAnswer.known),
              icon: Icons.check_circle_outline,
              label: 'Biliyordum',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _saving ? null : () => _submit(FlashcardAnswer.unsure),
              child: const Text('Kararsizim'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed:
                  _saving ? null : () => _submit(FlashcardAnswer.unknown),
              child: const Text('Bilmiyordum'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrontFace extends StatelessWidget {
  const _FrontFace({required this.word});

  final WordItem word;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(word.enWord, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Chip(label: Text(word.pos)),
        const SizedBox(height: 16),
        const Text('Detaylari gormek icin karta dokun'),
      ],
    );
  }
}

class _BackFace extends StatelessWidget {
  const _BackFace({
    required this.word,
    required this.synonyms,
    required this.antonyms,
  });

  final WordItem word;
  final List<String> synonyms;
  final List<String> antonyms;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        Text(word.trMeaning, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('EN: ${word.exampleEn}'),
        if ((word.exampleTr ?? '').trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text('TR: ${word.exampleTr}'),
        ],
        if (synonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text('Synonyms'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: synonyms
                .map((String e) => Chip(label: Text(e)))
                .toList(growable: false),
          ),
        ],
        if (antonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          const Text('Antonyms'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: antonyms
                .map((String e) => Chip(label: Text(e)))
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView({
    required this.pack,
    required this.knownCount,
    required this.unsureCount,
    required this.unknownCount,
    required this.onRetry,
  });

  final Pack pack;
  final int knownCount;
  final int unsureCount;
  final int unknownCount;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flashcard Ozeti')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppSurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Oturum bitti',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 14),
                  _SummaryMetric(label: 'Known', value: knownCount),
                  _SummaryMetric(label: 'Unsure', value: unsureCount),
                  _SummaryMetric(label: 'Unknown', value: unknownCount),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppGradientCtaButton(
              onTap: onRetry,
              icon: Icons.refresh,
              label: 'Tekrar Calis',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TestHubPage(pack: pack),
                  ),
                );
              },
              child: const Text('Teste Gec'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
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
