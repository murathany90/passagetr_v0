import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/interaction_guard.dart';
import '../../core/student_providers.dart';
import '../../core/tts/student_tts_controller.dart';
import '../../core/tts/student_tts_engine.dart';
import '../../core/tts/student_tts_icon_button.dart';
import '../common/page_parts.dart';
import '../words/student_word_card_sheet.dart';
import 'reading_artwork.dart';
import 'reading_seed_data.dart';

class StudentReadingDetailPage extends ConsumerStatefulWidget {
  const StudentReadingDetailPage({super.key, required this.readingId});

  final String readingId;

  @override
  ConsumerState<StudentReadingDetailPage> createState() =>
      _StudentReadingDetailPageState();
}

class _StudentReadingDetailPageState
    extends ConsumerState<StudentReadingDetailPage> {
  bool _focusModeEnabled = false;
  bool _isRefreshingContent = false;
  bool _hasTriggeredInitialRefresh = false;
  final Set<int> _revealedTranslations = <int>{};
  final Set<int> _loadingTranslations = <int>{};
  final Map<int, _SelectedDictionaryWord> _selectedWords =
      <int, _SelectedDictionaryWord>{};
  final Map<String, int> _selectedQuestionOptionIndexes = <String, int>{};
  _ReadingQuizResult? _readingQuizResult;
  bool _isSubmittingReadingQuiz = false;
  late final StudentTtsController _ttsController;

  @override
  void initState() {
    super.initState();
    _ttsController = ref.read(studentTtsControllerProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasTriggeredInitialRefresh) {
        return;
      }
      _hasTriggeredInitialRefresh = true;
      _refreshContent(showFeedback: false);
    });
  }

  @override
  void dispose() {
    unawaited(_ttsController.stop());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StudentReadingDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readingId == widget.readingId) {
      return;
    }

    unawaited(_ttsController.stop());
    _revealedTranslations.clear();
    _loadingTranslations.clear();
    _selectedWords.clear();
    _selectedQuestionOptionIndexes.clear();
    _readingQuizResult = null;
    _isSubmittingReadingQuiz = false;
    _hasTriggeredInitialRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _refreshContent(showFeedback: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final readings = ref.watch(studentReadingsProvider);
    ref.watch(studentTranslationProvider);

    return readings.when(
      data: (items) {
        final reading = _resolveReading(items, widget.readingId);
        if (reading == null) {
          return StudentDetailFrame(
            destination: StudentDestination.readings,
            accessContext: accessContext,
            header: ReadingDetailHeader(
              isBookmarked: false,
              isFavorite: false,
              canToggleEngagement: false,
              engagementHelperText: null,
              onBack: () => _goBack(context),
              onBookmarkToggle: () {},
              onFavoriteToggle: () {},
              onShare: () {},
            ),
            body: const StudentSurfaceCard(child: Text('Okuma bulunamadi.')),
          );
        }

        final isLocked = reading.isPro && !accessContext.canViewPremium;
        if (isLocked) {
          return StudentDetailFrame(
            destination: StudentDestination.readings,
            accessContext: accessContext,
            header: ReadingDetailHeader(
              isBookmarked: false,
              isFavorite: false,
              canToggleEngagement: false,
              engagementHelperText: null,
              onBack: () => _goBack(context),
              onBookmarkToggle: () {},
              onFavoriteToggle: () {},
              onShare: () {},
            ),
            body: _ReadingStateCard(
              title: 'Bu okuma Pro uyelik gerektirir',
              message:
                  'Kayit listede gorunur, ancak tam icerik ve detay ekranina erismek icin Pro gerekir.',
              actionLabel: 'Proyu Gor',
              onAction: () => context.go('/premium'),
            ),
          );
        }

        final seed = readingSeedForPassage(reading);
        final adjacentReadings = _resolveAdjacentReadings(items, reading.id);
        final articleSections = _resolveArticleSections(
          seed,
          ref.watch(studentReadingSectionsProvider(reading.id)).valueOrNull,
        );
        final focusWords = ref.watch(
          studentReadingFocusWordsProvider(reading.id),
        );
        final readingQuestions = ref.watch(
          studentReadingQuestionsProvider(reading.id),
        );
        final focusWordCards = ref.watch(
          studentReadingWordCardsProvider(reading.id),
        );
        final linkedWordCards = _resolveLinkedWordCards(
          focusWords.valueOrNull ?? const <ReadingFocusWord>[],
          focusWordCards.valueOrNull ?? const <String, WordEntry>{},
        );
        final ttsState = ref.watch(studentTtsControllerProvider);
        final engagement = ref.watch(
          studentReadingEngagementByIdProvider(reading.id),
        );
        final canPersistEngagement = InteractionGuard.canPersist(accessContext);

        return StudentDetailFrame(
          destination: StudentDestination.readings,
          accessContext: accessContext,
          header: ReadingDetailHeader(
            isBookmarked: engagement.isBookmarked,
            isFavorite: engagement.isFavorite,
            canToggleEngagement: canPersistEngagement,
            engagementHelperText: canPersistEngagement
                ? null
                : 'Kaydetmek icin giris yap',
            onBack: () => _goBack(context),
            onBookmarkToggle: () => _toggleBookmark(reading.id),
            onFavoriteToggle: () => _toggleFavorite(reading.id),
            onShare: () =>
                _showSnackBar('Paylasim sonraki fazda etkinlesecek.'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
              final infoPanel = _ReadingInfoPanel(
                readingId: reading.id,
                reading: reading,
                seed: seed,
                summary: _resolveVisibleSummary(reading, seed),
                focusModeEnabled: _focusModeEnabled,
                articleSections: articleSections,
                ttsState: ttsState,
                onToggleFocusMode: () {
                  setState(() {
                    _focusModeEnabled = !_focusModeEnabled;
                  });
                },
                onPlayPassage: () => _playPassage(reading.id, articleSections),
                onStopPassage: _stopActiveTts,
              );
              final articlePanel = _ReadingArticlePanel(
                readingId: reading.id,
                title: reading.title,
                sections: articleSections,
                previousReading: adjacentReadings.previous,
                nextReading: adjacentReadings.next,
                canAccessPremium: accessContext.canViewPremium,
                focusModeEnabled: _focusModeEnabled,
                linkedWordCards: linkedWordCards,
                revealedTranslations: _revealedTranslations,
                loadingTranslations: _loadingTranslations,
                selectedWords: _selectedWords,
                questions: readingQuestions,
                selectedQuestionOptionIndexes: _selectedQuestionOptionIndexes,
                readingQuizResult: _readingQuizResult,
                isSubmittingReadingQuiz: _isSubmittingReadingQuiz,
                persistsAttempts: InteractionGuard.canPersist(accessContext),
                translationForSection: (lookupIndex) => ref
                    .read(studentTranslationProvider.notifier)
                    .cachedTranslation(reading.id, lookupIndex),
                onNavigateToReading: (targetReading) =>
                    _navigateToReading(targetReading, accessContext),
                onPlaySentence: _playSentence,
                onStopSentence: _stopSentence,
                onWordTap: _handleWordTap,
                onWordLongPress: (section) =>
                    _toggleTranslation(readingId: reading.id, section: section),
                onQuestionSelected: _selectReadingQuestionOption,
                onSubmitQuiz: (questions) =>
                    _submitReadingQuiz(reading.id, questions),
                onClearQuiz: _clearReadingQuiz,
              );
              final focusWordsPanel = _FocusWordsPanel(
                focusWords: focusWords,
                linkedWordCards: linkedWordCards,
                onWordTap: _showWordCardSheet,
              );

              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoPanel,
                    const SizedBox(height: 16),
                    articlePanel,
                    const SizedBox(height: 16),
                    focusWordsPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 260, child: infoPanel),
                  const SizedBox(width: 20),
                  Expanded(child: articlePanel),
                  const SizedBox(width: 20),
                  SizedBox(width: 300, child: focusWordsPanel),
                ],
              );
            },
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: _ReadingStateCard(
            title: 'Okuma simdi acilamiyor',
            message:
                'Baglanti tekrar geldiginde ekrani yeniden acmayi dene veya okuma listesine geri don.',
            actionLabel: 'Okuma Listesine Don',
            onAction: () => context.go('/readings'),
          ),
        ),
      ),
    );
  }

  ReadingPassage? _resolveReading(
    List<ReadingPassage> items,
    String readingId,
  ) {
    for (final item in items) {
      if (item.id == readingId) {
        return item;
      }
    }

    return null;
  }

  _AdjacentReadings _resolveAdjacentReadings(
    List<ReadingPassage> items,
    String readingId,
  ) {
    final currentIndex = items.indexWhere((item) => item.id == readingId);
    if (currentIndex < 0) {
      return const _AdjacentReadings();
    }

    return _AdjacentReadings(
      previous: currentIndex > 0 ? items[currentIndex - 1] : null,
      next: currentIndex < items.length - 1 ? items[currentIndex + 1] : null,
    );
  }

  String? _resolveVisibleSummary(ReadingPassage reading, ReadingSeedData seed) {
    final readingSummary = reading.summary?.trim();
    if (readingSummary != null && readingSummary.isNotEmpty) {
      return isFallbackReadingSummary(readingSummary) ? null : readingSummary;
    }

    return isFallbackReadingSummary(seed.summary) ? null : seed.summary;
  }

  void _goBack(BuildContext context) {
    unawaited(_ttsController.stop());
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/readings');
  }

  Future<void> _refreshContent({required bool showFeedback}) async {
    if (_isRefreshingContent) {
      return;
    }

    setState(() {
      _isRefreshingContent = true;
    });

    AppResult<void>? result;
    if (!kIsWeb) {
      result = await ref
          .read(studentSyncRepositoryProvider)
          .syncNow(SyncScope.content);
    }
    ref.invalidate(studentReadingsProvider);
    ref.invalidate(studentReadingSectionsProvider(widget.readingId));
    ref.invalidate(studentReadingFocusWordsProvider(widget.readingId));
    ref.invalidate(studentReadingQuestionsProvider(widget.readingId));
    ref.invalidate(studentReadingWordCardsProvider(widget.readingId));

    if (!mounted) {
      return;
    }

    setState(() {
      _isRefreshingContent = false;
    });

    if (!showFeedback) {
      return;
    }

    if (result?.isFailure ?? false) {
      _showSnackBar('Okuma icerigi simdi yenilenemedi.');
      return;
    }

    _showSnackBar('Okuma icerigi yenilendi.');
  }

  void _navigateToReading(ReadingPassage reading, AccessContext accessContext) {
    unawaited(_ttsController.stop());
    if (reading.isPro && !accessContext.canViewPremium) {
      context.go('/premium');
      return;
    }

    context.go('/readings/${reading.id}');
  }

  Future<void> _toggleBookmark(String readingId) async {
    final result = await ref
        .read(studentReadingEngagementProvider.notifier)
        .toggleBookmark(readingId);
    if (mounted) {
      _showSnackBar(
        result.isSuccess
            ? 'Yer imi durumu guncellendi.'
            : 'Yer imi durumu simdi guncellenemedi.',
      );
    }
  }

  Future<void> _toggleFavorite(String readingId) async {
    final result = await ref
        .read(studentReadingEngagementProvider.notifier)
        .toggleFavorite(readingId);
    if (mounted) {
      _showSnackBar(
        result.isSuccess
            ? 'Favori durumu guncellendi.'
            : 'Favori durumu simdi guncellenemedi.',
      );
    }
  }

  void _handleWordTap(int lookupIndex, _SentenceToken token) {
    if (token.wordCard != null) {
      _showWordCardSheet(token.wordCard!);
      return;
    }

    if (!token.isLookupable) {
      return;
    }

    setState(() {
      final current = _selectedWords[lookupIndex];
      if (current?.lookupQuery == token.lookupQuery &&
          current?.displayWord == token.displayWord) {
        _selectedWords.remove(lookupIndex);
      } else {
        _selectedWords[lookupIndex] = _SelectedDictionaryWord(
          displayWord: token.displayWord,
          lookupQuery: token.lookupQuery,
        );
      }
    });
  }

  Future<void> _showWordCardSheet(WordEntry word) async {
    await showStudentWordCardSheet(
      context,
      initialWord: word,
      readingId: widget.readingId,
    );
  }

  Future<void> _toggleTranslation({
    required String readingId,
    required _ReadingArticleSection section,
  }) async {
    final lookupIndex = section.lookupIndex;
    if (_revealedTranslations.contains(lookupIndex)) {
      setState(() {
        _revealedTranslations.remove(lookupIndex);
      });
      return;
    }

    final directTranslation = section.turkishText?.trim();
    if (directTranslation != null && directTranslation.isNotEmpty) {
      setState(() {
        _revealedTranslations.add(lookupIndex);
      });
      return;
    }

    final controller = ref.read(studentTranslationProvider.notifier);
    final cached = controller.cachedTranslation(readingId, lookupIndex);
    if (cached != null) {
      setState(() {
        _revealedTranslations.add(lookupIndex);
      });
      return;
    }

    setState(() {
      _loadingTranslations.add(lookupIndex);
    });
    await controller.loadTranslation(
      readingId: readingId,
      sectionIndex: lookupIndex,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingTranslations.remove(lookupIndex);
      _revealedTranslations.add(lookupIndex);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectReadingQuestionOption(ReadingQuestion question, int optionIndex) {
    setState(() {
      _selectedQuestionOptionIndexes[question.id] = optionIndex;
      _readingQuizResult = null;
    });
  }

  void _clearReadingQuiz() {
    setState(() {
      _selectedQuestionOptionIndexes.clear();
      _readingQuizResult = null;
      _isSubmittingReadingQuiz = false;
    });
  }

  Future<void> _submitReadingQuiz(
    String readingId,
    List<ReadingQuestion> questions,
  ) async {
    if (_isSubmittingReadingQuiz || questions.isEmpty) {
      return;
    }

    for (final question in questions) {
      if (!_selectedQuestionOptionIndexes.containsKey(question.id)) {
        _showSnackBar('Tum sorulari cevapladiktan sonra kontrol et.');
        return;
      }
    }

    final correctCount = questions.where((question) {
      return _selectedQuestionOptionIndexes[question.id] ==
          question.correctOptionIndex;
    }).length;
    final wrongCount = questions.length - correctCount;
    final score = ((correctCount / questions.length) * 100).round();

    setState(() {
      _readingQuizResult = _ReadingQuizResult(
        correctCount: correctCount,
        wrongCount: wrongCount,
        score: score,
      );
      _isSubmittingReadingQuiz = true;
    });

    final result = await ref
        .read(studentWordProgressProvider.notifier)
        .recordTestAttempt(
          sourceType: 'reading',
          sourceId: readingId,
          score: score,
          correctCount: correctCount,
          wrongCount: wrongCount,
          payload: <String, dynamic>{
            'passage_id': readingId,
            'question_count': questions.length,
            'correct_count': correctCount,
            'wrong_count': wrongCount,
          },
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmittingReadingQuiz = false;
    });

    if (result.isFailure) {
      _showSnackBar('Mini test sonucu kaydedilemedi.');
    }
  }

  Future<void> _playPassage(
    String readingId,
    List<_ReadingArticleSection> articleSections,
  ) async {
    final segments = articleSections
        .map(
          (section) => StudentTtsPassageSegment(
            sentenceIndex: section.lookupIndex,
            text: section.englishText,
          ),
        )
        .toList(growable: false);
    final result = await ref
        .read(studentTtsControllerProvider.notifier)
        .playPassage(readingId: readingId, segments: segments);
    if (!mounted ||
        result == StudentTtsActionResult.started ||
        result == StudentTtsActionResult.stopped) {
      return;
    }
    _showTtsFeedback();
  }

  Future<void> _playSentence(
    String readingId,
    _ReadingArticleSection section,
  ) async {
    final result = await ref
        .read(studentTtsControllerProvider.notifier)
        .playSentence(
          readingId: readingId,
          sentenceIndex: section.lookupIndex,
          text: section.englishText,
        );
    if (!mounted ||
        result == StudentTtsActionResult.started ||
        result == StudentTtsActionResult.stopped) {
      return;
    }
    _showTtsFeedback();
  }

  Future<void> _stopSentence(_ReadingArticleSection section) {
    return ref
        .read(studentTtsControllerProvider.notifier)
        .stopIfMatching(
          readingId: widget.readingId,
          sentenceIndex: section.lookupIndex,
        );
  }

  Future<void> _stopActiveTts() {
    return _ttsController.stop();
  }

  void _showTtsFeedback() {
    final message =
        ref.read(studentTtsControllerProvider).errorMessage ??
        'Metin simdi okunamadi.';
    _showSnackBar(message);
  }
}

List<_ReadingArticleSection> _resolveArticleSections(
  ReadingSeedData seed,
  List<ReadingSentence>? remoteSections,
) {
  if (remoteSections != null && remoteSections.isNotEmpty) {
    final sections = <_ReadingArticleSection>[];
    for (var i = 0; i < remoteSections.length; i++) {
      final section = remoteSections[i];
      final englishText = section.englishText.trim();
      if (englishText.isEmpty) {
        continue;
      }
      sections.add(
        _ReadingArticleSection(
          lookupIndex: i,
          heading: '',
          englishText: englishText,
          turkishText: _trimToNull(section.turkishText),
        ),
      );
    }
    return sections;
  }

  final sections = <_ReadingArticleSection>[];
  for (var i = 0; i < seed.sections.length; i++) {
    final section = seed.sections[i];
    if (section.body.trim().isEmpty) {
      continue;
    }
    sections.add(
      _ReadingArticleSection(
        lookupIndex: i,
        heading: section.heading,
        englishText: section.body,
      ),
    );
  }
  return sections;
}

String? _trimToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

List<WordEntry> _resolveLinkedWordCards(
  List<ReadingFocusWord> focusWords,
  Map<String, WordEntry> wordCardsById,
) {
  return focusWords
      .map((item) => wordCardsById[item.wordId] ?? _fallbackWordEntry(item))
      .toList(growable: false);
}

WordEntry _fallbackWordEntry(ReadingFocusWord word) {
  return WordEntry(
    id: word.wordId,
    packId: '',
    enWord: word.enWord,
    trMeaning: word.trMeaning,
    pos: word.pos ?? '',
  );
}

class _ReadingArticleSection {
  const _ReadingArticleSection({
    required this.lookupIndex,
    required this.heading,
    required this.englishText,
    this.turkishText,
  });

  final int lookupIndex;
  final String heading;
  final String englishText;
  final String? turkishText;
}

class _SelectedDictionaryWord {
  const _SelectedDictionaryWord({
    required this.displayWord,
    required this.lookupQuery,
  });

  final String displayWord;
  final String lookupQuery;
}

class _AdjacentReadings {
  const _AdjacentReadings({this.previous, this.next});

  final ReadingPassage? previous;
  final ReadingPassage? next;
}

class _ReadingQuizResult {
  const _ReadingQuizResult({
    required this.correctCount,
    required this.wrongCount,
    required this.score,
  });

  final int correctCount;
  final int wrongCount;
  final int score;
}

class _SentenceToken {
  const _SentenceToken({
    required this.displayWord,
    required this.lookupQuery,
    this.wordCard,
  });

  final String displayWord;
  final String lookupQuery;
  final WordEntry? wordCard;

  bool get isLookupable => lookupQuery.isNotEmpty;
}

final RegExp _tokenPattern = RegExp(r'\S+');
final RegExp _edgePunctuationPattern = RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$');

List<_SentenceToken> _tokenizeSentence(
  String text,
  List<WordEntry> focusWordCards,
) {
  final rawTokens = _tokenPattern
      .allMatches(text)
      .map(
        (match) => _RawSentenceToken(
          displayWord: match.group(0) ?? '',
          normalized: _normalizeDictionaryQuery(match.group(0) ?? ''),
        ),
      )
      .where((token) => token.displayWord.isNotEmpty)
      .toList(growable: false);
  if (rawTokens.isEmpty) {
    return const <_SentenceToken>[];
  }

  final focusPhrases =
      focusWordCards
          .map((item) {
            final parts = item.enWord
                .split(RegExp(r'\s+'))
                .map(_normalizeDictionaryQuery)
                .where((part) => part.isNotEmpty)
                .toList(growable: false);
            return _FocusPhrase(word: item, parts: parts);
          })
          .where((item) => item.parts.isNotEmpty)
          .toList(growable: false)
        ..sort(
          (left, right) => right.parts.length.compareTo(left.parts.length),
        );

  final matchedWords = List<WordEntry?>.filled(rawTokens.length, null);
  for (var index = 0; index < rawTokens.length; index++) {
    if (matchedWords[index] != null) {
      continue;
    }

    for (final phrase in focusPhrases) {
      if (phrase.parts.length == 1 &&
          rawTokens[index].normalized == phrase.parts.first) {
        matchedWords[index] = phrase.word;
        break;
      }

      if (index + phrase.parts.length > rawTokens.length) {
        continue;
      }

      var matches = true;
      for (var partIndex = 0; partIndex < phrase.parts.length; partIndex++) {
        if (rawTokens[index + partIndex].normalized !=
            phrase.parts[partIndex]) {
          matches = false;
          break;
        }
      }
      if (!matches) {
        continue;
      }

      for (var partIndex = 0; partIndex < phrase.parts.length; partIndex++) {
        matchedWords[index + partIndex] = phrase.word;
      }
      break;
    }
  }

  return List<_SentenceToken>.generate(rawTokens.length, (index) {
    final token = rawTokens[index];
    return _SentenceToken(
      displayWord: token.displayWord,
      lookupQuery: token.normalized,
      wordCard: matchedWords[index],
    );
  }, growable: false);
}

String _normalizeDictionaryQuery(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(_edgePunctuationPattern, '');
}

class _RawSentenceToken {
  const _RawSentenceToken({
    required this.displayWord,
    required this.normalized,
  });

  final String displayWord;
  final String normalized;
}

class _FocusPhrase {
  const _FocusPhrase({required this.word, required this.parts});

  final WordEntry word;
  final List<String> parts;
}

class ReadingDetailHeader extends StatelessWidget {
  const ReadingDetailHeader({
    super.key,
    required this.isBookmarked,
    required this.isFavorite,
    required this.canToggleEngagement,
    required this.onBack,
    required this.onBookmarkToggle,
    required this.onFavoriteToggle,
    required this.onShare,
    this.engagementHelperText,
  });

  final bool isBookmarked;
  final bool isFavorite;
  final bool canToggleEngagement;
  final VoidCallback onBack;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onShare;
  final String? engagementHelperText;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: Icon(Icons.chevron_left_rounded, color: tokens.secondaryText),
            label: const Text('Geri Don'),
          ),
          const Spacer(),
          if (engagementHelperText != null) ...[
            Text(
              engagementHelperText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tokens.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Tooltip(
            message: canToggleEngagement
                ? 'Yer imi'
                : 'Kaydetmek icin giris yap',
            child: IconButton(
              onPressed: canToggleEngagement ? onBookmarkToggle : null,
              icon: Icon(
                isBookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
            ),
          ),
          Tooltip(
            message: canToggleEngagement
                ? 'Favori'
                : 'Kaydetmek icin giris yap',
            child: IconButton(
              onPressed: canToggleEngagement ? onFavoriteToggle : null,
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
            ),
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
    );
  }
}

class _ReadingInfoPanel extends StatelessWidget {
  const _ReadingInfoPanel({
    required this.readingId,
    required this.reading,
    required this.seed,
    required this.summary,
    required this.focusModeEnabled,
    required this.articleSections,
    required this.ttsState,
    required this.onToggleFocusMode,
    required this.onPlayPassage,
    required this.onStopPassage,
  });

  final String readingId;
  final ReadingPassage reading;
  final ReadingSeedData seed;
  final String? summary;
  final bool focusModeEnabled;
  final List<_ReadingArticleSection> articleSections;
  final StudentTtsState ttsState;
  final VoidCallback onToggleFocusMode;
  final Future<void> Function() onPlayPassage;
  final Future<void> Function() onStopPassage;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final isPassageSpeaking =
        ttsState.isSpeaking &&
        ttsState.activeTarget == StudentTtsTarget.passage &&
        ttsState.activeReadingId == readingId;
    final isPassageInitializing =
        ttsState.isInitializing &&
        ttsState.activeTarget == StudentTtsTarget.passage &&
        ttsState.activeReadingId == readingId;

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadingArtwork(
            seed: seed,
            remoteUrl: reading.coverUrl,
            semanticLabel: reading.coverAltText ?? reading.title,
            height: 220,
            borderRadius: BorderRadius.circular(20),
          ),
          const SizedBox(height: 18),
          Text(reading.title, style: Theme.of(context).textTheme.headlineSmall),
          if (summary != null) ...[
            const SizedBox(height: 10),
            Text(
              summary!,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
            ),
          ],
          const SizedBox(height: 16),
          _MetaPill(label: 'Yazar', value: seed.author),
          const SizedBox(height: 10),
          _MetaPill(label: 'Ilerleme', value: '%${seed.progressPercent}'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: ValueKey<String>('reading_passage_tts_$readingId'),
              onPressed: articleSections.isEmpty || ttsState.isUnavailable
                  ? null
                  : () async {
                      if (isPassageSpeaking) {
                        await onStopPassage();
                        return;
                      }
                      await onPlayPassage();
                    },
              icon: isPassageInitializing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      isPassageSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                    ),
              label: Text(isPassageSpeaking ? 'Durdur' : 'Parcayi Dinle'),
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: focusModeEnabled,
            onChanged: (_) => onToggleFocusMode(),
            title: const Text('Odak modu'),
            subtitle: const Text('Dikkat dagitan bolumleri azalt.'),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.secondaryText),
          ),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _ReadingArticlePanel extends ConsumerWidget {
  const _ReadingArticlePanel({
    required this.readingId,
    required this.title,
    required this.sections,
    required this.previousReading,
    required this.nextReading,
    required this.canAccessPremium,
    required this.focusModeEnabled,
    required this.linkedWordCards,
    required this.revealedTranslations,
    required this.loadingTranslations,
    required this.selectedWords,
    required this.questions,
    required this.selectedQuestionOptionIndexes,
    required this.readingQuizResult,
    required this.isSubmittingReadingQuiz,
    required this.persistsAttempts,
    required this.translationForSection,
    required this.onNavigateToReading,
    required this.onPlaySentence,
    required this.onStopSentence,
    required this.onWordTap,
    required this.onWordLongPress,
    required this.onQuestionSelected,
    required this.onSubmitQuiz,
    required this.onClearQuiz,
  });

  final String readingId;
  final String title;
  final List<_ReadingArticleSection> sections;
  final ReadingPassage? previousReading;
  final ReadingPassage? nextReading;
  final bool canAccessPremium;
  final bool focusModeEnabled;
  final List<WordEntry> linkedWordCards;
  final Set<int> revealedTranslations;
  final Set<int> loadingTranslations;
  final Map<int, _SelectedDictionaryWord> selectedWords;
  final AsyncValue<List<ReadingQuestion>> questions;
  final Map<String, int> selectedQuestionOptionIndexes;
  final _ReadingQuizResult? readingQuizResult;
  final bool isSubmittingReadingQuiz;
  final bool persistsAttempts;
  final String? Function(int lookupIndex) translationForSection;
  final ValueChanged<ReadingPassage> onNavigateToReading;
  final Future<void> Function(String readingId, _ReadingArticleSection section)
  onPlaySentence;
  final Future<void> Function(_ReadingArticleSection section) onStopSentence;
  final void Function(int lookupIndex, _SentenceToken token) onWordTap;
  final ValueChanged<_ReadingArticleSection> onWordLongPress;
  final void Function(ReadingQuestion question, int optionIndex)
  onQuestionSelected;
  final Future<void> Function(List<ReadingQuestion> questions) onSubmitQuiz;
  final VoidCallback onClearQuiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(studentTtsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSurfaceCard(
          child: Text(title, style: Theme.of(context).textTheme.displaySmall),
        ),
        const SizedBox(height: 16),
        for (final section in sections) ...[
          Builder(
            builder: (context) {
              final isSentenceSpeaking =
                  ttsState.isSpeaking &&
                  ttsState.activeReadingId == readingId &&
                  ttsState.activeSentenceIndex == section.lookupIndex;
              final isSentenceInitializing =
                  ttsState.isInitializing &&
                  ttsState.activeReadingId == readingId &&
                  ttsState.activeSentenceIndex == section.lookupIndex;
              final isHighlighted =
                  ttsState.activeReadingId == readingId &&
                  ttsState.activeSentenceIndex == section.lookupIndex &&
                  (ttsState.activeTarget == StudentTtsTarget.passage ||
                      ttsState.activeTarget == StudentTtsTarget.sentence) &&
                  (ttsState.isSpeaking || ttsState.isInitializing);

              return AnimatedContainer(
                key: ValueKey<String>(
                  'reading_section_${section.lookupIndex}_${isHighlighted ? 'active' : 'idle'}',
                ),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? AppThemeTokens.of(
                          context,
                        ).accentBlue.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: isHighlighted
                        ? AppThemeTokens.of(context).accentBlue
                        : Colors.transparent,
                  ),
                ),
                child: StudentSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (section.heading.isNotEmpty)
                            Expanded(
                              child: Text(
                                section.heading,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            )
                          else
                            const Spacer(),
                          StudentTtsIconButton(
                            key: ValueKey<String>(
                              'reading_sentence_tts_${section.lookupIndex}',
                            ),
                            isSpeaking: isSentenceSpeaking,
                            isInitializing: isSentenceInitializing,
                            isUnavailable: ttsState.isUnavailable,
                            tooltip: isSentenceSpeaking
                                ? 'Durdur'
                                : 'Cumleyi dinle',
                            iconSize: 18,
                            visualDensity: VisualDensity.compact,
                            onPlay: () => onPlaySentence(readingId, section),
                            onStop: () => onStopSentence(section),
                          ),
                        ],
                      ),
                      if (section.heading.isNotEmpty)
                        const SizedBox(height: 12),
                      _InteractiveSentenceText(
                        sentence: section.englishText,
                        focusModeEnabled: focusModeEnabled,
                        focusWordCards: linkedWordCards,
                        selectedWord: selectedWords[section.lookupIndex],
                        onWordTap: (token) =>
                            onWordTap(section.lookupIndex, token),
                        onWordLongPress: () => onWordLongPress(section),
                      ),
                      if (selectedWords.containsKey(section.lookupIndex)) ...[
                        const SizedBox(height: 16),
                        _DictionaryInlinePanel(
                          query: selectedWords[section.lookupIndex]!,
                        ),
                      ],
                      if (loadingTranslations.contains(
                        section.lookupIndex,
                      )) ...[
                        const SizedBox(height: 16),
                        const _InlineLoadingPanel(),
                      ],
                      if (revealedTranslations.contains(
                        section.lookupIndex,
                      )) ...[
                        const SizedBox(height: 16),
                        _SentenceTranslationPanel(
                          translation:
                              section.turkishText ??
                              translationForSection(section.lookupIndex) ??
                              'Cumle cevirisi bulunamadi.',
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        ...switch (questions) {
          AsyncData<List<ReadingQuestion>>(value: final items)
              when items.isNotEmpty => <Widget>[
                _ReadingQuestionsPanel(
                  questions: items,
                  selectedQuestionOptionIndexes: selectedQuestionOptionIndexes,
                  readingQuizResult: readingQuizResult,
                  isSubmitting: isSubmittingReadingQuiz,
                  persistsAttempts: persistsAttempts,
                  onOptionSelected: onQuestionSelected,
                  onSubmit: () => onSubmitQuiz(items),
                  onClear: onClearQuiz,
                ),
                const SizedBox(height: 16),
              ],
          AsyncLoading<List<ReadingQuestion>>() => <Widget>[
            _ReadingQuestionsLoadingCard(),
            const SizedBox(height: 16),
          ],
          AsyncError<List<ReadingQuestion>>() => <Widget>[
            _ReadingQuestionsStateCard(
              title: 'Mini test simdi yuklenemiyor',
              message:
                  'Soru kayitlari daha sonra yeniden yuklenebilir. Okuma icerigi kullanilmaya devam ediyor.',
            ),
            const SizedBox(height: 16),
          ],
          _ => const <Widget>[],
        },
        _ReadingPassagePager(
          previousReading: previousReading,
          nextReading: nextReading,
          canAccessPremium: canAccessPremium,
          onNavigateToReading: onNavigateToReading,
        ),
      ],
    );
  }
}

class _ReadingQuestionsPanel extends StatelessWidget {
  const _ReadingQuestionsPanel({
    required this.questions,
    required this.selectedQuestionOptionIndexes,
    required this.readingQuizResult,
    required this.isSubmitting,
    required this.persistsAttempts,
    required this.onOptionSelected,
    required this.onSubmit,
    required this.onClear,
  });

  final List<ReadingQuestion> questions;
  final Map<String, int> selectedQuestionOptionIndexes;
  final _ReadingQuizResult? readingQuizResult;
  final bool isSubmitting;
  final bool persistsAttempts;
  final void Function(ReadingQuestion question, int optionIndex) onOptionSelected;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final result = readingQuizResult;
    final allAnswered = questions.every(
      (question) => selectedQuestionOptionIndexes.containsKey(question.id),
    );

    return StudentSurfaceCard(
      key: const ValueKey<String>('reading_quiz_panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mini Test', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            persistsAttempts
                ? 'Gecisi bitirdikten sonra cevaplarini kontrol et.'
                : 'Cevaplarini simdi kontrol edebilirsin. Sonuc bu oturumda kalir.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (result != null) ...[
            const SizedBox(height: 14),
            _ReadingQuizResultBanner(result: result, questionCount: questions.length),
          ],
          const SizedBox(height: 16),
          for (final question in questions) ...[
            _ReadingQuestionCard(
              question: question,
              selectedOptionIndex: selectedQuestionOptionIndexes[question.id],
              resultVisible: result != null,
              onOptionSelected: (optionIndex) =>
                  onOptionSelected(question, optionIndex),
            ),
            if (question.explanation != null &&
                question.explanation!.trim().isNotEmpty &&
                result != null) ...[
              const SizedBox(height: 10),
              _ReadingQuestionExplanation(text: question.explanation!.trim()),
            ],
            if (question != questions.last) const SizedBox(height: 16),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              OutlinedButton(
                onPressed: selectedQuestionOptionIndexes.isEmpty ? null : onClear,
                child: const Text('Temizle'),
              ),
              const Spacer(),
              FilledButton(
                key: const ValueKey<String>('reading_quiz_submit'),
                onPressed: allAnswered && !isSubmitting ? onSubmit : null,
                child: Text(
                  isSubmitting ? 'Kaydediliyor...' : 'Cevaplari Kontrol Et',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingQuizResultBanner extends StatelessWidget {
  const _ReadingQuizResultBanner({
    required this.result,
    required this.questionCount,
  });

  final _ReadingQuizResult result;
  final int questionCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allCorrect = result.correctCount == questionCount;
    final background = allCorrect
        ? colorScheme.primaryContainer
        : colorScheme.secondaryContainer;
    final foreground = allCorrect
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Skor ${result.score}% - ${result.correctCount} dogru, ${result.wrongCount} yanlis',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class _ReadingQuestionCard extends StatelessWidget {
  const _ReadingQuestionCard({
    required this.question,
    required this.selectedOptionIndex,
    required this.resultVisible,
    required this.onOptionSelected,
  });

  final ReadingQuestion question;
  final int? selectedOptionIndex;
  final bool resultVisible;
  final ValueChanged<int> onOptionSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.question, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (var index = 0; index < question.options.length; index++) ...[
          _ReadingQuestionOptionTile(
            key: ValueKey<String>('reading_quiz_option_${question.id}_$index'),
            label: question.options[index],
            isSelected: selectedOptionIndex == index,
            isCorrect: question.correctOptionIndex == index,
            showResult: resultVisible,
            onTap: () => onOptionSelected(index),
          ),
          if (index < question.options.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ReadingQuestionOptionTile extends StatelessWidget {
  const _ReadingQuestionOptionTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isCorrect,
    required this.showResult,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isCorrect;
  final bool showResult;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isWrongSelection = showResult && isSelected && !isCorrect;
    final isCorrectSelection = showResult && isCorrect;
    final borderColor = isCorrectSelection
        ? colorScheme.primary
        : isWrongSelection
        ? colorScheme.error
        : isSelected
        ? tokens.accent
        : tokens.surfaceBorder;
    final backgroundColor = isCorrectSelection
        ? colorScheme.primaryContainer
        : isWrongSelection
        ? colorScheme.errorContainer
        : isSelected
        ? tokens.accentSoft.withValues(alpha: 0.28)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            color: backgroundColor,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _ReadingQuestionExplanation extends StatelessWidget {
  const _ReadingQuestionExplanation({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ReadingQuestionsLoadingCard extends StatelessWidget {
  const _ReadingQuestionsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _ReadingQuestionsStateCard(
      title: 'Mini test yukleniyor',
      message: 'Okuma sorulari getiriliyor.',
      isLoading: true,
    );
  }
}

class _ReadingQuestionsStateCard extends StatelessWidget {
  const _ReadingQuestionsStateCard({
    required this.title,
    required this.message,
    this.isLoading = false,
  });

  final String title;
  final String message;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingPassagePager extends StatelessWidget {
  const _ReadingPassagePager({
    required this.previousReading,
    required this.nextReading,
    required this.canAccessPremium,
    required this.onNavigateToReading,
  });

  final ReadingPassage? previousReading;
  final ReadingPassage? nextReading;
  final bool canAccessPremium;
  final ValueChanged<ReadingPassage> onNavigateToReading;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: _ReadingNavigationButton(
              key: ValueKey<String>(
                'reading_nav_prev_${previousReading?.id ?? 'none'}',
              ),
              label: 'Onceki parca',
              icon: Icons.arrow_back_rounded,
              reading: previousReading,
              canAccessPremium: canAccessPremium,
              alignment: CrossAxisAlignment.start,
              onNavigateToReading: onNavigateToReading,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(width: 1, height: 52, color: tokens.surfaceBorder),
          ),
          Expanded(
            child: _ReadingNavigationButton(
              key: ValueKey<String>(
                'reading_nav_next_${nextReading?.id ?? 'none'}',
              ),
              label: 'Sonraki parca',
              icon: Icons.arrow_forward_rounded,
              reading: nextReading,
              canAccessPremium: canAccessPremium,
              alignment: CrossAxisAlignment.end,
              onNavigateToReading: onNavigateToReading,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingNavigationButton extends StatelessWidget {
  const _ReadingNavigationButton({
    super.key,
    required this.label,
    required this.icon,
    required this.reading,
    required this.canAccessPremium,
    required this.alignment,
    required this.onNavigateToReading,
  });

  final String label;
  final IconData icon;
  final ReadingPassage? reading;
  final bool canAccessPremium;
  final CrossAxisAlignment alignment;
  final ValueChanged<ReadingPassage> onNavigateToReading;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final targetReading = reading;
    final isLocked = targetReading?.isPro == true && !canAccessPremium;

    return Opacity(
      opacity: targetReading == null ? 0.45 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: targetReading == null
            ? null
            : () => onNavigateToReading(targetReading),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: alignment,
            children: [
              Row(
                mainAxisAlignment: alignment == CrossAxisAlignment.end
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  if (alignment == CrossAxisAlignment.start) ...[
                    Icon(icon, size: 18, color: tokens.secondaryText),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (alignment == CrossAxisAlignment.end) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 18, color: tokens.secondaryText),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                targetReading?.title ?? 'Yok',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: alignment == CrossAxisAlignment.end
                    ? TextAlign.end
                    : TextAlign.start,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (isLocked) ...[
                const SizedBox(height: 6),
                Text(
                  'Pro',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: tokens.accentBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractiveSentenceText extends StatelessWidget {
  const _InteractiveSentenceText({
    required this.sentence,
    required this.focusModeEnabled,
    required this.focusWordCards,
    required this.selectedWord,
    required this.onWordTap,
    required this.onWordLongPress,
  });

  final String sentence;
  final bool focusModeEnabled;
  final List<WordEntry> focusWordCards;
  final _SelectedDictionaryWord? selectedWord;
  final ValueChanged<_SentenceToken> onWordTap;
  final VoidCallback onWordLongPress;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(height: focusModeEnabled ? 1.9 : 1.6);
    final tokens = AppThemeTokens.of(context);
    final words = _tokenizeSentence(sentence, focusWordCards);

    return Wrap(
      spacing: 4,
      runSpacing: focusModeEnabled ? 10 : 6,
      children: [
        for (final token in words)
          _SentenceTokenChip(
            token: token,
            textStyle: textStyle,
            isSelected:
                selectedWord?.lookupQuery == token.lookupQuery &&
                selectedWord?.displayWord == token.displayWord,
            isFocusWord: token.wordCard != null,
            accentColor: tokens.accentSoft,
            focusColor: tokens.accentBlue,
            onTap: () => onWordTap(token),
            onLongPress: onWordLongPress,
          ),
      ],
    );
  }
}

class _SentenceTokenChip extends StatelessWidget {
  const _SentenceTokenChip({
    required this.token,
    required this.textStyle,
    required this.isSelected,
    required this.isFocusWord,
    required this.accentColor,
    required this.focusColor,
    required this.onTap,
    required this.onLongPress,
  });

  final _SentenceToken token;
  final TextStyle? textStyle;
  final bool isSelected;
  final bool isFocusWord;
  final Color accentColor;
  final Color focusColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final resolvedTextStyle = (textStyle ?? const TextStyle()).copyWith(
      fontWeight: isFocusWord ? FontWeight.w800 : textStyle?.fontWeight,
      color: isFocusWord ? focusColor : textStyle?.color,
      decoration: isFocusWord ? TextDecoration.underline : TextDecoration.none,
      decorationColor: isFocusWord ? focusColor.withValues(alpha: 0.45) : null,
      decorationThickness: isFocusWord ? 1.6 : null,
    );

    return Material(
      color: isSelected
          ? accentColor.withValues(alpha: 0.16)
          : isFocusWord
          ? focusColor.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: token.isLookupable ? onTap : null,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(token.displayWord, style: resolvedTextStyle),
        ),
      ),
    );
  }
}

class _DictionaryInlinePanel extends ConsumerWidget {
  const _DictionaryInlinePanel({required this.query});

  final _SelectedDictionaryWord query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final dictionaryEntry = ref.watch(
      studentDictionaryEntryProvider(query.lookupQuery),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surfaceMuted,
        borderRadius: BorderRadius.circular(18),
      ),
      child: dictionaryEntry.when(
        loading: () => const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Sozluk aranıyor...')),
          ],
        ),
        error: (error, stackTrace) => const Text('Sozlukte bulunamadi.'),
        data: (entry) {
          if (entry == null) {
            return const Text('Sozlukte bulunamadi.');
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      query.displayWord,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (entry.pos != null && entry.pos!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accentSoft.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(entry.pos!),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.trMeaning,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InlineLoadingPanel extends StatelessWidget {
  const _InlineLoadingPanel();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.accentSoft.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Cumle cevirisi yukleniyor...')),
        ],
      ),
    );
  }
}

class _SentenceTranslationPanel extends StatelessWidget {
  const _SentenceTranslationPanel({required this.translation});

  final String translation;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.accentSoft.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(translation, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _FocusWordsPanel extends StatelessWidget {
  const _FocusWordsPanel({
    required this.focusWords,
    required this.linkedWordCards,
    required this.onWordTap,
  });

  final AsyncValue<List<ReadingFocusWord>> focusWords;
  final List<WordEntry> linkedWordCards;
  final ValueChanged<WordEntry> onWordTap;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ODAK KELIMELER', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          focusWords.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Text('Odak kelimeler simdi yuklenemiyor.'),
            data: (words) {
              if (words.isEmpty) {
                return const Text('Bu parcaya henuz odak kelime baglanmamis.');
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final word in words)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FocusWordTile(
                        word: linkedWordCards.firstWhere(
                          (item) => item.id == word.wordId,
                          orElse: () => _fallbackWordEntry(word),
                        ),
                        onTap: onWordTap,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FocusWordTile extends StatelessWidget {
  const _FocusWordTile({required this.word, required this.onTap});

  final WordEntry word;
  final ValueChanged<WordEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Material(
      color: tokens.surfaceMuted,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onTap(word),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      word.enWord,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      word.trMeaning,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              if (word.pos.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(word.pos, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingStateCard extends StatelessWidget {
  const _ReadingStateCard({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
