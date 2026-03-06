import 'dart:async';

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/network_error_classifier.dart';
import '../../core/utils/raw_splitter.dart';
import '../../core/utils/word_selection_utils.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../core/widgets/app_speak_button.dart';
import '../../domain/entities/dictionary_lookup_result.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../domain/value_objects/flashcard_answer.dart';
import '../../state/providers.dart';
import '../tests/test_hub_page.dart';
import '../words/widgets/dictionary_fallback_sheet.dart';
import '../words/word_detail_page.dart';

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
  final AppinioSwiperController _swiperController = AppinioSwiperController();

  bool _loading = true;
  bool _loadingMore = false;
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
    if (_isCustomSession || _loadingMore || !_hasMore) {
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
      });

      if (!_isCustomSession && _words.length - _index < 8 && _hasMore) {
        unawaited(_loadMore());
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openRelatedWord(String rawWord) async {
    final String normalized = normalizeWordToken(rawWord);
    if (normalized.isEmpty) {
      return;
    }

    final WordRepository wordRepository = ref.read(wordRepositoryProvider);
    final WordItem? target =
        await wordRepository.getWordByEnWordGlobal(normalized);
    if (!mounted) {
      return;
    }

    if (target != null) {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => WordDetailPage(word: target),
          ),
        ),
      );
      return;
    }

    final DictionaryRepository dictionaryRepository =
        ref.read(dictionaryRepositoryProvider);
    final DictionaryLookupResult lookup =
        await dictionaryRepository.lookup(query: normalized);
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DictionaryFallbackSheet(
        query: normalized,
        lookup: lookup,
      ),
    );
  }

  void _triggerAnswer(FlashcardAnswer answer) {
    if (_saving) {
      return;
    }
    switch (answer) {
      case FlashcardAnswer.known:
        _swiperController.swipeRight();
      case FlashcardAnswer.unsure:
        _swiperController.swipeUp();
      case FlashcardAnswer.unknown:
        _swiperController.swipeLeft();
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
                  onPressed: _loadInitial,
                  child: const Text('Retry'),
                ),
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
                  onPressed: _loadInitial,
                  child: const Text('Retry'),
                ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('$_title ${_index + 1}/${_words.length}'),
      ),
      bottomNavigationBar: _FlashcardActionBar(
        saving: _saving,
        onUnknown: () => _triggerAnswer(FlashcardAnswer.unknown),
        onUnsure: () => _triggerAnswer(FlashcardAnswer.unsure),
        onKnown: () => _triggerAnswer(FlashcardAnswer.known),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: AppinioSwiper(
          controller: _swiperController,
          cardCount: _words.length,
          initialIndex: _index,
          onSwipeEnd: (
            int previousIndex,
            int? targetIndex,
            SwiperActivity activity,
          ) {
            if (activity is Swipe) {
              if (activity.direction == AxisDirection.right) {
                _submit(FlashcardAnswer.known);
              } else if (activity.direction == AxisDirection.left) {
                _submit(FlashcardAnswer.unknown);
              } else if (activity.direction == AxisDirection.up) {
                _submit(FlashcardAnswer.unsure);
              } else {
                _submit(FlashcardAnswer.unsure);
              }
            }
          },
          cardBuilder: (BuildContext context, int index) {
            if (index >= _words.length) {
              return const Card(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final WordItem currentCardWord = _words[index];
            final List<String> currentSynonyms =
                parseRawList(currentCardWord.synonymsRaw);
            final List<String> currentAntonyms =
                parseRawList(currentCardWord.antonymsRaw);

            return FlipCard(
              direction: FlipDirection.HORIZONTAL,
              front: AppSurfaceCard(
                padding: const EdgeInsets.all(18),
                child: _FrontFace(word: currentCardWord),
              ),
              back: AppSurfaceCard(
                padding: const EdgeInsets.all(18),
                child: _BackFace(
                  word: currentCardWord,
                  synonyms: currentSynonyms,
                  antonyms: currentAntonyms,
                  onRelatedWordTap: _openRelatedWord,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FrontFace extends ConsumerWidget {
  const _FrontFace({required this.word});

  final WordItem word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          word.enWord,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        AppSpeakButton(text: word.enWord),
        const SizedBox(height: 8),
        Chip(label: Text(word.pos)),
        const SizedBox(height: 16),
        Text(
          'Detaylari gormek icin karta dokun',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _BackFace extends StatelessWidget {
  const _BackFace({
    required this.word,
    required this.synonyms,
    required this.antonyms,
    required this.onRelatedWordTap,
  });

  final WordItem word;
  final List<String> synonyms;
  final List<String> antonyms;
  final ValueChanged<String> onRelatedWordTap;

  @override
  Widget build(BuildContext context) {
    final List<String> tags = parseRawList(word.tagsRaw);
    final String level = (word.level ?? '').trim().toUpperCase();
    final bool hasDetailPanel =
        word.exampleEn.trim().isNotEmpty ||
            (word.exampleTr ?? '').trim().isNotEmpty ||
            (word.notes ?? '').trim().isNotEmpty;

    return ListView(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      word.trMeaning,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  AppSpeakButton(text: word.enWord),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text(word.pos),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (level.isNotEmpty)
                    Chip(
                      label: Text(level),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (tags.isNotEmpty)
                    ...tags.take(2).map(
                      (String tag) => Chip(
                        label: Text(tag),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (hasDetailPanel) ...<Widget>[
          const SizedBox(height: 12),
          AppSurfaceCard(
            variant: AppSurfaceVariant.grouped,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (word.exampleEn.trim().isNotEmpty)
                  _BackFaceInfoBlock(
                    title: 'EN Ornek',
                    value: word.exampleEn,
                    trailing: AppSpeakButton(
                      text: word.exampleEn,
                      iconSize: 18,
                    ),
                  ),
                if ((word.exampleTr ?? '').trim().isNotEmpty) ...<Widget>[
                  if (word.exampleEn.trim().isNotEmpty)
                    const SizedBox(height: 12),
                  _BackFaceInfoBlock(
                    title: 'TR Ornek',
                    value: word.exampleTr!,
                  ),
                ],
                if ((word.notes ?? '').trim().isNotEmpty) ...<Widget>[
                  if (word.exampleEn.trim().isNotEmpty ||
                      (word.exampleTr ?? '').trim().isNotEmpty)
                    const SizedBox(height: 12),
                  _BackFaceInfoBlock(
                    title: 'Not',
                    value: word.notes!,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (synonyms.isNotEmpty || antonyms.isNotEmpty || tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          AppSurfaceCard(
            variant: AppSurfaceVariant.grouped,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (synonyms.isNotEmpty)
                  _RelationSection(
                    title: 'Synonyms',
                    values: synonyms,
                    onTap: onRelatedWordTap,
                  ),
                if (antonyms.isNotEmpty) ...<Widget>[
                  if (synonyms.isNotEmpty) const SizedBox(height: 12),
                  _RelationSection(
                    title: 'Antonyms',
                    values: antonyms,
                    onTap: onRelatedWordTap,
                  ),
                ],
                if (tags.isNotEmpty) ...<Widget>[
                  if (synonyms.isNotEmpty || antonyms.isNotEmpty)
                    const SizedBox(height: 12),
                  _RelationSection(
                    title: 'Etiketler',
                    values: tags,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BackFaceInfoBlock extends StatelessWidget {
  const _BackFaceInfoBlock({
    required this.title,
    required this.value,
    this.trailing,
  });

  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 6),
        Text(value),
      ],
    );
  }
}

class _RelationSection extends StatelessWidget {
  const _RelationSection({
    required this.title,
    required this.values,
    this.onTap,
  });

  final String title;
  final List<String> values;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((String value) {
            if (onTap == null) {
              return Chip(
                label: Text(value),
                visualDensity: VisualDensity.compact,
              );
            }
            return ActionChip(
              label: Text(value),
              onPressed: () => onTap!(value),
            );
          }).toList(growable: false),
        ),
      ],
    );
  }
}

class _FlashcardActionBar extends StatelessWidget {
  const _FlashcardActionBar({
    required this.saving,
    required this.onUnknown,
    required this.onUnsure,
    required this.onKnown,
  });

  final bool saving;
  final VoidCallback onUnknown;
  final VoidCallback onUnsure;
  final VoidCallback onKnown;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const ValueKey<String>('flashcard-action-bar'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.72),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Sola: Bilmem | Yukari: Kararsiz | Saga: Bilirim',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ActionButton(
                    label: 'Bilmem',
                    icon: Icons.close_rounded,
                    backgroundColor:
                        Theme.of(context).colorScheme.errorContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onErrorContainer,
                    enabled: !saving,
                    onPressed: onUnknown,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Kararsiz',
                    icon: Icons.help_outline_rounded,
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                    enabled: !saving,
                    onPressed: onUnsure,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Bilirim',
                    icon: Icons.check_rounded,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    enabled: !saving,
                    onPressed: onKnown,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label),
        ),
      ),
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
                  _SummaryMetric(label: 'Bilirim', value: knownCount),
                  _SummaryMetric(label: 'Kararsiz', value: unsureCount),
                  _SummaryMetric(label: 'Bilmem', value: unknownCount),
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
