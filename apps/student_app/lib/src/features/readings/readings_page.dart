import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import 'reading_artwork.dart';
import 'reading_seed_data.dart';

enum ReadingCollectionView { library, discover }

class StudentReadingsPage extends ConsumerStatefulWidget {
  const StudentReadingsPage({super.key});

  @override
  ConsumerState<StudentReadingsPage> createState() =>
      _StudentReadingsPageState();
}

class _StudentReadingsPageState extends ConsumerState<StudentReadingsPage> {
  final searchController = TextEditingController();
  ReadingCollectionView selectedView = ReadingCollectionView.library;
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final readings = ref.watch(studentReadingsProvider);

    return StudentShellFrame(
      destination: StudentDestination.readings,
      title: 'Okuma Odası',
      subtitle: 'İngilizce metinler okuyarak anlama becerini geliştir.',
      accessContext: accessContext,
      headerAction: SizedBox(
        width: 280,
        child: StudentSearchField(
          controller: searchController,
          hintText: 'Makale, hikâye ara...',
          onChanged: (value) {
            setState(() {
              query = value.trim();
            });
          },
        ),
      ),
      body: readings.when(
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= AppBreakpoints.studentReadingsWide;
            final visibleItems = _visibleReadings(items);
            final columns = constraints.maxWidth >= AppBreakpoints.desktopWide
                ? 3
                : constraints.maxWidth >= AppBreakpoints.mobileWide
                ? 2
                : 1;
            final spacing = isWide ? 22.0 : 16.0;
            final itemWidth =
                (constraints.maxWidth - (spacing * (columns - 1))) / columns;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isWide) ...[
                  StudentSearchField(
                    controller: searchController,
                    hintText: 'Makale, hikâye ara...',
                    onChanged: (value) {
                      setState(() {
                        query = value.trim();
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                ],
                _ReadingToggle(
                  selectedView: selectedView,
                  onSelectionChanged: (value) {
                    setState(() {
                      selectedView = value;
                    });
                  },
                ),
                const SizedBox(height: 28),
                if (visibleItems.isEmpty)
                  const StudentSurfaceCard(
                    child: Text('Aramana uygun okuma bulunamadı.'),
                  )
                else
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final item in visibleItems)
                        SizedBox(
                          width: itemWidth,
                          child: _ReadingCard(
                            reading: item,
                            seed: readingSeedFor(item.id),
                            onTap: () => context.go('/readings/${item.id}'),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(error.toString()),
      ),
    );
  }

  List<ReadingPassage> _visibleReadings(List<ReadingPassage> items) {
    final normalizedQuery = query.toLowerCase();
    final filtered = items
        .where((item) {
          final seed = readingSeedFor(item.id);
          final displaySummary =
              (item.summary?.isNotEmpty ?? false) ? item.summary : seed.summary;
          final haystack =
              '${item.title} ${item.category ?? ''} ${item.level ?? ''} $displaySummary'
                  .toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: false);

    if (selectedView == ReadingCollectionView.discover) {
      final discoverItems = filtered
          .where((item) {
            return readingSeedFor(item.id).progressPercent < 100;
          })
          .toList(growable: false);
      discoverItems.sort(
        (left, right) => readingSeedFor(
          left.id,
        ).progressPercent.compareTo(readingSeedFor(right.id).progressPercent),
      );
      return discoverItems;
    }

    return filtered;
  }
}

class _ReadingToggle extends StatelessWidget {
  const _ReadingToggle({
    required this.selectedView,
    required this.onSelectionChanged,
  });

  final ReadingCollectionView selectedView;
  final ValueChanged<ReadingCollectionView> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ReadingCollectionView>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ReadingCollectionView.library,
          label: Text('Okuma Listem'),
        ),
        ButtonSegment(
          value: ReadingCollectionView.discover,
          label: Text('Keşfet'),
        ),
      ],
      selected: <ReadingCollectionView>{selectedView},
      onSelectionChanged: (selection) {
        onSelectionChanged(selection.first);
      },
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.reading,
    required this.seed,
    required this.onTap,
  });

  final ReadingPassage reading;
  final ReadingSeedData seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      padding: EdgeInsets.zero,
      minHeight: 520,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ReadingArtwork(
                seed: seed,
                height: 220,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Row(
                  children: [
                    _CardChip(
                      label: reading.level ?? '-',
                      backgroundColor: seed.levelBadgeColor.withValues(
                        alpha: 0.14,
                      ),
                      foregroundColor: seed.levelBadgeColor,
                    ),
                    const SizedBox(width: 8),
                    _CardChip(
                      label: '${seed.durationMinutes} dk',
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      foregroundColor: tokens.secondaryText,
                      icon: Icons.schedule_rounded,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading.title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(height: 1.15),
                ),
                const SizedBox(height: 12),
                Text(
                  (reading.summary?.isNotEmpty ?? false)
                      ? reading.summary!
                      : seed.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: tokens.secondaryText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                if (seed.isCompleted)
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: tokens.success,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tamamlandı',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: tokens.success),
                      ),
                    ],
                  )
                else if (seed.progressPercent == 0)
                  Text(
                    'Okumaya Başla →',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: tokens.accent),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'İLERLEME',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: tokens.secondaryText,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const Spacer(),
                          Text(
                            '${seed.progressPercent}%',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StudentProgressBar(
                        value: seed.progressPercent / 100,
                        color: tokens.accent,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foregroundColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
