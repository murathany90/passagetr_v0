import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/translation_service.dart';
import '../../core/utils/network_error_classifier.dart';
import '../../core/utils/word_selection_utils.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/passage_focus_word.dart';
import '../../domain/entities/passage_sentence.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/sentence_translation.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';
import '../flashcard/flashcard_session_page.dart';
import '../tests/mcq_session_page.dart';
import 'widgets/interactive_sentence_text.dart';
import 'widgets/word_quick_view_sheet.dart';
import '../../core/widgets/app_speak_button.dart';

class ReadingDetailPage extends ConsumerStatefulWidget {
  const ReadingDetailPage({
    required this.passage,
    required this.pack,
    this.initialLastIdx = 0,
    super.key,
  });

  final ReadingPassage passage;
  final Pack pack;
  final int initialLastIdx;

  @override
  ConsumerState<ReadingDetailPage> createState() => _ReadingDetailPageState();
}

class _ReadingDetailPageState extends ConsumerState<ReadingDetailPage> {
  static final RegExp _tokenPattern =
      RegExp(r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*|\s+|[^A-Za-z0-9\s]+");

  final Set<String> _expandedSentenceIds = <String>{};
  final Set<String> _loadingTranslationIds = <String>{};
  final Map<String, String> _runtimeTranslations = <String, String>{};
  final Map<String, String> _translationErrors = <String, String>{};
  final Map<String, Set<String>> _highlightedWordsBySentence =
      <String, Set<String>>{};
  bool _focusWordsExpanded = false;

  bool _loading = true;
  bool _savingProgress = false;
  bool _quickWordSheetOpen = false;
  String? _error;
  List<PassageSentence> _sentences = <PassageSentence>[];
  List<PassageFocusWord> _focusWords = <PassageFocusWord>[];
  String _datasetVersion = '';

  int _lastIdx = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _sentences = <PassageSentence>[];
      _focusWords = <PassageFocusWord>[];
      _datasetVersion = '';
      _lastIdx = 0;
      _completed = false;
      _expandedSentenceIds.clear();
      _loadingTranslationIds.clear();
      _runtimeTranslations.clear();
      _translationErrors.clear();
      _highlightedWordsBySentence.clear();
      _focusWordsExpanded = false;
    });

    try {
      final ReadingRepository readingRepository =
          ref.read(readingRepositoryProvider);
      final List<PassageSentence> rows = await readingRepository.getSentences(
        passageId: widget.passage.id,
      );

      final int maxIdx = rows.isEmpty
          ? 0
          : rows
              .map((PassageSentence e) => e.idx)
              .reduce((int a, int b) => a > b ? a : b);

      int nextLastIdx = widget.initialLastIdx;
      bool nextCompleted = false;

      try {
        final progress = await readingRepository.getUserReadingProgress(
          passageId: widget.passage.id,
        );
        if (progress != null) {
          nextLastIdx =
              progress.lastIdx > nextLastIdx ? progress.lastIdx : nextLastIdx;
          nextCompleted = progress.completed;
        }
      } catch (_) {
        // Auth/network hatasi static akisi bloklamaz.
      }

      if (nextLastIdx > maxIdx) {
        nextLastIdx = maxIdx;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _sentences = rows;
        _lastIdx = nextLastIdx;
        _completed = nextCompleted;
      });

      try {
        await readingRepository.upsertUserReadingProgress(
          passageId: widget.passage.id,
          lastIdx: _lastIdx,
          completed: _completed,
        );
      } catch (_) {
        // Best-effort.
      }

      await _prefetchCachedTranslations();
      await _buildDeterministicHighlights();

      ref.invalidate(readingProgressProvider(widget.passage.id));
      ref.invalidate(homeDashboardProvider);
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

  Future<void> _buildDeterministicHighlights() async {
    if (_sentences.isEmpty) {
      return;
    }

    final String datasetVersion = await ref.read(
      appContentDatasetVersionProvider.future,
    );
    final WordRepository wordRepository = ref.read(wordRepositoryProvider);
    final List<WordItem> globalWords = await wordRepository.getGlobalWordIndex(
      limit: 7000,
    );

    final Map<String, List<WordItem>> tokenIndex = <String, List<WordItem>>{};
    for (final WordItem word in globalWords) {
      final String token = normalizeWordToken(word.enWord);
      if (token.isEmpty) {
        continue;
      }
      tokenIndex.putIfAbsent(token, () => <WordItem>[]).add(word);
    }

    final Map<String, Set<String>> highlighted = <String, Set<String>>{};
    final Map<String, PassageFocusWord> focusMap = <String, PassageFocusWord>{};

    for (final PassageSentence sentence in _sentences) {
      final List<String> tokens =
          _extractNormalizedWordTokens(sentence.sentenceEn);
      if (tokens.isEmpty) {
        continue;
      }

      final Set<String> uniqueTokens = tokens.toSet();
      final List<_SentenceCandidate> candidates = <_SentenceCandidate>[];
      final String seed = '${widget.passage.id}|${sentence.id}|$datasetVersion';

      for (final String token in uniqueTokens) {
        final List<WordItem>? choices = tokenIndex[token];
        if (choices == null || choices.isEmpty) {
          continue;
        }

        WordItem bestWord = choices.first;
        int bestScore = _stableHash('$seed|$token|${bestWord.id}');

        for (final WordItem choice in choices.skip(1)) {
          final int score = _stableHash('$seed|$token|${choice.id}');
          if (score < bestScore) {
            bestWord = choice;
            bestScore = score;
          }
        }

        candidates.add(
          _SentenceCandidate(
            token: token,
            word: bestWord,
            score: bestScore,
          ),
        );
      }

      candidates.sort((_SentenceCandidate a, _SentenceCandidate b) {
        final int scoreCompare = a.score.compareTo(b.score);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return a.token.compareTo(b.token);
      });

      final List<_SentenceCandidate> selected = candidates.take(4).toList();
      highlighted[sentence.id] =
          selected.map((candidate) => candidate.token).toSet();

      for (final _SentenceCandidate item in selected) {
        final int occurrenceCount =
            tokens.where((String e) => e == item.token).length;
        final PassageFocusWord? current = focusMap[item.word.id];
        focusMap[item.word.id] = PassageFocusWord(
          wordId: item.word.id,
          enWord: item.word.enWord,
          trMeaning: item.word.trMeaning,
          pos: item.word.pos,
          count: (current?.count ?? 0) + occurrenceCount,
        );
      }
    }

    final List<PassageFocusWord> focusWords = focusMap.values.toList()
      ..sort((PassageFocusWord a, PassageFocusWord b) {
        final int countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) {
          return countCompare;
        }
        return a.enWord.compareTo(b.enWord);
      });

    if (!mounted) {
      return;
    }
    setState(() {
      _datasetVersion = datasetVersion;
      _highlightedWordsBySentence
        ..clear()
        ..addAll(highlighted);
      _focusWords = focusWords;
    });
  }

  List<String> _extractNormalizedWordTokens(String sentence) {
    final List<String> tokens = <String>[];
    for (final Match match in _tokenPattern.allMatches(sentence)) {
      final String raw = match.group(0) ?? '';
      final String normalized = normalizeWordToken(raw);
      if (normalized.isNotEmpty) {
        tokens.add(normalized);
      }
    }
    return tokens;
  }

  int _stableHash(String input) {
    int hash = 0x811C9DC5;
    for (int i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> _prefetchCachedTranslations() async {
    final TranslationService translationService =
        ref.read(translationServiceProvider);
    for (final PassageSentence sentence in _sentences) {
      if ((sentence.sentenceTr ?? '').trim().isNotEmpty) {
        continue;
      }
      try {
        final SentenceTranslation? cached = await ref.read(
          sentenceTranslationControllerProvider(
            SentenceTranslationLookup(
              sentenceId: sentence.id,
              provider: translationService.providerKey,
            ),
          ).future,
        );

        if (cached != null &&
            cached.translatedText.trim().isNotEmpty &&
            mounted) {
          setState(() {
            _runtimeTranslations[sentence.id] = cached.translatedText.trim();
          });
        }
      } catch (_) {
        // Ignore cache read failures for prefetch.
      }
    }
  }

  Future<void> _toggleTranslation(PassageSentence sentence) async {
    final bool isExpanded = _expandedSentenceIds.contains(sentence.id);
    if (isExpanded) {
      setState(() {
        _expandedSentenceIds.remove(sentence.id);
      });
      return;
    }

    setState(() {
      _expandedSentenceIds.add(sentence.id);
    });

    await _markProgress(sentence.idx);

    final String? inlineTr = sentence.sentenceTr?.trim();
    if (inlineTr != null && inlineTr.isNotEmpty) {
      return;
    }

    if ((_runtimeTranslations[sentence.id] ?? '').trim().isNotEmpty) {
      return;
    }

    await _translateAndCache(sentence);
  }

  Future<void> _translateAndCache(PassageSentence sentence) async {
    if (_loadingTranslationIds.contains(sentence.id)) {
      return;
    }

    final String text = sentence.sentenceEn.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _loadingTranslationIds.add(sentence.id);
      _translationErrors.remove(sentence.id);
    });

    final TranslationService translationService =
        ref.read(translationServiceProvider);
    if (!translationService.isConfigured) {
      _handleTranslationError(
        sentenceId: sentence.id,
        message: 'Ceviri yapilandirilmadi.',
      );
      setState(() {
        _loadingTranslationIds.remove(sentence.id);
      });
      return;
    }

    try {
      final ReadingRepository repository = ref.read(readingRepositoryProvider);
      final SentenceTranslation? cached = await repository.getCachedTranslation(
        sentenceId: sentence.id,
        provider: translationService.providerKey,
        targetLang: 'tr',
      );

      if (cached != null && cached.translatedText.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _runtimeTranslations[sentence.id] = cached.translatedText.trim();
          });
        }
        return;
      }

      final String translated = await translationService.translate(
        text: text,
        sourceLang: 'en',
        targetLang: 'tr',
      );

      await repository.saveTranslation(
        sentenceId: sentence.id,
        provider: translationService.providerKey,
        targetLang: 'tr',
        translatedText: translated,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeTranslations[sentence.id] = translated;
      });
    } catch (error) {
      _handleTranslationError(
        sentenceId: sentence.id,
        message: _toTranslationErrorMessage(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingTranslationIds.remove(sentence.id);
        });
      }
    }
  }

  String _toTranslationErrorMessage(Object error) {
    if (error is TranslationException) {
      return NetworkErrorClassifier.toUserSafeMessage(
        error,
        fallback: 'Ceviri su an alinamadi. Daha sonra tekrar dene.',
      );
    }
    if (NetworkErrorClassifier.isNetworkLikeError(error)) {
      return 'Ceviri icin internet baglantisi gerekli.';
    }
    return 'Ceviri alinamadi. Daha sonra tekrar dene.';
  }

  void _handleTranslationError({
    required String sentenceId,
    required String message,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      _translationErrors[sentenceId] = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _markProgress(int idx) async {
    final int maxIdx = _maxIdx;
    final int normalized = idx > maxIdx ? maxIdx : idx;
    if (normalized <= _lastIdx && !_completed) {
      return;
    }
    final int nextLastIdx = normalized > _lastIdx ? normalized : _lastIdx;
    await _persistProgress(
      lastIdx: nextLastIdx,
      completed: _completed,
    );
  }

  Future<void> _advanceProgress() async {
    final int maxIdx = _maxIdx;
    final int nextLastIdx = (_lastIdx + 1) > maxIdx ? maxIdx : (_lastIdx + 1);
    await _persistProgress(lastIdx: nextLastIdx, completed: false);
  }

  Future<void> _completeReading() async {
    await _persistProgress(lastIdx: _maxIdx, completed: true);
  }

  Future<void> _persistProgress({
    required int lastIdx,
    required bool completed,
  }) async {
    setState(() {
      _savingProgress = true;
    });
    try {
      await ref.read(readingRepositoryProvider).upsertUserReadingProgress(
            passageId: widget.passage.id,
            lastIdx: lastIdx,
            completed: completed,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _lastIdx = lastIdx;
        _completed = completed;
      });
      ref.invalidate(readingProgressProvider(widget.passage.id));
      ref.invalidate(homeDashboardProvider);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _savingProgress = false;
        });
      }
    }
  }

  Future<void> _openQuickWordPopup(String normalizedWord) async {
    if (_quickWordSheetOpen) {
      return;
    }
    if (normalizedWord.trim().isEmpty) {
      return;
    }
    _quickWordSheetOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: WordQuickViewSheet(
          hostContext: context,
          pack: widget.pack,
          selectedWord: normalizedWord,
        ),
      ),
    );
    _quickWordSheetOpen = false;
  }

  String? _resolveTranslation(PassageSentence sentence) {
    final String inline = sentence.sentenceTr?.trim() ?? '';
    if (inline.isNotEmpty) {
      return inline;
    }
    final String cached = _runtimeTranslations[sentence.id]?.trim() ?? '';
    if (cached.isNotEmpty) {
      return cached;
    }
    return null;
  }

  int get _maxIdx {
    if (_sentences.isEmpty) {
      return 0;
    }
    return _sentences
        .map((PassageSentence e) => e.idx)
        .reduce((int a, int b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Tooltip(
          message: widget.passage.title,
          child: Text(
            widget.passage.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppShimmerCard(lineCount: 4),
            SizedBox(height: 10),
            AppShimmerCard(),
            SizedBox(height: 10),
            AppShimmerCard(),
          ],
        ),
      );
    }

    if (_error != null) {
      return AppErrorState(
        title: 'Paragraf yuklenemedi.',
        detail: _error!,
        onRetry: _load,
      );
    }

    if (_sentences.isEmpty) {
      return const AppEmptyState(
        title: 'Bu paragrafta cumle yok.',
        message: 'Baska bir paragraf secip tekrar deneyin.',
        icon: Icons.menu_book_outlined,
      );
    }

    final int total = _maxIdx;
    final int shownProgress =
        _completed ? total : (_lastIdx > total ? total : _lastIdx);
    final double progress = total == 0 ? 0 : shownProgress / total;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        itemCount: _sentences.length + 2,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return AppSurfaceCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Ilerleme: $shownProgress/$total',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(width: 8),
                      if (_completed)
                        const Chip(
                          label: Text('Tamamlandi'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _savingProgress || shownProgress >= total
                              ? null
                              : _advanceProgress,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Ilerledim'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _savingProgress || _completed
                              ? null
                              : _completeReading,
                          icon: const Icon(Icons.task_alt_rounded),
                          label: const Text('Okumayi Bitirdim'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          if (index == _sentences.length + 1) {
            return _buildPassageWordsPanel();
          }

          final PassageSentence sentence = _sentences[index - 1];
          final bool expanded = _expandedSentenceIds.contains(sentence.id);
          final bool loadingTranslate =
              _loadingTranslationIds.contains(sentence.id);
          final String? translation = _resolveTranslation(sentence);
          final String? translateError = _translationErrors[sentence.id];
          final Set<String> highlightedWords =
              _highlightedWordsBySentence[sentence.id] ?? const <String>{};

          return AppSurfaceCard(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Chip(
                      label: Text('${sentence.idx}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InteractiveSentenceText(
                        sentenceText: sentence.sentenceEn,
                        highlightedWordsSet: highlightedWords,
                        onWordTap: _openQuickWordPopup,
                        baseStyle: Theme.of(context).textTheme.bodyLarge,
                        highlightStyle:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  decoration: TextDecoration.underline,
                                ),
                      ),
                    ),
                    AppSpeakButton(
                      text: sentence.sentenceEn,
                      iconSize: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _toggleTranslation(sentence),
                  icon: Icon(
                    expanded ? Icons.visibility_off : Icons.translate,
                  ),
                  label: Text(
                    expanded ? 'Ceviriyi Gizle' : 'Ceviriyi Goster',
                  ),
                ),
                if (expanded) ...<Widget>[
                  const SizedBox(height: 6),
                  if (loadingTranslate)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Ceviri yukleniyor...'),
                        ],
                      ),
                    ),
                  if (!loadingTranslate && translation != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'TR:',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(translation),
                        ],
                      ),
                    ),
                  if (!loadingTranslate && translation == null) ...<Widget>[
                    const Text('Ceviri bulunamadi.'),
                    if (translateError != null) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        translateError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _translateAndCache(sentence),
                      child: const Text('Retry Ceviri'),
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassageWordsPanel() {
    final List<String> focusWordIds = _focusWords
        .map((PassageFocusWord e) => e.wordId)
        .toList(growable: false);

    return AppSurfaceCard(
      margin: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 6),
              onExpansionChanged: (bool expanded) {
                setState(() {
                  _focusWordsExpanded = expanded;
                });
              },
              title: Row(
                children: <Widget>[
                  const AppSectionHeader(title: 'Odak Kelimeler'),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_focusWords.length}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              subtitle: _datasetVersion.trim().isEmpty
                  ? null
                  : Text(
                      'Dataset: $_datasetVersion',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
              children: <Widget>[
                if (_focusWords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child:
                          Text('Bu paragrafta secili odak kelime bulunamadi.'),
                    ),
                  )
                else ...<Widget>[
                  ..._focusWords.map(
                    (PassageFocusWord word) {
                      final String pos = word.pos.trim();
                      final String trMeaning = word.trMeaning.trim();
                      final String subtitle = trMeaning.isEmpty
                          ? (pos.isEmpty ? '-' : pos)
                          : (pos.isEmpty ? trMeaning : '$trMeaning • $pos');
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(word.enWord),
                        subtitle: Text(subtitle),
                        trailing: Chip(
                          label: Text('x${word.count}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          if (_focusWordsExpanded && focusWordIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            AppGradientCtaButton(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FlashcardSessionPage(
                      pack: widget.pack,
                      customWordIds: focusWordIds,
                      sessionLabel: 'Passage Focus Words',
                    ),
                  ),
                );
              },
              icon: Icons.school,
              label: 'Kelime Calis',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => McqSessionPage(
                      pack: widget.pack,
                      customWordIds: focusWordIds,
                      sessionLabel: 'Passage Mini MCQ',
                      questionCount: 5,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.quiz),
              label: const Text('Mini MCQ'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SentenceCandidate {
  const _SentenceCandidate({
    required this.token,
    required this.word,
    required this.score,
  });

  final String token;
  final WordItem word;
  final int score;
}
