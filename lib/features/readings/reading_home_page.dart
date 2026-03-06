import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/tr_ui_texts.dart';
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

    return packsAsync.when(
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
            children: <Widget>[
              _ReadingHeroCard(
                segment: _segment,
                onTap: () => _openList(context, primaryPack),
              ),
              const SizedBox(height: 10),
              SegmentedButton<ReadingHomeSegment>(
                showSelectedIcon: false,
                segments: ReadingHomeSegment.values
                    .map(
                      (ReadingHomeSegment segment) =>
                          ButtonSegment<ReadingHomeSegment>(
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
              ),
              const SizedBox(height: 12),
              _buildResumeStrip(context, resumeAsync, packs),
              const SizedBox(height: 12),
              _buildSegmentContent(
                context: context,
                feedAsync: feedAsync,
                packs: packs,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResumeStrip(
    BuildContext context,
    AsyncValue<ReadingResumeItem?> resumeAsync,
    List<Pack> packs,
  ) {
    return AppSurfaceCard(
      child: resumeAsync.when(
        loading: () => const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (Object _, StackTrace __) => const Text(
          'Okumaya devam bilgisi su an alinamadi.',
        ),
        data: (ReadingResumeItem? resume) {
          if (resume == null) {
            return const Text('Yarim kalan okuma bulunmuyor.');
          }
          final Pack? pack = packs.cast<Pack?>().firstWhere(
                (Pack? item) => item?.id == resume.passage.packId,
                orElse: () => null,
              );
          if (pack == null) {
            return const Text('Devam okunmasi icin uygun paket bulunamadi.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppSectionHeader(title: 'Okumaya Devam Et'),
              const SizedBox(height: 6),
              Text(
                resume.passage.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text('Ilerleme: ${resume.progress.lastIdx}'),
              const SizedBox(height: 8),
              AppGradientCtaButton(
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
                icon: Icons.play_arrow_rounded,
                label: 'Devam Et',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSegmentContent({
    required BuildContext context,
    required AsyncValue<PagedResult<ReadingPassage>> feedAsync,
    required List<Pack> packs,
  }) {
    return feedAsync.when(
      loading: () => const AppShimmerCard(),
      error: (Object _, StackTrace __) => _buildPackCards(context, packs),
      data: (PagedResult<ReadingPassage> page) {
        if (page.items.isEmpty) {
          if (_segment == ReadingHomeSegment.library) {
            return const AppEmptyState(
              title: 'Kitaplik bos',
              message: 'Yer imi ekledikce burada gorunecek.',
              icon: Icons.bookmark_outline,
            );
          }
          return _buildPackCards(context, packs);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppSectionHeader(title: _segment.label),
            const SizedBox(height: 8),
            ...page.items.map((ReadingPassage passage) {
              final Pack resolvedPack = _resolvePackForPassage(
                packs: packs,
                passage: passage,
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            passage.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
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
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
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

  Widget _buildPackCards(BuildContext context, List<Pack> packs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppSectionHeader(title: 'Okuma Paketleri'),
        const SizedBox(height: 8),
        ...packs.map(
          (Pack pack) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
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
  });

  final ReadingHomeSegment segment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          AppGradientCtaButton(
            onTap: onTap,
            icon: Icons.chrome_reader_mode_outlined,
            label: 'Okumaya Basla',
          ),
        ],
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
