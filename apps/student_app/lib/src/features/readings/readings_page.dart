import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../core/interaction_guard.dart';
import '../../core/student_providers.dart';
import '../common/page_parts.dart';
import 'reading_artwork.dart';
import 'reading_seed_data.dart';

enum ReadingCollectionView { all, saved, favorites }

class StudentReadingsPage extends ConsumerStatefulWidget {
  const StudentReadingsPage({super.key});

  @override
  ConsumerState<StudentReadingsPage> createState() =>
      _StudentReadingsPageState();
}

class _StudentReadingsPageState extends ConsumerState<StudentReadingsPage> {
  static const int _pageSize = 21;

  final searchController = TextEditingController();
  ReadingCollectionView selectedView = ReadingCollectionView.all;
  bool discoverOnly = false;
  String? selectedPackId;
  String query = '';
  int currentPage = 0;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(studentAccessProvider);
    final readings = ref.watch(studentReadingsProvider);
    final packs = ref.watch(studentPacksProvider);
    final engagementByPassage = ref.watch(studentReadingEngagementProvider);
    final canPersistEngagement = InteractionGuard.canPersist(accessContext);

    return StudentShellFrame(
      destination: StudentDestination.readings,
      title: 'Okuma Odasi',
      subtitle: 'Ingilizce metinler okuyarak anlama becerini gelistir.',
      accessContext: accessContext,
      headerAction: SizedBox(
        width: 280,
        child: StudentSearchField(
          controller: searchController,
          hintText: 'Makale, hikaye ara...',
          onChanged: _updateQuery,
        ),
      ),
      body: readings.when(
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
            final isWide =
                constraints.maxWidth >= AppBreakpoints.studentReadingsWide;
            final showAuthRequired =
                !canPersistEngagement &&
                selectedView != ReadingCollectionView.all;
            final packOptions = _packOptionsFor(
              items,
              packs.valueOrNull ?? const <ContentPack>[],
            );
            final resolvedSelectedPackId =
                packOptions.any((item) => item.id == selectedPackId)
                ? selectedPackId
                : null;
            final visibleItems = showAuthRequired
                ? const <ReadingPassage>[]
                : _visibleReadings(
                    items,
                    engagementByPassage,
                    selectedPackId: resolvedSelectedPackId,
                  );
            final columns = constraints.maxWidth >= AppBreakpoints.desktopWide
                ? 3
                : constraints.maxWidth >= AppBreakpoints.mobileWide
                ? 2
                : 1;
            final spacing = isWide ? 22.0 : 16.0;
            final totalPages = (visibleItems.length / _pageSize).ceil();
            final resolvedPage = totalPages == 0
                ? 0
                : currentPage.clamp(0, totalPages - 1);
            final pageItems = visibleItems
                .skip(resolvedPage * _pageSize)
                .take(_pageSize)
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isWide) ...[
                  StudentSearchField(
                    controller: searchController,
                    hintText: 'Makale, hikaye ara...',
                    onChanged: _updateQuery,
                  ),
                  const SizedBox(height: 18),
                ],
                _ReadingToggle(
                  selectedView: selectedView,
                  onSelectionChanged: (value) {
                    setState(() {
                      selectedView = value;
                      currentPage = 0;
                    });
                  },
                ),
                if (selectedView == ReadingCollectionView.all ||
                    packOptions.length > 1) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (selectedView == ReadingCollectionView.all)
                        FilterChip(
                          label: const Text('Kesfet'),
                          selected: discoverOnly,
                          onSelected: (value) {
                            setState(() {
                              discoverOnly = value;
                              currentPage = 0;
                            });
                          },
                        ),
                      if (packOptions.length > 1)
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 220,
                            maxWidth: 320,
                          ),
                          child: DropdownButtonFormField<String?>(
                            key: const ValueKey<String>(
                              'reading-pack-filter-dropdown',
                            ),
                            initialValue: resolvedSelectedPackId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Paket',
                            ),
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Tum Paketler'),
                              ),
                              ...packOptions.map(
                                (item) => DropdownMenuItem<String?>(
                                  value: item.id,
                                  child: Text(item.label),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedPackId = value;
                                currentPage = 0;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),
                if (showAuthRequired)
                  _ReadingsInfoCard(
                    title: selectedView == ReadingCollectionView.saved
                        ? 'Kayitlilar giris gerektirir'
                        : 'Favoriler giris gerektirir',
                    message:
                        'Tum okumalari gezebilirsin, ancak kisisel kayitlarin ve favorilerin icin giris yapman gerekir.',
                    actionLabel: 'Profile Git',
                    onAction: () => context.go('/profile'),
                  )
                else if (visibleItems.isEmpty)
                  _ReadingsInfoCard(
                    title: _emptyTitleForSelectedView(),
                    message: _emptyMessageForSelectedView(),
                  )
                else ...[
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: 580,
                    ),
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) {
                      final item = pageItems[index];
                      final isLocked =
                          item.isPro && !accessContext.canViewPremium;
                      return _ReadingCard(
                        reading: item,
                        seed: readingSeedForPassage(item),
                        isLocked: isLocked,
                        onTap: () => isLocked
                            ? context.go('/premium')
                            : context.go('/readings/${item.id}'),
                      );
                    },
                  ),
                  if (totalPages > 1) ...[
                    const SizedBox(height: 24),
                    _ReadingsPaginationBar(
                      currentPage: resolvedPage,
                      totalPages: totalPages,
                      pageSize: _pageSize,
                      totalItems: visibleItems.length,
                      onPrevious: resolvedPage == 0
                          ? null
                          : () {
                              setState(() {
                                currentPage = resolvedPage - 1;
                              });
                            },
                      onNext: resolvedPage >= totalPages - 1
                          ? null
                          : () {
                              setState(() {
                                currentPage = resolvedPage + 1;
                              });
                            },
                    ),
                  ],
                ],
              ],
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ReadingsStateCard(
          title: 'Okuma kutuphanesi simdi yuklenemiyor',
          message:
              'Baglanti tekrar geldiginde okumalar otomatik yenilenir. Bu ekrani yeniden acmayi dene.',
          onRetry: () => ref.invalidate(studentReadingsProvider),
        ),
      ),
    );
  }

  List<ReadingPassage> _visibleReadings(
    List<ReadingPassage> items,
    Map<String, ReadingEngagement> engagementByPassage, {
    String? selectedPackId,
  }) {
    final normalizedQuery = query.toLowerCase();
    final filteredByView = switch (selectedView) {
      ReadingCollectionView.all =>
        items
            .where(
              (item) =>
                  (selectedPackId == null || item.packId == selectedPackId) &&
                  (!discoverOnly ||
                      readingSeedForPassage(item).progressPercent < 100),
            )
            .toList(growable: false),
      ReadingCollectionView.saved =>
        items
            .where(
              (item) =>
                  (selectedPackId == null || item.packId == selectedPackId) &&
                  (engagementByPassage[item.id]?.isBookmarked ?? false),
            )
            .toList(growable: false),
      ReadingCollectionView.favorites =>
        items
            .where(
              (item) =>
                  (selectedPackId == null || item.packId == selectedPackId) &&
                  (engagementByPassage[item.id]?.isFavorite ?? false),
            )
            .toList(growable: false),
    };

    final visible = filteredByView
        .where((item) {
          final seed = readingSeedForPassage(item);
          final displaySummary = (item.summary?.isNotEmpty ?? false)
              ? item.summary
              : seed.summary;
          final haystack =
              '${item.title} ${item.category ?? ''} ${item.level ?? ''} $displaySummary'
                  .toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: false);

    switch (selectedView) {
      case ReadingCollectionView.all:
        if (discoverOnly) {
          visible.sort(
            (left, right) => readingSeedForPassage(left).progressPercent
                .compareTo(readingSeedForPassage(right).progressPercent),
          );
        }
        return visible;
      case ReadingCollectionView.saved:
        visible.sort(
          (left, right) => _compareEngagementTimestamp(
            engagementByPassage[right.id]?.bookmarkedAt,
            engagementByPassage[left.id]?.bookmarkedAt,
            left.title,
            right.title,
          ),
        );
        return visible;
      case ReadingCollectionView.favorites:
        visible.sort(
          (left, right) => _compareEngagementTimestamp(
            engagementByPassage[right.id]?.favoritedAt,
            engagementByPassage[left.id]?.favoritedAt,
            left.title,
            right.title,
          ),
        );
        return visible;
    }
  }

  int _compareEngagementTimestamp(
    DateTime? left,
    DateTime? right,
    String fallbackLeftTitle,
    String fallbackRightTitle,
  ) {
    final timestampComparison = (left?.millisecondsSinceEpoch ?? 0).compareTo(
      right?.millisecondsSinceEpoch ?? 0,
    );
    if (timestampComparison != 0) {
      return timestampComparison;
    }

    return fallbackLeftTitle.compareTo(fallbackRightTitle);
  }

  String _emptyTitleForSelectedView() {
    return switch (selectedView) {
      ReadingCollectionView.all => 'Aramana uygun okuma bulunamadi',
      ReadingCollectionView.saved => 'Kayitli okuma yok',
      ReadingCollectionView.favorites => 'Favori okuma yok',
    };
  }

  String _emptyMessageForSelectedView() {
    return switch (selectedView) {
      ReadingCollectionView.all =>
        'Arama metnini veya filtreleri degistirerek tekrar dene.',
      ReadingCollectionView.saved =>
        'Bir okumayi yer imlerine eklediginde burada goreceksin.',
      ReadingCollectionView.favorites =>
        'Begendigin okumalari favorilere eklediginde burada goreceksin.',
    };
  }

  void _updateQuery(String value) {
    setState(() {
      query = value.trim();
      currentPage = 0;
    });
  }

  List<_ReadingPackFilterOption> _packOptionsFor(
    List<ReadingPassage> readings,
    List<ContentPack> packs,
  ) {
    final packNames = <String, String>{
      for (final pack in packs)
        if (pack.id.trim().isNotEmpty) pack.id.trim(): pack.name.trim(),
    };
    final seen = <String>{};
    final options = <_ReadingPackFilterOption>[];
    for (final item in readings) {
      final packId = item.packId?.trim();
      if (packId == null || packId.isEmpty || !seen.add(packId)) {
        continue;
      }
      final label = packNames[packId];
      options.add(
        _ReadingPackFilterOption(
          id: packId,
          label: (label == null || label.isEmpty) ? packId : label,
        ),
      );
    }
    options.sort(
      (left, right) =>
          left.label.toLowerCase().compareTo(right.label.toLowerCase()),
    );
    return options;
  }
}

class _ReadingPackFilterOption {
  const _ReadingPackFilterOption({required this.id, required this.label});

  final String id;
  final String label;
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
          value: ReadingCollectionView.all,
          label: Text('Tum Okumalar'),
        ),
        ButtonSegment(
          value: ReadingCollectionView.saved,
          label: Text('Kayitlilar'),
        ),
        ButtonSegment(
          value: ReadingCollectionView.favorites,
          label: Text('Favoriler'),
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
    required this.isLocked,
    required this.onTap,
  });

  final ReadingPassage reading;
  final ReadingSeedData seed;
  final bool isLocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);

    return StudentSurfaceCard(
      padding: EdgeInsets.zero,
      minHeight: 520,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.max,
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
                    if (reading.isPro) ...[
                      _CardChip(
                        label: isLocked ? 'PRO KILITLI' : 'PRO',
                        backgroundColor: isLocked
                            ? tokens.warning.withValues(alpha: 0.14)
                            : tokens.accent.withValues(alpha: 0.14),
                        foregroundColor: isLocked
                            ? tokens.warning
                            : tokens.accent,
                        icon: isLocked
                            ? Icons.lock_outline_rounded
                            : Icons.workspace_premium_outlined,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _CardChip(
                      label: reading.level ?? '-',
                      backgroundColor: seed.levelBadgeColor.withValues(
                        alpha: 0.14,
                      ),
                      foregroundColor: seed.levelBadgeColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
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
                  Expanded(
                    child: Text(
                      _cardSummaryFor(reading, seed, isLocked),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (isLocked)
                    Text(
                      'Pro ile Ac',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: tokens.accent),
                    )
                  else if (seed.isCompleted)
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
                          'Tamamlandi',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: tokens.success),
                        ),
                      ],
                    )
                  else if (seed.progressPercent == 0)
                    Text(
                      'Okumaya Basla ->',
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
                              'ILERLEME',
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
          ),
        ],
      ),
    );
  }

  String _cardSummaryFor(
    ReadingPassage reading,
    ReadingSeedData seed,
    bool isLocked,
  ) {
    if (isLocked) {
      return 'Bu okuma listede gorunur; tam icerik icin Pro gerekir.';
    }

    final summary = reading.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }

    return seed.summary;
  }
}

class _ReadingsPaginationBar extends StatelessWidget {
  const _ReadingsPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final startIndex = (currentPage * pageSize) + 1;
    final endIndex = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return StudentSurfaceCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final controls = [
            OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Onceki'),
            ),
            const SizedBox(width: 10, height: 10),
            FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Sonraki'),
            ),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$startIndex-$endIndex / $totalItems okuma',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sayfa ${currentPage + 1} / $totalPages',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: controls),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Text(
                  '$startIndex-$endIndex / $totalItems okuma',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: tokens.secondaryText),
                ),
              ),
              Text(
                'Sayfa ${currentPage + 1} / $totalPages',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 16),
              ...controls,
            ],
          );
        },
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

class _ReadingsStateCard extends StatelessWidget {
  const _ReadingsStateCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

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
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Tekrar Dene'),
          ),
        ],
      ),
    );
  }
}

class _ReadingsInfoCard extends StatelessWidget {
  const _ReadingsInfoCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return StudentSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
