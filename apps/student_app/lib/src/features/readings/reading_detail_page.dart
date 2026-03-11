import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final Set<int> _revealedTranslations = <int>{};
  final Set<int> _loadingTranslations = <int>{};
  final Map<int, _SelectedDictionaryWord> _selectedWords =
      <int, _SelectedDictionaryWord>{};

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
        final articleSections = _resolveArticleSections(
          seed,
          ref.watch(studentReadingSectionsProvider(reading.id)).valueOrNull,
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
                focusModeEnabled: _focusModeEnabled,
                revealedTranslations: _revealedTranslations,
                loadingTranslations: _loadingTranslations,
                selectedWords: _selectedWords,
                translationForSection: (lookupIndex) => ref
                    .read(studentTranslationProvider.notifier)
                    .cachedTranslation(reading.id, lookupIndex),
                onWordTap: _handleWordTap,
                onWordLongPress: (section) =>
                    _toggleTranslation(readingId: reading.id, section: section),
              );
              final focusWordsPanel = _FocusWordsPanel(words: seed.focusWords);

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

class _SentenceToken {
  const _SentenceToken({required this.displayWord, required this.lookupQuery});

  final String displayWord;
  final String lookupQuery;

  bool get isLookupable => lookupQuery.isNotEmpty;
}

final RegExp _tokenPattern = RegExp(r'\S+');
final RegExp _edgePunctuationPattern = RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$');

List<_SentenceToken> _tokenizeSentence(String text) {
  return _tokenPattern
      .allMatches(text)
      .map((match) {
        final displayWord = match.group(0) ?? '';
        return _SentenceToken(
          displayWord: displayWord,
          lookupQuery: _normalizeDictionaryQuery(displayWord),
        );
      })
      .where((token) => token.displayWord.isNotEmpty)
      .toList(growable: false);
}

String _normalizeDictionaryQuery(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(_edgePunctuationPattern, '');
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
    required this.focusModeEnabled,
    required this.revealedTranslations,
    required this.loadingTranslations,
    required this.selectedWords,
    required this.translationForSection,
    required this.onWordTap,
    required this.onWordLongPress,
  });

  final String readingId;
  final String title;
  final List<_ReadingArticleSection> sections;
  final bool focusModeEnabled;
  final Set<int> revealedTranslations;
  final Set<int> loadingTranslations;
  final Map<int, _SelectedDictionaryWord> selectedWords;
  final String? Function(int lookupIndex) translationForSection;
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
      ],
    );
  }
}

class _InteractiveSentenceText extends StatelessWidget {
  const _InteractiveSentenceText({
    required this.sentence,
    required this.focusModeEnabled,
    required this.selectedWord,
    required this.onWordTap,
    required this.onWordLongPress,
  });

  final String sentence;
  final bool focusModeEnabled;
  final _SelectedDictionaryWord? selectedWord;
  final ValueChanged<_SentenceToken> onWordTap;
  final VoidCallback onWordLongPress;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(height: focusModeEnabled ? 1.9 : 1.6);
    final tokens = AppThemeTokens.of(context);
    final words = _tokenizeSentence(sentence);

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
            accentColor: tokens.accentSoft,
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
    required this.accentColor,
    required this.onTap,
    required this.onLongPress,
  });

  final _SentenceToken token;
  final TextStyle? textStyle;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? accentColor.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: token.isLookupable ? onTap : null,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(token.displayWord, style: textStyle),
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
  const _FocusWordsPanel({required this.words});

  final List<ReadingFocusWordSeed> words;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ODAK KELIMELER', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final word in words) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    word.meaning,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
        ],
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
