import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/tr_ui_texts.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_state.dart';
import '../../../core/widgets/app_shimmer_block.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../domain/entities/pack.dart';
import '../../../state/providers.dart';
import '../../packs/pack_list_page.dart';

class WordPackListDesktop extends ConsumerWidget {
  const WordPackListDesktop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Pack>> packsAsync = ref.watch(packListProvider);

    return packsAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          key: ValueKey<String>('word-pack-list-desktop'),
          children: <Widget>[
            AppShimmerCard(),
            SizedBox(height: 10),
            AppShimmerCard(lineCount: 2),
            SizedBox(height: 10),
            AppShimmerCard(),
          ],
        ),
      ),
      error: (Object error, StackTrace stack) => AppErrorState(
        title: TrUiTexts.packListLoadError,
        detail: error.toString(),
        onRetry: () => ref.invalidate(packListProvider),
      ),
      data: (List<Pack> packs) {
        if (packs.isEmpty) {
          return AppEmptyState(
            title: TrUiTexts.packListEmptyTitle,
            message: TrUiTexts.csvImportHint,
            icon: Icons.menu_book_outlined,
            actionLabel: TrUiTexts.refresh,
            onAction: () => ref.invalidate(packListProvider),
          );
        }

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int crossAxisCount = constraints.maxWidth >= 1680
                ? 4
                : constraints.maxWidth >= 1320
                ? 3
                : 2;
            final double mainAxisExtent = constraints.maxWidth >= 1680
                ? 118
                : constraints.maxWidth >= 1320
                ? 122
                : 126;
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(packListProvider);
                await ref.read(packListProvider.future);
              },
              child: GridView.builder(
                key: const ValueKey<String>('word-pack-list-desktop'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: mainAxisExtent,
                ),
                itemCount: packs.length,
                itemBuilder: (BuildContext context, int index) {
                  final Pack pack = packs[index];
                  final String packCountLabel = pack.wordCount > 0
                      ? TrUiTexts.packWordCount(pack.wordCount)
                      : TrUiTexts.packOnlyReading;

                  return AppSurfaceCard(
                    key: ValueKey<String>('word-pack-card-${pack.id}'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PackDetailPage(pack: pack),
                        ),
                      );
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                pack.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Chip(
                              label: Text(packCountLabel),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${pack.fromLang.toUpperCase()} -> ${pack.toLang.toUpperCase()}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                        ),
                        const Spacer(),
                        Row(
                          children: <Widget>[
                            Text(
                              TrUiTexts.packOpenHubCta,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_outward_rounded,
                              color: Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
