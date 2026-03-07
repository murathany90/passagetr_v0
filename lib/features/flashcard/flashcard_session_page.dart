import 'dart:async';

import 'package:appinio_swiper/appinio_swiper.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/layout/app_breakpoints.dart';
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
  final FocusNode _desktopFocusNode = FocusNode(
    debugLabel: 'flashcardDesktopFocus',
  );

  bool _loading = true;
  bool _loadingMore = false;
  bool _saving = false;
  bool _hasMore = true;
  bool _desktopShowBack = false;
  int _offset = 0;
  int _index = 0;
  String? _errorMessage;

  int _knownCount = 0;
  int _unsureCount = 0;
  int _unknownCount = 0;

  bool get _isCustomSession =>
      (widget.customWordIds ?? const <String>[]).isNotEmpty;

  String get _title => widget.sessionLabel ?? 'Flashcard';
  bool get _canAnswerCurrent => _index < _words.length;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _desktopFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _words.clear();
      _offset = 0;
      _hasMore = true;
      _desktopShowBack = false;
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
      final List<WordItem> fetchedWords = await repository.getWordsByIds(ids);
      final List<WordItem> words = _filterRenderableWords(fetchedWords);
      if (!mounted) {
        return;
      }
      setState(() {
        _words.addAll(words);
        _offset = words.length;
        _hasMore = false;
        if (fetchedWords.isNotEmpty && words.isEmpty) {
          _errorMessage = 'Kelime verisi eksik geldigi icin oturum acilamadi.';
        }
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
      final List<WordItem> fetchedBatch = await repository.getSessionBatch(
        widget.pack.id,
        limit: AppConstants.sessionBatchSize,
        offset: _offset,
      );
      final List<WordItem> batch = _filterRenderableWords(fetchedBatch);

      if (!mounted) {
        return;
      }
      setState(() {
        _words.addAll(batch);
        _offset += fetchedBatch.length;
        _hasMore = fetchedBatch.length == AppConstants.sessionBatchSize;
        if (fetchedBatch.isNotEmpty && batch.isEmpty && _words.isEmpty) {
          _errorMessage = 'Kelime verisi eksik geldigi icin oturum acilamadi.';
        }
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
        _desktopShowBack = false;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
    final WordItem? target = await wordRepository.getWordByEnWordGlobal(
      normalized,
    );
    if (!mounted) {
      return;
    }

    if (target != null) {
      unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => WordDetailPage(word: target)),
        ),
      );
      return;
    }

    final DictionaryRepository dictionaryRepository = ref.read(
      dictionaryRepositoryProvider,
    );
    final DictionaryLookupResult lookup = await dictionaryRepository.lookup(
      query: normalized,
    );
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          DictionaryFallbackSheet(query: normalized, lookup: lookup),
    );
  }

  void _triggerAnswer(FlashcardAnswer answer) {
    if (_saving) {
      return;
    }
    if (_isDesktopLayout(context)) {
      unawaited(_submit(answer));
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

  KeyEventResult _handleDesktopKey(KeyEvent event) {
    if (event is! KeyDownEvent || _saving || !_canAnswerCurrent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _triggerAnswer(FlashcardAnswer.unknown);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _triggerAnswer(FlashcardAnswer.unsure);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _triggerAnswer(FlashcardAnswer.known);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<WordItem> _filterRenderableWords(List<WordItem> words) {
    return words
        .where((WordItem word) => _hasDisplayableWordContent(word))
        .toList(growable: false);
  }

  bool _hasDisplayableWordContent(WordItem word) {
    return word.enWord.trim().isNotEmpty ||
        word.trMeaning.trim().isNotEmpty ||
        word.exampleEn.trim().isNotEmpty ||
        (word.exampleTr ?? '').trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktopPage = _isDesktopLayout(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    final Widget actionBar = _FlashcardActionBar(
      saving: _saving,
      maxWidth: isDesktopPage ? 820 : null,
      embedded: isDesktopPage,
      onUnknown: () => _triggerAnswer(FlashcardAnswer.unknown),
      onUnsure: () => _triggerAnswer(FlashcardAnswer.unsure),
      onKnown: () => _triggerAnswer(FlashcardAnswer.known),
    );

    return Scaffold(
      backgroundColor: isDesktopPage ? colorScheme.surfaceContainerLow : null,
      appBar: AppBar(
        backgroundColor: isDesktopPage ? colorScheme.primary : null,
        foregroundColor: isDesktopPage ? colorScheme.onPrimary : null,
        title: Text('$_title ${_index + 1}/${_words.length}'),
      ),
      bottomNavigationBar: isDesktopPage ? null : actionBar,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isDesktop = AppBreakpoints.isDesktopWidth(
            constraints.maxWidth,
          );
          const bool useStaticWebScene = kIsWeb;
          final Widget flashcardScene = useStaticWebScene
              ? _buildStaticCardScene(compact: !isDesktop)
              : isDesktop
                  ? _buildStaticCardScene()
                  : _buildSwiperScene();

          return Focus(
            focusNode: _desktopFocusNode,
            autofocus: isDesktop,
            onKeyEvent: (_, KeyEvent event) =>
                isDesktop ? _handleDesktopKey(event) : KeyEventResult.ignored,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: isDesktop
                  ? (_) => _desktopFocusNode.requestFocus()
                  : null,
              child: isDesktop
                  ? _buildDesktopBody(flashcardScene, actionBar)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: flashcardScene,
                    ),
            ),
          );
        },
      ),
    );
  }

  bool _isDesktopLayout(BuildContext context) {
    return AppBreakpoints.isDesktopWidth(MediaQuery.sizeOf(context).width);
  }

  Widget _buildDesktopBody(Widget cardScene, Widget actionBar) {
    final int remaining = (_words.length - _index).clamp(0, _words.length);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        key: const ValueKey<String>('flashcard-desktop-layout'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AppSurfaceCard(
                        variant: AppSurfaceVariant.feature,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Kart ${_index + 1}/${_words.length}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              'Kalan: $remaining',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      cardScene,
                      const SizedBox(height: 14),
                      actionBar,
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AppSurfaceCard(
                  variant: AppSurfaceVariant.feature,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Oturum Durumu',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      _SessionMetric(label: 'Paket', value: widget.pack.name),
                      _SessionMetric(label: 'Kalan Kart', value: '$remaining'),
                      _SessionMetric(label: 'Bilirim', value: '$_knownCount'),
                      _SessionMetric(label: 'Kararsiz', value: '$_unsureCount'),
                      _SessionMetric(label: 'Bilmem', value: '$_unknownCount'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppSurfaceCard(
                  variant: AppSurfaceVariant.grouped,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Kisayollar',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Kart uzerine tiklayip odagi koruyabilirsin.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Sol ok: Bilmem'),
                      const SizedBox(height: 6),
                      const Text('Yukari ok: Kararsiz'),
                      const SizedBox(height: 6),
                      const Text('Sag ok: Bilirim'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticCardScene({bool compact = false}) {
    final WordItem currentWord = _words[_index];
    final List<String> currentSynonyms = parseRawList(currentWord.synonymsRaw);
    final List<String> currentAntonyms = parseRawList(currentWord.antonymsRaw);
    final double minHeight = compact ? 420 : 560;
    final EdgeInsetsGeometry padding = EdgeInsets.all(compact ? 16 : 18);
    final BorderRadius borderRadius = BorderRadius.circular(compact ? 20 : 24);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.9),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              blurRadius: 24,
              offset: const Offset(0, 14),
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
            ),
          ],
        ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey<String>('flashcard-static-scene'),
              borderRadius: borderRadius,
              onTap: () {
                setState(() {
                _desktopShowBack = !_desktopShowBack;
              });
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: Container(
                key: ValueKey<String>(
                  'flashcard-${currentWord.id}-${_desktopShowBack ? 'back' : 'front'}',
                ),
                constraints: BoxConstraints(minHeight: minHeight),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  child: _desktopShowBack
                      ? Padding(
                          padding: padding,
                          child: _BackFace(
                            word: currentWord,
                            synonyms: currentSynonyms,
                            antonyms: currentAntonyms,
                            onRelatedWordTap: _openRelatedWord,
                          ),
                        )
                      : Padding(
                          padding: padding,
                          child: Center(child: _FrontFace(word: currentWord)),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwiperScene() {
    return AppinioSwiper(
      controller: _swiperController,
      cardCount: _words.length,
      initialIndex: _index,
      onSwipeEnd:
          (int previousIndex, int? targetIndex, SwiperActivity activity) {
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
          return const Card(child: Center(child: CircularProgressIndicator()));
        }
        final WordItem currentCardWord = _words[index];
        final List<String> currentSynonyms = parseRawList(
          currentCardWord.synonymsRaw,
        );
        final List<String> currentAntonyms = parseRawList(
          currentCardWord.antonymsRaw,
        );

        return FlipCard(
          key: ValueKey<String>('flashcard-${currentCardWord.id}'),
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
    );
  }
}

class _FrontFace extends ConsumerWidget {
  const _FrontFace({required this.word});

  final WordItem word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String displayWord = word.enWord.trim().isEmpty
        ? 'Kelime verisi eksik'
        : word.enWord;
    final bool canSpeak = word.enWord.trim().isNotEmpty;
    final bool hasPos = word.pos.trim().isNotEmpty;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          displayWord,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (canSpeak) AppSpeakButton(text: word.enWord),
        const SizedBox(height: 8),
        if (hasPos) Chip(label: Text(word.pos)),
        const SizedBox(height: 16),
        Text(
          canSpeak
              ? 'Detaylari gormek icin karta dokun'
              : 'Bu kelime kaydinda eksik alanlar var.',
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
    final String displayMeaning = word.trMeaning.trim().isEmpty
        ? 'Anlam verisi eksik'
        : word.trMeaning;
    final bool canSpeak = word.enWord.trim().isNotEmpty;
    final bool hasDetailPanel = word.exampleEn.trim().isNotEmpty ||
        (word.exampleTr ?? '').trim().isNotEmpty ||
        (word.notes ?? '').trim().isNotEmpty;

    return SingleChildScrollView(
      key: const ValueKey<String>('flashcard-back-face-list'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        displayMeaning,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (canSpeak) AppSpeakButton(text: word.enWord),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (word.pos.trim().isNotEmpty)
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
                    _BackFaceInfoBlock(title: 'Not', value: word.notes!),
                  ],
                ],
              ),
            ),
          ],
          if (synonyms.isNotEmpty ||
              antonyms.isNotEmpty ||
              tags.isNotEmpty) ...<Widget>[
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
                    _RelationSection(title: 'Etiketler', values: tags),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
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
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
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
    this.maxWidth,
    this.embedded = false,
  });

  final bool saving;
  final VoidCallback onUnknown;
  final VoidCallback onUnsure;
  final VoidCallback onKnown;
  final double? maxWidth;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      key: const ValueKey<String>('flashcard-action-bar'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: embedded
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.72),
              )
            : Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
        borderRadius: embedded ? BorderRadius.circular(20) : null,
      ),
      child: Center(
        child: ConstrainedBox(
          key: const ValueKey<String>('flashcard-action-bar-content'),
          constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Sola: Bilmem | Yukari: Kararsiz | Saga: Bilirim',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.errorContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                      enabled: !saving,
                      onPressed: onUnknown,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Kararsiz',
                      icon: Icons.help_outline_rounded,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondaryContainer,
                      enabled: !saving,
                      onPressed: onUnsure,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Bilirim',
                      icon: Icons.check_rounded,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      enabled: !saving,
                      onPressed: onKnown,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (embedded) {
      return content;
    }

    return SafeArea(top: false, child: content);
  }
}

class _SessionMetric extends StatelessWidget {
  const _SessionMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
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
  const _SummaryMetric({required this.label, required this.value});

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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
