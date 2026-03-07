import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/services/translation_service.dart';
import '../../core/utils/network_error_classifier.dart';
import '../../core/utils/raw_splitter.dart';
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
import 'widgets/reading_detail_side_panel.dart';
import 'widgets/reading_audio_settings_sheet.dart';
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
  static final RegExp _tokenPattern = RegExp(
    r"[A-Za-z0-9]+(?:['-][A-Za-z0-9]+)*|\s+|[^A-Za-z0-9\s]+",
  );

  final Set<String> _loadingTranslationIds = <String>{};
  final Map<String, String> _runtimeTranslations = <String, String>{};
  final Map<String, String> _translationErrors = <String, String>{};
  final Map<String, Set<String>> _highlightedWordsBySentence =
      <String, Set<String>>{};
  final ScrollController _scrollController = ScrollController();
  bool _focusWordsExpanded = false;

  bool _loading = true;
  bool _savingProgress = false;
  bool _quickWordSheetOpen = false;
  bool _isBookmarked = false;
  bool _bookmarkBusy = false;
  bool _isFavorite = false;
  bool _favoriteBusy = false;
  String? _error;
  List<PassageSentence> _sentences = <PassageSentence>[];
  List<PassageFocusWord> _focusWords = <PassageFocusWord>[];

  int _lastIdx = 0;
  bool _completed = false;

  Offset _sentenceTranslationAnchor = const Offset(180, 220);
  String? _activeSentenceTranslationId;
  bool _sentenceTranslationVisible = false;
  ReadingDetailPanelType _desktopPanelType = ReadingDetailPanelType.empty;
  String? _desktopSelectedWord;
  bool _desktopWordLoading = false;
  bool _desktopWordHasDetail = false;
  String _desktopWordMeaning = '';

  OverlayEntry? _inlineBubbleEntry;
  Timer? _inlineBubbleTimer;
  Offset _inlineBubbleAnchor = const Offset(180, 180);
  String _inlineBubbleWord = '';
  String _inlineBubbleText = '';
  bool _inlineBubbleLoading = false;
  bool _inlineBubbleHasDetail = false;
  bool _inlineBubbleVisible = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScrollChanged);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScrollChanged)
      ..dispose();
    _dismissSentenceTranslationPopup(notify: false);
    _dismissInlineBubble();
    super.dispose();
  }

  void _onScrollChanged() {
    if (!_isDesktopLayout(context) && _sentenceTranslationVisible) {
      _dismissSentenceTranslationPopup();
    }
    if (!_isDesktopLayout(context) && _inlineBubbleVisible) {
      _dismissInlineBubble();
    }
  }

  Future<void> _load() async {
    _dismissSentenceTranslationPopup();
    _dismissInlineBubble();
    setState(() {
      _loading = true;
      _error = null;
      _sentences = <PassageSentence>[];
      _focusWords = <PassageFocusWord>[];
      _lastIdx = 0;
      _completed = false;
      _isBookmarked = false;
      _isFavorite = false;
      _loadingTranslationIds.clear();
      _runtimeTranslations.clear();
      _translationErrors.clear();
      _highlightedWordsBySentence.clear();
      _focusWordsExpanded = false;
      _activeSentenceTranslationId = null;
      _desktopPanelType = ReadingDetailPanelType.empty;
      _desktopSelectedWord = null;
      _desktopWordLoading = false;
      _desktopWordHasDetail = false;
      _desktopWordMeaning = '';
    });

    try {
      final ReadingRepository readingRepository = ref.read(
        readingRepositoryProvider,
      );
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
        final bool bookmarked = await readingRepository.isPassageBookmarked(
          widget.passage.id,
        );
        final bool favorited = await readingRepository.isPassageFavorited(
          widget.passage.id,
        );
        if (mounted) {
          setState(() {
            _isBookmarked = bookmarked;
            _isFavorite = favorited;
          });
        }
      } catch (_) {
        // Optional metadata should not block.
      }

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
      try {
        await _buildDeterministicHighlights();
      } catch (error, stackTrace) {
        debugPrint(
          'ReadingDetailPage highlight enrichment failed for '
          '${widget.passage.id}: $error\n$stackTrace',
        );
      }

      ref.invalidate(readingProgressProvider(widget.passage.id));
      ref.invalidate(homeMetricsProvider);
      ref.invalidate(homeQuickStartProvider);
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
      final List<String> tokens = _extractNormalizedWordTokens(
        sentence.sentenceEn,
      );
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
          _SentenceCandidate(token: token, word: bestWord, score: bestScore),
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
    final TranslationService translationService = ref.read(
      translationServiceProvider,
    );
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

  Future<void> _handleSentenceLongPress(
    PassageSentence sentence,
    SentenceTapDetail detail,
  ) async {
    unawaited(ref.read(ttsServiceProvider).stopIfInteractionEnabled());
    _dismissInlineBubble();

    if (_isDesktopLayout(context)) {
      await _markProgress(sentence.idx);
      setState(() {
        _activeSentenceTranslationId = sentence.id;
        _desktopPanelType = ReadingDetailPanelType.translation;
        _desktopSelectedWord = null;
      });

      final String? inlineTr = sentence.sentenceTr?.trim();
      if (inlineTr != null && inlineTr.isNotEmpty) {
        return;
      }
      if ((_runtimeTranslations[sentence.id] ?? '').trim().isNotEmpty) {
        return;
      }
      await _translateAndCache(sentence);
      return;
    }

    if (_sentenceTranslationVisible &&
        _activeSentenceTranslationId == sentence.id) {
      _dismissSentenceTranslationPopup();
      return;
    }

    await _markProgress(sentence.idx);
    _showSentenceTranslationPopup(
      sentenceId: sentence.id,
      anchor: detail.globalPosition,
    );

    final String? inlineTr = sentence.sentenceTr?.trim();
    if (inlineTr != null && inlineTr.isNotEmpty) {
      return;
    }

    if ((_runtimeTranslations[sentence.id] ?? '').trim().isNotEmpty) {
      return;
    }

    await _translateAndCache(sentence);
  }

  Future<void> _openDesktopSentenceTranslationAction(
    PassageSentence sentence,
  ) async {
    await _handleSentenceLongPress(
      sentence,
      const SentenceTapDetail(globalPosition: Offset.zero),
    );
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
    _refreshSentenceTranslationPopup();

    final TranslationService translationService = ref.read(
      translationServiceProvider,
    );
    if (!translationService.isConfigured) {
      _handleTranslationError(
        sentenceId: sentence.id,
        message: 'Ceviri yapilandirilmadi.',
      );
      setState(() {
        _loadingTranslationIds.remove(sentence.id);
      });
      _refreshSentenceTranslationPopup();
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
          _refreshSentenceTranslationPopup();
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
      _refreshSentenceTranslationPopup();
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
        _refreshSentenceTranslationPopup();
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
    _refreshSentenceTranslationPopup();
  }

  Future<void> _markProgress(int idx) async {
    final int maxIdx = _maxIdx;
    final int normalized = idx > maxIdx ? maxIdx : idx;
    if (normalized <= _lastIdx && !_completed) {
      return;
    }
    final int nextLastIdx = normalized > _lastIdx ? normalized : _lastIdx;
    await _persistProgress(lastIdx: nextLastIdx, completed: _completed);
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
      ref.invalidate(homeMetricsProvider);
      ref.invalidate(homeQuickStartProvider);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _savingProgress = false;
        });
      }
    }
  }

  void _showSentenceTranslationPopup({
    required String sentenceId,
    required Offset anchor,
  }) {
    if (!mounted) {
      _activeSentenceTranslationId = sentenceId;
      _sentenceTranslationAnchor = anchor;
      _sentenceTranslationVisible = true;
      return;
    }
    setState(() {
      _activeSentenceTranslationId = sentenceId;
      _sentenceTranslationAnchor = anchor;
      _sentenceTranslationVisible = true;
    });
  }

  void _refreshSentenceTranslationPopup() {
    if (_sentenceTranslationVisible && mounted) {
      setState(() {});
    }
  }

  Widget _buildSentenceTranslationOverlay(BuildContext context) {
    final String? sentenceId = _activeSentenceTranslationId;
    if (sentenceId == null) {
      return const SizedBox.shrink();
    }

    final PassageSentence? sentence = _sentenceById(sentenceId);
    if (sentence == null) {
      return const SizedBox.shrink();
    }

    final String? translation = _resolveTranslation(sentence);
    final String? error = _translationErrors[sentenceId];
    final bool loadingTranslate = _loadingTranslationIds.contains(sentenceId);
    final Size size = MediaQuery.of(context).size;
    final double maxWidth = size.width < 480 ? size.width - 24 : 360;
    final double left = (_sentenceTranslationAnchor.dx - (maxWidth / 2)).clamp(
      12.0,
      size.width - maxWidth - 12,
    );
    final double top = (_sentenceTranslationAnchor.dy + 12).clamp(
      kToolbarHeight + 16.0,
      size.height - 220.0,
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismissSentenceTranslationPopup,
            onVerticalDragStart: (_) {
              _dismissSentenceTranslationPopup();
            },
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: maxWidth,
          child: Material(
            color: Colors.transparent,
            child: AppSurfaceCard(
              key: const ValueKey<String>('sentence-translation-popup'),
              variant: AppSurfaceVariant.feature,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        'Çeviri',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _dismissSentenceTranslationPopup,
                        icon: const Icon(Icons.close_rounded),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Kapat',
                      ),
                    ],
                  ),
                  if (loadingTranslate)
                    const Row(
                      children: <Widget>[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text('Çeviri yükleniyor...')),
                      ],
                    )
                  else if (translation != null)
                    Text(
                      translation,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.42),
                    )
                  else ...<Widget>[
                    const Text('Çeviri bulunamadı.'),
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _translateAndCache(sentence),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar dene'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _dismissSentenceTranslationPopup({bool notify = true}) {
    if (mounted && notify) {
      setState(() {
        _sentenceTranslationVisible = false;
        _activeSentenceTranslationId = null;
      });
    } else {
      _sentenceTranslationVisible = false;
      _activeSentenceTranslationId = null;
    }
  }

  PassageSentence? _sentenceById(String sentenceId) {
    for (final PassageSentence sentence in _sentences) {
      if (sentence.id == sentenceId) {
        return sentence;
      }
    }
    return null;
  }

  Future<void> _onSentenceWordTap(SentenceWordTapDetail tap) async {
    if (tap.word.trim().isEmpty) {
      return;
    }
    unawaited(ref.read(ttsServiceProvider).stopIfInteractionEnabled());

    if (_isDesktopLayout(context)) {
      _dismissSentenceTranslationPopup();
      _dismissInlineBubble();
      await _showDesktopWordMeaning(tap.word);
      return;
    }

    _dismissSentenceTranslationPopup();
    _showInlineBubble(
      word: tap.word,
      anchor: tap.globalPosition,
      loading: true,
      text: 'Anlam yukleniyor...',
      hasDetail: false,
    );

    final _InlineBubbleResult result = await _resolveInlineBubbleMeaning(
      tap.word,
    );

    if (!mounted || !_inlineBubbleVisible || _inlineBubbleWord != tap.word) {
      return;
    }

    _showInlineBubble(
      word: tap.word,
      anchor: tap.globalPosition,
      loading: false,
      text: result.text,
      hasDetail: result.hasDetail,
    );
    _inlineBubbleTimer?.cancel();
    _inlineBubbleTimer = Timer(const Duration(milliseconds: 2500), () {
      _dismissInlineBubble();
    });
  }

  Future<void> _showDesktopWordMeaning(String word) async {
    setState(() {
      _desktopPanelType = ReadingDetailPanelType.dictionary;
      _desktopSelectedWord = word;
      _desktopWordLoading = true;
      _desktopWordHasDetail = false;
      _desktopWordMeaning = 'Anlam yukleniyor...';
      _activeSentenceTranslationId = null;
    });

    final _InlineBubbleResult result = await _resolveInlineBubbleMeaning(word);
    if (!mounted || _desktopSelectedWord != word) {
      return;
    }

    setState(() {
      _desktopWordLoading = false;
      _desktopWordHasDetail = result.hasDetail;
      _desktopWordMeaning = result.text;
    });
  }

  Future<_InlineBubbleResult> _resolveInlineBubbleMeaning(String word) async {
    final WordRepository wordRepository = ref.read(wordRepositoryProvider);

    final WordItem? inPack = await wordRepository.getWordByEnWord(
      packId: widget.pack.id,
      enWord: word,
    );
    final WordItem? found =
        inPack ?? await wordRepository.getWordByEnWordGlobal(word);
    if (found != null && found.trMeaning.trim().isNotEmpty) {
      return _InlineBubbleResult(text: found.trMeaning.trim(), hasDetail: true);
    }

    final TranslationService translationService = ref.read(
      translationServiceProvider,
    );
    if (!translationService.isConfigured) {
      return const _InlineBubbleResult(
        text: 'Ceviri servisi hazir degil.',
        hasDetail: true,
      );
    }

    try {
      final String translated = await translationService.translateEnToTr(word);
      return _InlineBubbleResult(
        text: translated.trim().isEmpty ? 'Ceviri bulunamadi.' : translated,
        hasDetail: true,
      );
    } catch (error) {
      final String safeMessage = NetworkErrorClassifier.toUserSafeMessage(
        error,
        fallback: 'Anlam su an alinamadi.',
      );
      return _InlineBubbleResult(text: safeMessage, hasDetail: true);
    }
  }

  void _showInlineBubble({
    required String word,
    required Offset anchor,
    required bool loading,
    required String text,
    required bool hasDetail,
  }) {
    _inlineBubbleWord = word;
    _inlineBubbleAnchor = anchor;
    _inlineBubbleLoading = loading;
    _inlineBubbleText = text;
    _inlineBubbleHasDetail = hasDetail;
    _inlineBubbleVisible = true;

    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }

    if (_inlineBubbleEntry == null) {
      _inlineBubbleEntry = OverlayEntry(
        builder: (BuildContext bubbleContext) {
          return _buildInlineBubbleOverlay(bubbleContext);
        },
      );
      overlay.insert(_inlineBubbleEntry!);
    } else {
      _inlineBubbleEntry!.markNeedsBuild();
    }
  }

  Widget _buildInlineBubbleOverlay(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double maxWidth = size.width * 0.72;
    final double left = (_inlineBubbleAnchor.dx - (maxWidth / 2)).clamp(
      12.0,
      size.width - maxWidth - 12,
    );
    final double top = (_inlineBubbleAnchor.dy - 94).clamp(
      kToolbarHeight + 16.0,
      size.height - 170.0,
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismissInlineBubble,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: maxWidth,
          child: Material(
            color: Colors.transparent,
            child: AppSurfaceCard(
              key: const ValueKey<String>('word-meaning-popup'),
              variant: AppSurfaceVariant.feature,
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _inlineBubbleWord,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  if (_inlineBubbleLoading)
                    Row(
                      children: <Widget>[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _inlineBubbleText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      _inlineBubbleText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!_inlineBubbleLoading &&
                      _inlineBubbleHasDetail) ...<Widget>[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _openQuickWordPopup(_inlineBubbleWord),
                      child: const Text('Detay'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _dismissInlineBubble() {
    _inlineBubbleTimer?.cancel();
    _inlineBubbleTimer = null;
    _inlineBubbleVisible = false;
    _inlineBubbleEntry?.remove();
    _inlineBubbleEntry = null;
  }

  Future<void> _openReaderSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => const ReadingAudioSettingsSheet(),
    );
  }

  Future<void> _sharePassage() async {
    final String payload = <String>[
      widget.passage.title,
      '',
      ..._sentences.map((PassageSentence e) => '${e.idx}. ${e.sentenceEn}'),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Okuma metni panoya kopyalandi.')),
    );
  }

  Future<void> _toggleBookmark() async {
    if (_bookmarkBusy) {
      return;
    }
    setState(() {
      _bookmarkBusy = true;
    });
    try {
      await ref
          .read(readingRepositoryProvider)
          .toggleBookmark(widget.passage.id);
      final bool bookmarked = await ref
          .read(readingRepositoryProvider)
          .isPassageBookmarked(widget.passage.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _isBookmarked = bookmarked;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yer imi guncellenemedi.')));
    } finally {
      if (mounted) {
        setState(() {
          _bookmarkBusy = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) {
      return;
    }
    setState(() {
      _favoriteBusy = true;
    });
    try {
      await ref
          .read(readingRepositoryProvider)
          .toggleFavorite(widget.passage.id);
      final bool favorited = await ref
          .read(readingRepositoryProvider)
          .isPassageFavorited(widget.passage.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _isFavorite = favorited;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Favori guncellenemedi.')));
    } finally {
      if (mounted) {
        setState(() {
          _favoriteBusy = false;
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
    _dismissInlineBubble();
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

  bool _isDesktopLayout(BuildContext context) {
    return AppBreakpoints.isDesktopWidth(MediaQuery.sizeOf(context).width);
  }

  bool get _useDesktopDoubleTapTranslation => kIsWeb;

  String _buildSentenceHintText() {
    if (_isDesktopLayout(context) && _useDesktopDoubleTapTranslation) {
      return 'Ceviri icin cift tikla, kelime icin tikla.';
    }
    return 'Ceviri icin uzun bas, kelime icin dokun.';
  }

  String _buildHeroHintText() {
    if (_isDesktopLayout(context) && _useDesktopDoubleTapTranslation) {
      return 'Ceviri icin cumleye cift tikla. Kelime anlami icin kelimeye tikla.';
    }
    return 'Ceviri icin cumleye uzun bas. Kelime anlami icin kelimeye dokun.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        title: Text(widget.passage.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Paylas',
            onPressed: _sharePassage,
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: 'Yer imi',
            onPressed: _bookmarkBusy ? null : _toggleBookmark,
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Favori',
            onPressed: _favoriteBusy ? null : _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Dinleme ayarlari',
            onPressed: _openReaderSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = AppBreakpoints.isDesktopWidth(
          constraints.maxWidth,
        );
        if (isDesktop) {
          return _buildDesktopBody(
            shownProgress: shownProgress,
            total: total,
            progress: progress,
          );
        }
        return _buildMobileBody(
          shownProgress: shownProgress,
          total: total,
          progress: progress,
        );
      },
    );
  }

  Widget _buildMobileBody({
    required int shownProgress,
    required int total,
    required double progress,
  }) {
    return Stack(
      children: <Widget>[
        RefreshIndicator(
          onRefresh: _load,
          child: _buildSentenceList(
            includeHeader: true,
            includeFocusWords: true,
            shownProgress: shownProgress,
            total: total,
            progress: progress,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          ),
        ),
        if (_sentenceTranslationVisible)
          _buildSentenceTranslationOverlay(context),
      ],
    );
  }

  Widget _buildDesktopBody({
    required int shownProgress,
    required int total,
    required double progress,
  }) {
    return Row(
      key: const ValueKey<String>('reading-detail-desktop-layout'),
      children: <Widget>[
        SizedBox(
          width: 252,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeroAndProgressCard(
                  shownProgress: shownProgress,
                  total: total,
                  progress: progress,
                ),
                _buildPassageWordsPanel(),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 760,
              child: RefreshIndicator(
                onRefresh: _load,
                child: _buildSentenceList(
                  includeHeader: false,
                  includeFocusWords: false,
                  shownProgress: shownProgress,
                  total: total,
                  progress: progress,
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
                ),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 10, 16),
            child: SingleChildScrollView(child: _buildDesktopDetailPanel()),
          ),
        ),
      ],
    );
  }

  Widget _buildSentenceList({
    required bool includeHeader,
    required bool includeFocusWords,
    required int shownProgress,
    required int total,
    required double progress,
    required EdgeInsets padding,
  }) {
    final int extraHeader = includeHeader ? 1 : 0;
    final int extraFooter = includeFocusWords ? 1 : 0;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: _sentences.length + extraHeader + extraFooter,
      itemBuilder: (BuildContext context, int index) {
        if (includeHeader && index == 0) {
          return _buildHeroAndProgressCard(
            shownProgress: shownProgress,
            total: total,
            progress: progress,
          );
        }

        if (includeFocusWords && index == _sentences.length + extraHeader) {
          return _buildPassageWordsPanel();
        }

        final int sentenceIndex = includeHeader ? index - 1 : index;
        final PassageSentence sentence = _sentences[sentenceIndex];
        final Set<String> highlightedWords =
            _highlightedWordsBySentence[sentence.id] ?? const <String>{};
        final PassageSentence? previous =
            sentenceIndex > 0 ? _sentences[sentenceIndex - 1] : null;

        return Column(
          children: <Widget>[
            if (previous != null && sentence.idx - previous.idx > 1)
              _buildSentenceGapMarker(previous.idx, sentence.idx),
            _buildSentenceCard(
              sentence: sentence,
              highlightedWords: highlightedWords,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSentenceGapMarker(int previousIdx, int currentIdx) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '... ${previousIdx + 1}-${currentIdx - 1}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceCard({
    required PassageSentence sentence,
    required Set<String> highlightedWords,
  }) {
    final bool isActive = _activeSentenceTranslationId == sentence.id;
    final bool isDesktop = _isDesktopLayout(context);

    return AppSurfaceCard(
      variant: isActive ? AppSurfaceVariant.feature : AppSurfaceVariant.subtle,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${sentence.idx}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InteractiveSentenceText(
                  sentenceText: sentence.sentenceEn,
                  highlightedWordsSet: highlightedWords,
                  gestureKey: ValueKey<String>(
                    'sentence-tap-target-${sentence.id}',
                  ),
                  onWordTap: _onSentenceWordTap,
                  onSentenceDoubleTap: _isDesktopLayout(context) &&
                          _useDesktopDoubleTapTranslation
                      ? (SentenceTapDetail detail) {
                          _handleSentenceLongPress(sentence, detail);
                        }
                      : null,
                  onSentenceLongPress: (SentenceTapDetail detail) {
                    _handleSentenceLongPress(sentence, detail);
                  },
                  baseStyle: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.5),
                  highlightStyle:
                      Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                            fontWeight: FontWeight.w800,
                            decoration: TextDecoration.underline,
                          ),
                ),
                const SizedBox(height: 8),
                Text(
                  _buildSentenceHintText(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isDesktop)
                IconButton(
                  key: ValueKey<String>(
                    'sentence-translate-action-${sentence.id}',
                  ),
                  tooltip: 'Çeviri',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.translate_rounded, size: 18),
                  onPressed: () {
                    _openDesktopSentenceTranslationAction(sentence);
                  },
                ),
              AppSpeakButton(text: sentence.sentenceEn, iconSize: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetailPanel() {
    switch (_desktopPanelType) {
      case ReadingDetailPanelType.translation:
        final String? sentenceId = _activeSentenceTranslationId;
        final PassageSentence? sentence =
            sentenceId == null ? null : _sentenceById(sentenceId);
        if (sentence == null) {
          return _buildEmptyDesktopPanel();
        }
        final String? translation = _resolveTranslation(sentence);
        final String? error =
            sentenceId == null ? null : _translationErrors[sentenceId];
        final bool loadingTranslate =
            sentenceId != null && _loadingTranslationIds.contains(sentenceId);

        return ReadingDetailSidePanel(
          type: ReadingDetailPanelType.translation,
          title: 'Secili cumle',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (loadingTranslate)
                const Row(
                  children: <Widget>[
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text('Ceviri yukleniyor...')),
                  ],
                )
              else if (translation != null)
                Text(
                  translation,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.45),
                )
              else ...<Widget>[
                const Text('Ceviri bulunamadi.'),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ],
          ),
          actionLabel:
              (!loadingTranslate && translation == null) ? 'Tekrar dene' : null,
          onAction: (!loadingTranslate && translation == null)
              ? () => _translateAndCache(sentence)
              : null,
        );
      case ReadingDetailPanelType.dictionary:
        final String selectedWord = _desktopSelectedWord ?? '';
        if (selectedWord.trim().isEmpty) {
          return _buildEmptyDesktopPanel();
        }
        return ReadingDetailSidePanel(
          type: ReadingDetailPanelType.dictionary,
          title: selectedWord,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_desktopWordLoading)
                Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_desktopWordMeaning)),
                  ],
                )
              else
                Text(
                  _desktopWordMeaning,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
            ],
          ),
          actionLabel:
              (!_desktopWordLoading && _desktopWordHasDetail) ? 'Detay' : null,
          onAction: (!_desktopWordLoading && _desktopWordHasDetail)
              ? () => _openQuickWordPopup(selectedWord)
              : null,
        );
      case ReadingDetailPanelType.empty:
        return _buildEmptyDesktopPanel();
    }
  }

  Widget _buildEmptyDesktopPanel() {
    return ReadingDetailSidePanel(
      type: ReadingDetailPanelType.empty,
      title: 'Secim bekleniyor',
      body: Text(
        _isDesktopLayout(context) && _useDesktopDoubleTapTranslation
            ? 'Kelimeye tiklayarak sozluk anlamini gorebilir, cumleye cift tiklayarak ceviriyi bu panelde acabilirsin.'
            : 'Kelimeye dokunarak sozluk anlamini gorebilir, cumleye uzun basarak ceviriyi bu panelde acabilirsin.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
      ),
    );
  }

  Widget _buildHeroAndProgressCard({
    required int shownProgress,
    required int total,
    required double progress,
  }) {
    final List<String> tags = parseRawList(widget.passage.tagsRaw);
    return AppSurfaceCard(
      variant: AppSurfaceVariant.feature,
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.passage.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                if ((widget.passage.level ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text(
                        (widget.passage.level ?? '').trim().toUpperCase(),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if ((widget.passage.category ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text(widget.passage.category!.trim()),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ...tags.map(
                  (String tag) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Chip(
                      label: Text(tag),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _buildHeroHintText(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                'Ilerleme: $shownProgress/$total',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
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
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool useCompactStack = constraints.maxWidth < 320;
              final Widget progressButton = _ReadingProgressActionButton(
                tooltip: 'Ilerledim',
                label: useCompactStack ? 'Ilerle' : 'Ilerledim',
                filled: false,
                enabled: !(_savingProgress || shownProgress >= total),
                icon: Icons.arrow_forward_rounded,
                onPressed: _advanceProgress,
              );
              final Widget completeButton = _ReadingProgressActionButton(
                tooltip: 'Okumayi Bitirdim',
                label: useCompactStack ? 'Bitir' : 'Okumayi Bitirdim',
                filled: true,
                enabled: !(_savingProgress || _completed),
                icon: Icons.task_alt_rounded,
                onPressed: _completeReading,
              );

              if (useCompactStack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    progressButton,
                    const SizedBox(height: 8),
                    completeButton,
                  ],
                );
              }

              return Row(
                children: <Widget>[
                  Expanded(child: progressButton),
                  const SizedBox(width: 8),
                  Expanded(child: completeButton),
                ],
              );
            },
          ),
        ],
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
                  const Expanded(
                    child: AppSectionHeader(title: 'Odak Kelimeler'),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('${_focusWords.length}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              children: <Widget>[
                if (_focusWords.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bu paragrafta secili odak kelime bulunamadi.',
                      ),
                    ),
                  )
                else ...<Widget>[
                  ..._focusWords.map((PassageFocusWord word) {
                    final String pos = word.pos.trim();
                    final String trMeaning = word.trMeaning.trim();
                    final String subtitle = trMeaning.isEmpty
                        ? (pos.isEmpty ? '-' : pos)
                        : (pos.isEmpty ? trMeaning : '$trMeaning / $pos');
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(word.enWord),
                      subtitle: Text(subtitle),
                    );
                  }),
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
                      sessionLabel: 'Odak Kelimeler',
                    ),
                  ),
                );
              },
              icon: Icons.school,
              label: 'Kelime Çalış',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => McqSessionPage(
                      pack: widget.pack,
                      customWordIds: focusWordIds,
                      sessionLabel: 'Odak Kelimeler Mini Testi',
                      questionCount: 5,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.quiz),
              label: const Text('Mini Test'),
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

class _InlineBubbleResult {
  const _InlineBubbleResult({required this.text, required this.hasDetail});

  final String text;
  final bool hasDetail;
}

class _ReadingProgressActionButton extends StatelessWidget {
  const _ReadingProgressActionButton({
    required this.tooltip,
    required this.label,
    required this.filled,
    required this.enabled,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final bool filled;
  final bool enabled;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Text labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: TextAlign.center,
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: filled
          ? FilledButton.icon(
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              icon: Icon(icon, size: 18),
              label: labelWidget,
            )
          : OutlinedButton.icon(
              onPressed: enabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              icon: Icon(icon, size: 18),
              label: labelWidget,
            ),
    );
  }
}
