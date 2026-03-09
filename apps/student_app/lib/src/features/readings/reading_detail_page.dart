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
            body: const StudentSurfaceCard(child: Text('Okuma bulunamadı.')),
          );
        }

        final seed = readingSeedFor(reading.id);
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
                _showSnackBar('Paylaşım sonraki fazda etkinleşecek.'),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= AppBreakpoints.desktop;
              final infoPanel = _ReadingInfoPanel(
                reading: reading,
                seed: seed,
                focusModeEnabled: _focusModeEnabled,
                onToggleFocusMode: () {
                  setState(() {
                    _focusModeEnabled = !_focusModeEnabled;
                  });
                },
              );
              final articlePanel = _ReadingArticlePanel(
                reading: reading,
                seed: seed,
                focusModeEnabled: _focusModeEnabled,
                revealedTranslations: _revealedTranslations,
                loadingTranslations: _loadingTranslations,
                translationForSection: (index) => ref
                    .read(studentTranslationProvider.notifier)
                    .cachedTranslation(reading.id, index),
                onToggleTranslation: (index) => _toggleTranslation(
                  readingId: reading.id,
                  sectionIndex: index,
                  sourceText: seed.sections[index].body,
                ),
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
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('$error'))),
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
      _showSnackBar('Yer imi durumu güncellendi.');
    }
  }

  Future<void> _toggleFavorite(String readingId) async {
    await ref
        .read(studentReadingEngagementProvider.notifier)
        .toggleFavorite(readingId);
    if (mounted) {
      _showSnackBar('Favori durumu güncellendi.');
    }
  }

  Future<void> _toggleTranslation({
    required String readingId,
    required int sectionIndex,
    required String sourceText,
  }) async {
    if (_revealedTranslations.contains(sectionIndex)) {
      setState(() {
        _revealedTranslations.remove(sectionIndex);
      });
      return;
    }

    final controller = ref.read(studentTranslationProvider.notifier);
    final cached = controller.cachedTranslation(readingId, sectionIndex);
    if (cached != null) {
      setState(() {
        _revealedTranslations.add(sectionIndex);
      });
      return;
    }

    setState(() {
      _loadingTranslations.add(sectionIndex);
    });
    await controller.loadTranslation(
      readingId: readingId,
      sectionIndex: sectionIndex,
      sourceText: sourceText,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingTranslations.remove(sectionIndex);
      _revealedTranslations.add(sectionIndex);
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
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
            label: const Text('Geri Dön'),
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
    required this.focusModeEnabled,
    required this.onToggleFocusMode,
  });

  final ReadingPassage reading;
  final ReadingSeedData seed;
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
          const SizedBox(height: 10),
          Text(
            seed.summary,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: 16),
          _MetaPill(label: 'Yazar', value: seed.author),
          const SizedBox(height: 10),
          _MetaPill(label: 'Süre', value: '${seed.durationMinutes} dk'),
          const SizedBox(height: 10),
          _MetaPill(label: 'İlerleme', value: '%${seed.progressPercent}'),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: focusModeEnabled,
            onChanged: (_) => onToggleFocusMode(),
            title: const Text('Odak modu'),
            subtitle: const Text('Dikkat dağıtan bölümleri azalt.'),
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

class _ReadingArticlePanel extends StatelessWidget {
  const _ReadingArticlePanel({
    required this.reading,
    required this.seed,
    required this.focusModeEnabled,
    required this.revealedTranslations,
    required this.loadingTranslations,
    required this.translationForSection,
    required this.onToggleTranslation,
  });

  final ReadingPassage reading;
  final ReadingSeedData seed;
  final bool focusModeEnabled;
  final Set<int> revealedTranslations;
  final Set<int> loadingTranslations;
  final String? Function(int sectionIndex) translationForSection;
  final ValueChanged<int> onToggleTranslation;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reading.title,
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Okurken çeviri katmanını ihtiyaç duyduğun bölümlerde aç. İkinci açılışta aynı bölüm önbellekten gelir.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < seed.sections.length; index++) ...[
          StudentSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (seed.sections[index].heading.isNotEmpty) ...[
                  Text(
                    seed.sections[index].heading,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  seed.sections[index].body,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: focusModeEnabled ? 1.9 : 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => onToggleTranslation(index),
                      icon: loadingTranslations.contains(index)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              revealedTranslations.contains(index)
                                  ? Icons.translate_rounded
                                  : Icons.g_translate_rounded,
                            ),
                      label: Text(
                        revealedTranslations.contains(index)
                            ? 'Türkçe Çeviriyi Gizle'
                            : 'Türkçe Çeviriyi Göster',
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accentSoft.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('Bölüm ${index + 1}'),
                    ),
                  ],
                ),
                if (revealedTranslations.contains(index)) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.accentSoft.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      translationForSection(index) ?? 'Çeviri yüklenemedi.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
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

class _FocusWordsPanel extends StatelessWidget {
  const _FocusWordsPanel({required this.words});

  final List<ReadingFocusWordSeed> words;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ODAK KELİMELER', style: Theme.of(context).textTheme.titleLarge),
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
