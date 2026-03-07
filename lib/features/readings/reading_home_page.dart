import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_ui_texts.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_page_container.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/pack.dart';
import '../../domain/entities/reading_passage.dart';
import '../../domain/entities/reading_resume_item.dart';
import '../../domain/repositories/reading_repository.dart';
import '../../domain/value_objects/paged_result.dart';
import '../../state/providers.dart';
import 'reading_detail_page.dart';
import 'reading_level_style.dart';
import 'reading_list_page.dart';
import 'widgets/reading_feed_grid.dart';
import 'widgets/reading_resume_card.dart';

enum ReadingHomeSegment {
  stories('Hikayeler'),
  news('Haber Akisi'),
  library('Kitapligim');

  const ReadingHomeSegment(this.label);
  final String label;
}

class ReadingHomePage extends ConsumerStatefulWidget {
  const ReadingHomePage({super.key});

  @override
  ConsumerState<ReadingHomePage> createState() => _ReadingHomePageState();
}

class _ReadingHomePageState extends ConsumerState<ReadingHomePage> {
  ReadingHomeSegment _segment = ReadingHomeSegment.stories;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Pack>> packsAsync = ref.watch(packListProvider);
    final AsyncValue<ReadingResumeItem?> resumeAsync = ref.watch(
      _latestResumeProvider,
    );
    final AsyncValue<PagedResult<ReadingPassage>> feedAsync = ref.watch(
      _readingFeedProvider(_segment),
    );

    return AppPageContainer(
      padding: EdgeInsets.zero,
      child: packsAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              AppShimmerCard(lineCount: 4),
              SizedBox(height: 10),
              AppShimmerCard(),
              SizedBox(height: 10),
              AppShimmerCard(lineCount: 2),
            ],
          ),
        ),
        error: (Object error, StackTrace stack) {
          return AppErrorState(
            title: TrUiTexts.readingPackLoadError,
            detail: error.toString(),
            onRetry: () => ref.invalidate(packListProvider),
          );
        },
        data: (List<Pack> packs) {
          if (packs.isEmpty) {
            return const AppEmptyState(
              title: TrUiTexts.readingPackEmptyTitle,
              message: TrUiTexts.readingPackEmptyMessage,
              icon: Icons.menu_book_outlined,
            );
          }

          final Pack primaryPack = packs.first;
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isDesktop = AppBreakpoints.isDesktopWidth(
                constraints.maxWidth,
              );
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(packListProvider);
                  ref.invalidate(_latestResumeProvider);
                  ref.invalidate(_readingFeedProvider(_segment));
                  await ref.read(packListProvider.future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: isDesktop
                      ? _buildDesktopSections(
                          context: context,
                          primaryPack: primaryPack,
                          resumeAsync: resumeAsync,
                          feedAsync: feedAsync,
                          packs: packs,
                        )
                      : _buildMobileSections(
                          context: context,
                          primaryPack: primaryPack,
                          resumeAsync: resumeAsync,
                          feedAsync: feedAsync,
                          packs: packs,
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildMobileSections({
    required BuildContext context,
    required Pack primaryPack,
    required AsyncValue<ReadingResumeItem?> resumeAsync,
    required AsyncValue<PagedResult<ReadingPassage>> feedAsync,
    required List<Pack> packs,
  }) {
    return <Widget>[
      _ReadingHeroCard(
        segment: _segment,
        onTap: () => _openList(context, primaryPack),
      ),
      const SizedBox(height: 10),
      _buildSegmentSelector(),
      const SizedBox(height: 12),
      _buildResumeCard(context, resumeAsync, packs),
      const SizedBox(height: 12),
      _buildSegmentContent(
        context: context,
        feedAsync: feedAsync,
        packs: packs,
      ),
    ];
  }

  List<Widget> _buildDesktopSections({
    required BuildContext context,
    required Pack primaryPack,
    required AsyncValue<ReadingResumeItem?> resumeAsync,
    required AsyncValue<PagedResult<ReadingPassage>> feedAsync,
    required List<Pack> packs,
  }) {
    return <Widget>[
      Row(
        key: const ValueKey<String>('reading-home-desktop-header'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 7,
            child: _ReadingHeroCard(
              segment: _segment,
              onTap: () => _openList(context, primaryPack),
              desktop: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: _buildResumeCard(
              context,
              resumeAsync,
              packs,
              desktop: true,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _buildSegmentSelector(),
      const SizedBox(height: 12),
      _buildSegmentContent(
        context: context,
        feedAsync: feedAsync,
        packs: packs,
        useGrid: true,
        desktopWidth: MediaQuery.sizeOf(context).width,
      ),
    ];
  }

  Widget _buildSegmentSelector() {
    return SegmentedButton<ReadingHomeSegment>(
      key: const ValueKey<String>('reading-home-segment-control'),
      showSelectedIcon: false,
      segments: ReadingHomeSegment.values
          .map(
            (ReadingHomeSegment segment) => ButtonSegment<ReadingHomeSegment>(
              value: segment,
              label: Text(segment.label),
            ),
          )
          .toList(growable: false),
      selected: <ReadingHomeSegment>{_segment},
      onSelectionChanged: (Set<ReadingHomeSegment> value) {
        setState(() {
          _segment = value.first;
        });
      },
    );
  }

  Widget _buildResumeCard(
    BuildContext context,
    AsyncValue<ReadingResumeItem?> resumeAsync,
    List<Pack> packs, {
    bool desktop = false,
  }) {
    return resumeAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => ReadingResumeCard.loading(desktop: desktop),
      error: (Object _, StackTrace __) => ReadingResumeCard.message(
        message: 'Okumaya devam bilgisi su an alinamadi.',
        desktop: desktop,
      ),
      data: (ReadingResumeItem? resume) {
        if (resume == null) {
          return ReadingResumeCard.message(
            message: 'Yarim kalan okuma bulunmuyor.',
            desktop: desktop,
          );
        }
        final Pack? pack = packs.cast<Pack?>().firstWhere(
              (Pack? item) => item?.id == resume.passage.packId,
              orElse: () => null,
            );
        if (pack == null) {
          return ReadingResumeCard.message(
            message: 'Devam okunmasi icin uygun paket bulunamadi.',
            desktop: desktop,
          );
        }
        return ReadingResumeCard.content(
          title: resume.passage.title,
          progressText: 'Ilerleme: ${resume.progress.lastIdx}',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReadingDetailPage(
                  passage: resume.passage,
                  pack: pack,
                  initialLastIdx: resume.progress.lastIdx,
                ),
              ),
            );
          },
          desktop: desktop,
        );
      },
    );
  }

  Widget _buildSegmentContent({
    required BuildContext context,
    required AsyncValue<PagedResult<ReadingPassage>> feedAsync,
    required List<Pack> packs,
    bool useGrid = false,
    double? desktopWidth,
  }) {
    return feedAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const AppShimmerCard(),
      error: (Object _, StackTrace __) =>
          _buildPackCards(context, packs, useGrid: useGrid),
      data: (PagedResult<ReadingPassage> page) {
        if (page.items.isEmpty) {
          if (_segment == ReadingHomeSegment.library) {
            return const AppEmptyState(
              title: 'Kitaplik bos',
              message: 'Yer imi ekledikce burada gorunecek.',
              icon: Icons.bookmark_outline,
            );
          }
          return _buildPackCards(context, packs, useGrid: useGrid);
        }

        final List<Widget> feedCards = page.items
            .map(
              (ReadingPassage passage) => _buildPassageCard(
                context: context,
                passage: passage,
                resolvedPack: _resolvePackForPassage(
                  packs: packs,
                  passage: passage,
                ),
              ),
            )
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSectionHeader(title: _segment.label),
            const SizedBox(height: 8),
            if (useGrid)
              ReadingFeedGrid(
                crossAxisCount: _desktopFeedColumns(desktopWidth),
                mainAxisExtent: _desktopFeedExtent(desktopWidth),
                children: feedCards,
              )
            else
              Column(
                key: const ValueKey<String>('reading-feed-list'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: feedCards
                    .map(
                      (Widget card) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: card,
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        );
      },
    );
  }

  int _desktopFeedColumns(double? width) {
    if (width == null) {
      return 2;
    }
    if (width >= 1680) {
      return 4;
    }
    if (width >= 1280) {
      return 3;
    }
    return 2;
  }

  double _desktopFeedExtent(double? width) {
    if (width == null) {
      return 164;
    }
    if (width >= 1680) {
      return 164;
    }
    if (width >= 1280) {
      return 170;
    }
    return 164;
  }

  Pack _resolvePackForPassage({
    required List<Pack> packs,
    required ReadingPassage passage,
  }) {
    final String targetPackId = (passage.packId ?? '').trim();
    if (targetPackId.isEmpty) {
      return packs.first;
    }
    for (final Pack pack in packs) {
      if (pack.id == targetPackId) {
        return pack;
      }
    }
    return packs.first;
  }

  Widget _buildPackCards(
    BuildContext context,
    List<Pack> packs, {
    bool useGrid = false,
  }) {
    final List<Widget> packCards = packs
        .map((Pack pack) => _buildPackCard(context, pack))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppSectionHeader(title: 'Okuma Paketleri'),
        const SizedBox(height: 8),
        if (useGrid)
          ReadingFeedGrid(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 1280 ? 3 : 2,
            mainAxisExtent: 112,
            children: packCards,
          )
        else
          Column(
            key: const ValueKey<String>('reading-feed-list'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: packCards
                .map(
                  (Widget card) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: card,
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildPassageCard({
    required BuildContext context,
    required ReadingPassage passage,
    required Pack resolvedPack,
  }) {
    return SizedBox(
      width: double.infinity,
      child: AppSurfaceCard(
        key: ValueKey<String>('reading-feed-card-${passage.id}'),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ReadingDetailPage(
                passage: passage,
                pack: resolvedPack,
              ),
            ),
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool hasBoundedHeight = constraints.hasBoundedHeight;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    passage.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if ((passage.level ?? '').trim().isNotEmpty)
                        _ReadingMetaBadge.level(
                          level: (passage.level ?? '').trim(),
                        ),
                      if ((passage.category ?? '').trim().isNotEmpty)
                        _ReadingMetaBadge.category(
                          context: context,
                          label: (passage.category ?? '').trim(),
                        ),
                    ],
                  ),
                  if (hasBoundedHeight)
                    const Spacer()
                  else
                    const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Parcayi Ac',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPackCard(BuildContext context, Pack pack) {
    return SizedBox(
      width: double.infinity,
      child: AppSurfaceCard(
        onTap: () => _openList(context, pack),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    pack.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              pack.wordCount > 0
                  ? TrUiTexts.packWordCount(pack.wordCount)
                  : TrUiTexts.packOnlyReading,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _openList(BuildContext context, Pack pack) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadingListPage(pack: pack),
      ),
    );
  }
}

class _ReadingHeroCard extends StatelessWidget {
  const _ReadingHeroCard({
    required this.segment,
    required this.onTap,
    this.desktop = false,
  });

  final ReadingHomeSegment segment;
  final VoidCallback onTap;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      variant: AppSurfaceVariant.feature,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: desktop ? 148 : 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: desktop
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.start,
          children: <Widget>[
            Text(
              'Okuma Deneyimi',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${segment.label} modunda hizli bir oturum baslat.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: desktop ? 220 : double.infinity,
                child: AppGradientCtaButton(
                  onTap: onTap,
                  icon: Icons.chrome_reader_mode_outlined,
                  label: 'Okumaya Basla',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingMetaBadge extends StatelessWidget {
  const _ReadingMetaBadge._({
    required this.child,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  factory _ReadingMetaBadge.level({
    required String level,
  }) {
    return _ReadingMetaBadge._(
      backgroundColor: Colors.transparent,
      foregroundColor: ReadingLevelStyle.foreground(level),
      child: Text(level.toUpperCase()),
    );
  }

  factory _ReadingMetaBadge.category({
    required BuildContext context,
    required String label,
  }) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return _ReadingMetaBadge._(
      backgroundColor: colorScheme.surfaceContainerLowest,
      foregroundColor: colorScheme.onSurfaceVariant,
      child: Text(label),
    );
  }

  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final bool isLevelBadge = backgroundColor == Colors.transparent;
    final String? label = child is Text ? (child as Text).data : null;
    final Color fillColor = isLevelBadge
        ? ReadingLevelStyle.background(context, label)
        : backgroundColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLevelBadge
              ? foregroundColor.withValues(alpha: 0.35)
              : Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.75),
        ),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
        child: child,
      ),
    );
  }
}

final FutureProvider<ReadingResumeItem?> _latestResumeProvider =
    FutureProvider<ReadingResumeItem?>((Ref ref) async {
  final ReadingRepository repository = ref.watch(readingRepositoryProvider);
  return repository.getLatestIncompleteReading();
});

final _readingFeedProvider =
    FutureProvider.family<PagedResult<ReadingPassage>, ReadingHomeSegment>(
  (Ref ref, ReadingHomeSegment segment) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    if (segment == ReadingHomeSegment.library) {
      return repository.getBookmarkedPassages(limit: 20, offset: 0);
    }
    if (segment == ReadingHomeSegment.news) {
      return repository.getReadingFeed(
        category: 'news',
        limit: 20,
        offset: 0,
      );
    }
    return repository.getReadingFeed(limit: 20, offset: 0);
  },
);
