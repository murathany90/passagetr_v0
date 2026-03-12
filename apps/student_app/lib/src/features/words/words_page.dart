import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import 'student_word_card_sheet.dart';

enum WordCollectionView { all, favorites }

class StudentWordsPage extends ConsumerStatefulWidget {
  const StudentWordsPage({super.key});

  @override
  ConsumerState<StudentWordsPage> createState() => _StudentWordsPageState();
}

class _StudentWordsPageState extends ConsumerState<StudentWordsPage> {
  late final TextEditingController _searchController;
  String _query = '';
  WordCollectionView _selectedView = WordCollectionView.all;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final packProgress = ref.watch(studentPackProgressProvider);
    final wordSummary = ref.watch(studentWordSummaryProvider);
    final packs = ref.watch(studentPacksProvider);
    final words = ref.watch(studentWordsProvider);
    final favoriteByWord = ref.watch(studentWordFavoritesProvider);
    final isFavoritesView = _selectedView == WordCollectionView.favorites;
    final query = _query.trim().toLowerCase();

    return StudentShellFrame(
      destination: StudentDestination.words,
      title: 'Kelimeler',
      subtitle:
          'Kelime hazineni buyut, ardindan flashcard ve mini test ile pekistir.',
      accessContext: accessContext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudentSearchField(
            controller: _searchController,
            hintText: isFavoritesView
                ? 'Favori kelimelerde ara...'
                : 'Kelime havuzunda veya sozlukte ara...',
            onChanged: (value) {
              setState(() {
                _query = value;
              });
            },
          ),
          const SizedBox(height: 16),
          _WordCollectionSegmentedControl(
            selectedView: _selectedView,
            onSelectionChanged: (value) {
              setState(() {
                _selectedView = value;
              });
            },
          ),
          const SizedBox(height: 24),
          if (_selectedView == WordCollectionView.all) ...[
            _StudySummaryRow(summary: wordSummary),
            const SizedBox(height: 24),
            const StudentSectionTitle(title: 'Calisma Merkezi'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= AppBreakpoints.tablet;
                final flashcardCard = _StudyActionCard(
                  title: 'Flashcard Calismasi',
                  subtitle: 'Zayif kelimelerden baslayarak hizli tekrar yap.',
                  buttonLabel: 'Flashcard Ac',
                  icon: Icons.style_rounded,
                  accentColor: AppThemeTokens.of(context).accentBlue,
                  onPressed: () => context.go('/words/flashcards'),
                );
                final testCard = _StudyActionCard(
                  title: 'Mini Test',
                  subtitle: 'Kisa coktan secmeli tur ile ilerlemeyi olc.',
                  buttonLabel: 'Mini Test Baslat',
                  icon: Icons.quiz_outlined,
                  accentColor: AppThemeTokens.of(context).badgeOrange,
                  onPressed: () => context.go('/words/tests'),
                );

                if (!isWide) {
                  return Column(
                    children: [
                      flashcardCard,
                      const SizedBox(height: 14),
                      testCard,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: flashcardCard),
                    const SizedBox(width: 16),
                    Expanded(child: testCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            const StudentSectionTitle(title: 'Kelime Paketleri'),
            const SizedBox(height: 18),
            packs.when(
              data: (items) {
                final filtered = items
                    .where((item) => item.wordCount > 0)
                    .where((item) => item.name.toLowerCase().contains(query))
                    .toList(growable: false);

                if (filtered.isEmpty) {
                  return StudentSurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eslesen paket bulunamadi',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Arama filtresini temizleyip tekrar dene.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= AppBreakpoints.gridWide
                        ? 3
                        : constraints.maxWidth >= AppBreakpoints.small
                        ? 2
                        : 1;
                    final spacing = 18.0;
                    final itemWidth =
                        (constraints.maxWidth - ((columns - 1) * spacing)) /
                        columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (var index = 0; index < filtered.length; index++)
                          SizedBox(
                            width: itemWidth,
                            child: StudentPackCard(
                              title: filtered[index].name,
                              wordCount: filtered[index].wordCount,
                              progressPercent:
                                  packProgress[filtered[index].id] ?? 0,
                              accentColor: _packAccentColor(context, index),
                              onTap: () => context.go(
                                '/words/packs/${filtered[index].id}',
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
          ] else
            _buildFavoritesView(
              context: context,
              accessContext: accessContext,
              words: words,
              favoriteByWord: favoriteByWord,
              query: query,
            ),
        ],
      ),
    );
  }

  Widget _buildFavoritesView({
    required BuildContext context,
    required AccessContext accessContext,
    required AsyncValue<List<WordEntry>> words,
    required Map<String, WordFavorite> favoriteByWord,
    required String query,
  }) {
    if (!accessContext.hasIdentifiedProfile) {
      return _WordInfoCard(
        title: 'Favoriler giris gerektirir',
        message:
            'Tum kelimeleri gezebilirsin, ancak favori koleksiyonunu kaydetmek ve gormek icin giris yapman gerekir.',
        actionLabel: 'Profile Git',
        onAction: () => context.go('/profile'),
      );
    }

    return words.when(
      data: (items) {
        final filtered =
            items
                .where((item) => favoriteByWord[item.id]?.isFavorite ?? false)
                .where((item) {
                  if (query.isEmpty) {
                    return true;
                  }
                  return item.enWord.toLowerCase().contains(query) ||
                      item.trMeaning.toLowerCase().contains(query) ||
                      item.pos.toLowerCase().contains(query);
                })
                .toList(growable: false)
              ..sort((left, right) {
                final rightAt = favoriteByWord[right.id]?.favoritedAt;
                final leftAt = favoriteByWord[left.id]?.favoritedAt;
                final timeComparison = _compareNullableDates(rightAt, leftAt);
                if (timeComparison != 0) {
                  return timeComparison;
                }
                return left.enWord.toLowerCase().compareTo(
                  right.enWord.toLowerCase(),
                );
              });

        if (filtered.isEmpty) {
          return StudentSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  query.isEmpty
                      ? 'Favori kelime yok'
                      : 'Aramana uygun favori bulunamadi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  query.isEmpty
                      ? 'Kelime kartlarinda favori eklediklerin burada gorunecek.'
                      : 'Arama filtresini temizleyip tekrar dene.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudentSectionTitle(
              title: 'Favori Kelimeler',
              trailing: Text(
                '${filtered.length} kayit',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            for (final word in filtered) ...[
              _FavoriteWordRow(
                word: word,
                onTap: () =>
                    showStudentWordCardSheet(context, initialWord: word),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Text(error.toString()),
    );
  }

  int _compareNullableDates(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return -1;
    }
    if (right == null) {
      return 1;
    }
    return left.compareTo(right);
  }

  Color _packAccentColor(BuildContext context, int index) {
    final tokens = AppThemeTokens.of(context);
    final palette = <Color>[
      tokens.accentBlue,
      tokens.purple,
      tokens.green,
      tokens.warning,
      tokens.pink,
      const Color(0xFFA855F7),
    ];

    return palette[index % palette.length];
  }
}

class _WordCollectionSegmentedControl extends StatelessWidget {
  const _WordCollectionSegmentedControl({
    required this.selectedView,
    required this.onSelectionChanged,
  });

  final WordCollectionView selectedView;
  final ValueChanged<WordCollectionView> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<WordCollectionView>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<WordCollectionView>>[
        ButtonSegment<WordCollectionView>(
          value: WordCollectionView.all,
          label: Text('Tum Kelimeler'),
        ),
        ButtonSegment<WordCollectionView>(
          value: WordCollectionView.favorites,
          label: Text('Favoriler'),
        ),
      ],
      selected: <WordCollectionView>{selectedView},
      onSelectionChanged: (selection) {
        final value = selection.isEmpty ? null : selection.first;
        if (value != null) {
          onSelectionChanged(value);
        }
      },
    );
  }
}

class _FavoriteWordRow extends StatelessWidget {
  const _FavoriteWordRow({required this.word, required this.onTap});

  final WordEntry word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.enWord,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  word.trMeaning,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.surfaceMuted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(word.pos),
          ),
        ],
      ),
    );
  }
}

class _WordInfoCard extends StatelessWidget {
  const _WordInfoCard({
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

class _StudySummaryRow extends StatelessWidget {
  const _StudySummaryRow({required this.summary});

  final StudentWordSummary summary;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final items = <({String label, String value, Color color})>[
      (
        label: 'Calisilan',
        value: '${summary.studiedCount}',
        color: tokens.accentBlue,
      ),
      (label: 'Toplam', value: '${summary.totalCount}', color: tokens.accent),
      (
        label: 'Tekrar',
        value: '${summary.reviewCount}',
        color: tokens.badgeOrange,
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyLarge,
                children: [
                  TextSpan(
                    text: '${item.value} ',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: item.color),
                  ),
                  TextSpan(
                    text: item.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: tokens.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StudyActionCard extends StatelessWidget {
  const _StudyActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.icon,
    required this.accentColor,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
