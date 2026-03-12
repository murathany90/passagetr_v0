import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasTriggeredInitialRefresh) {
        return;
      }
      _hasTriggeredInitialRefresh = true;
      _refreshContent(showFeedback: false);
    });
  }

  @override
  void didUpdateWidget(covariant StudentReadingDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readingId == widget.readingId) {
      return;
    }

    _revealedTranslations.clear();
    _loadingTranslations.clear();
    _selectedWords.clear();
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
        final focusWordCards = ref.watch(
          studentReadingWordCardsProvider(reading.id),
        );
        final linkedWordCards = _resolveLinkedWordCards(
          focusWords.valueOrNull ?? const <ReadingFocusWord>[],
          focusWordCards.valueOrNull ?? const <String, WordEntry>{},
        );
        final engagement = ref
            .watch(studentReadingEngagementProvider.notifier)
            .stateFor(reading.id);

        return StudentDetailFrame(
          destination: StudentDestination.readings,
          accessContext: accessContext,
          header: ReadingDetailHeader(
            isBookmarked: engagement.isBookmarked,
            isFavorite: engagement.isFavorite,
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
                reading: reading,
                seed: seed,
                summary: _resolveVisibleSummary(reading, seed),
                focusModeEnabled: _focusModeEnabled,
                onToggleFocusMode: () {
                  setState(() {
                    _focusModeEnabled = !_focusModeEnabled;
                  });
                },
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
                translationForSection: (lookupIndex) => ref
                    .read(studentTranslationProvider.notifier)
                    .cachedTranslation(reading.id, lookupIndex),
                onNavigateToReading: (targetReading) =>
                    _navigateToReading(targetReading, accessContext),
                onWordTap: _handleWordTap,
                onWordLongPress: (section) =>
                    _toggleTranslation(readingId: reading.id, section: section),
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
    if (reading.isPro && !accessContext.canViewPremium) {
      context.go('/premium');
      return;
    }

    context.go('/readings/${reading.id}');
  }

  Future<void> _toggleBookmark(String readingId) async {
    await ref
        .read(studentReadingEngagementProvider.notifier)
        .toggleBookmark(readingId);
    if (mounted) {
      _showSnackBar('Yer imi durumu guncellendi.');
    }
  }

  Future<void> _toggleFavorite(String readingId) async {
    await ref
        .read(studentReadingEngagementProvider.notifier)
        .toggleFavorite(readingId);
    if (mounted) {
      _showSnackBar('Favori durumu guncellendi.');
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
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Kelime kartini kapat',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.54),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 16,
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    key: const ValueKey<String>('word_card_dismiss_area'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: const SizedBox.expand(),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: GestureDetector(
                      onTap: () {},
                      child: SingleChildScrollView(
                        child: _WordCardSheet(initialWord: word),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.08),
                  end: Offset.zero,
                ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
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

List<String> _splitWordList(String? rawValue) {
  if (rawValue == null || rawValue.trim().isEmpty) {
    return const <String>[];
  }

  final values = rawValue
      .split(RegExp(r'[,\n;|]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
  values.sort();
  return values;
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

  final focusPhrases = focusWordCards
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
    ..sort((left, right) => right.parts.length.compareTo(left.parts.length));

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
        if (rawTokens[index + partIndex].normalized != phrase.parts[partIndex]) {
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
  const _RawSentenceToken({required this.displayWord, required this.normalized});

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
    required this.onBack,
    required this.onBookmarkToggle,
    required this.onFavoriteToggle,
    required this.onShare,
  });

  final bool isBookmarked;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onShare;

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
          IconButton(
            onPressed: onBookmarkToggle,
            icon: Icon(
              isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
          ),
          IconButton(
            onPressed: onFavoriteToggle,
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
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
    required this.reading,
    required this.seed,
    required this.summary,
    required this.focusModeEnabled,
    required this.onToggleFocusMode,
  });

  final ReadingPassage reading;
  final ReadingSeedData seed;
  final String? summary;
  final bool focusModeEnabled;
  final VoidCallback onToggleFocusMode;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReadingArtwork(
            seed: seed,
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
    required this.translationForSection,
    required this.onNavigateToReading,
    required this.onWordTap,
    required this.onWordLongPress,
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
  final String? Function(int lookupIndex) translationForSection;
  final ValueChanged<ReadingPassage> onNavigateToReading;
  final void Function(int lookupIndex, _SentenceToken token) onWordTap;
  final ValueChanged<_ReadingArticleSection> onWordLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSurfaceCard(
          child: Text(title, style: Theme.of(context).textTheme.displaySmall),
        ),
        const SizedBox(height: 16),
        for (final section in sections) ...[
          StudentSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (section.heading.isNotEmpty) ...[
                  Text(
                    section.heading,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                ],
                _InteractiveSentenceText(
                  sentence: section.englishText,
                  focusModeEnabled: focusModeEnabled,
                  focusWordCards: linkedWordCards,
                  selectedWord: selectedWords[section.lookupIndex],
                  onWordTap: (token) => onWordTap(section.lookupIndex, token),
                  onWordLongPress: () => onWordLongPress(section),
                ),
                if (selectedWords.containsKey(section.lookupIndex)) ...[
                  const SizedBox(height: 16),
                  _DictionaryInlinePanel(
                    query: selectedWords[section.lookupIndex]!,
                  ),
                ],
                if (loadingTranslations.contains(section.lookupIndex)) ...[
                  const SizedBox(height: 16),
                  const _InlineLoadingPanel(),
                ],
                if (revealedTranslations.contains(section.lookupIndex)) ...[
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
          const SizedBox(height: 16),
        ],
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
            child: Container(
              width: 1,
              height: 52,
              color: tokens.surfaceBorder,
            ),
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

class _WordCardSheet extends ConsumerStatefulWidget {
  const _WordCardSheet({required this.initialWord});

  final WordEntry initialWord;

  @override
  ConsumerState<_WordCardSheet> createState() => _WordCardSheetState();
}

class _WordCardSheetState extends ConsumerState<_WordCardSheet> {
  late _WordSheetContent _content = _WordSheetContent.word(widget.initialWord);
  bool _isResolvingRelated = false;

  Future<void> _openRelatedWord(String label) async {
    final normalizedQuery = _normalizeDictionaryQuery(label);
    if (normalizedQuery.isEmpty || _isResolvingRelated) {
      return;
    }

    final activeWord = _content.word;
    if (activeWord != null &&
        _normalizeDictionaryQuery(activeWord.enWord) == normalizedQuery) {
      return;
    }

    setState(() {
      _isResolvingRelated = true;
    });

    try {
      final cachedWords = ref.read(studentWordsProvider).valueOrNull;
      late final List<WordEntry> allWords;
      if (cachedWords != null) {
        allWords = cachedWords;
      } else {
        allWords = await ref.read(studentWordsProvider.future);
      }
      final matchedWord = _findWordCardByQuery(allWords, normalizedQuery);
      if (!mounted) {
        return;
      }

      if (matchedWord != null) {
        setState(() {
          _content = _WordSheetContent.word(matchedWord);
        });
        return;
      }

      final dictionaryEntry = await ref.read(
        studentDictionaryEntryProvider(normalizedQuery).future,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _content = dictionaryEntry != null
            ? _WordSheetContent.dictionary(
                query: label.trim(),
                dictionaryEntry: dictionaryEntry,
              )
            : _WordSheetContent.missing(query: label.trim());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingRelated = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final word = _content.word;
    final dictionaryEntry = _content.dictionaryEntry;
    final synonyms = _splitWordList(word?.synonymsRaw);
    final antonyms = _splitWordList(word?.antonymsRaw);
    final title = word?.enWord ?? _content.query;
    final partOfSpeech = word?.pos ?? dictionaryEntry?.pos ?? '';
    final meaning = word?.trMeaning ?? dictionaryEntry?.trMeaning;

    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (word == null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surfaceMuted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Sozluk cevirisi',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.secondaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isResolvingRelated) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 10, right: 8),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
              if (partOfSpeech.trim().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.accentBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    partOfSpeech,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.accentBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              IconButton(
                key: const ValueKey<String>('word_card_close_button'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Kapat',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            meaning ?? 'Bu kelime icin ceviri bulunamadi.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (word != null &&
              (word.exampleEn.trim().isNotEmpty ||
                  (word.exampleTr?.trim().isNotEmpty ?? false))) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Ornek',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (word.exampleEn.trim().isNotEmpty)
                    Text(
                      word.exampleEn.trim(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (word.exampleTr?.trim().isNotEmpty ?? false) ...[
                    const SizedBox(height: 8),
                    Text(
                      word.exampleTr!.trim(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (word != null && synonyms.isNotEmpty) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Es anlamli',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in synonyms)
                    _WordListChip(
                      label: item,
                      color: tokens.accentBlue,
                      onTap: () => _openRelatedWord(item),
                    ),
                ],
              ),
            ),
          ],
          if (word != null && antonyms.isNotEmpty) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Zit anlamli',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in antonyms)
                    _WordListChip(
                      label: item,
                      color: tokens.warning,
                      onTap: () => _openRelatedWord(item),
                    ),
                ],
              ),
            ),
          ],
          if (word != null && (word.notes?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: 18),
            _WordCardSection(
              title: 'Not',
              child: Text(
                word.notes!.trim(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.secondaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WordSheetContent {
  const _WordSheetContent.word(this.word)
    : query = '',
      dictionaryEntry = null;

  const _WordSheetContent.dictionary({
    required this.query,
    required this.dictionaryEntry,
  }) : word = null;

  const _WordSheetContent.missing({required this.query})
    : word = null,
      dictionaryEntry = null;

  final WordEntry? word;
  final String query;
  final DictionaryEntry? dictionaryEntry;
}

class _WordCardSection extends StatelessWidget {
  const _WordCardSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _WordListChip extends StatelessWidget {
  const _WordListChip({
    required this.label,
    required this.color,
    this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

WordEntry? _findWordCardByQuery(List<WordEntry> words, String query) {
  for (final word in words) {
    if (_normalizeDictionaryQuery(word.enWord) == query) {
      return word;
    }
  }

  return null;
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
