import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_page_container.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_shimmer_block.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/grammar_module.dart';
import '../../domain/entities/grammar_page.dart';
import '../../state/providers.dart';
import 'grammar_reader_page.dart';

class GrammarModulePagesPage extends ConsumerWidget {
  const GrammarModulePagesPage({
    super.key,
    required this.module,
    this.initialPageId,
  });

  final GrammarModule module;
  final int? initialPageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<GrammarPage>> pagesAsync = ref.watch(
      grammarPagesProvider(module.id),
    );

    return Scaffold(
      appBar: AppBar(title: Text(module.baslik)),
      body: AppPageContainer(
        padding: EdgeInsets.zero,
        child: pagesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                AppShimmerCard(),
                SizedBox(height: 8),
                AppShimmerCard(),
                SizedBox(height: 8),
                AppShimmerCard(),
                SizedBox(height: 8),
                AppShimmerCard(),
              ],
            ),
          ),
          error: (Object error, StackTrace stackTrace) {
            final bool localMissing = _isLocalMissingError(error);
            return AppErrorState(
              title:
                  localMissing ? 'Lokal içerik yok' : 'Sayfalar yuklenemedi.',
              detail: localMissing
                  ? 'Bu modulun lokal sayfalari bulunamadi. İnternete baglanip tekrar deneyin.'
                  : error.toString(),
              onRetry: () => ref.invalidate(grammarPagesProvider(module.id)),
            );
          },
          data: (List<GrammarPage> pages) {
            if (pages.isEmpty) {
              return const AppEmptyState(
                title: 'Sayfa bulunamadi',
                message: 'Bu modulde listelenecek icerik yok.',
                icon: Icons.description_outlined,
              );
            }

            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isDesktop = AppBreakpoints.isDesktopWidth(
                  constraints.maxWidth,
                );
                return isDesktop
                    ? _buildDesktopBody(context, pages)
                    : _buildMobileBody(context, pages);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context, List<GrammarPage> pages) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: pages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final GrammarPage page = pages[index];
        final bool isResumePage =
            initialPageId != null && page.id == initialPageId;

        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${page.sayfaNo}')),
            title: Text(page.baslik),
            subtitle: Text('${page.kelimeSayisi} kelime'),
            trailing: isResumePage
                ? const Chip(label: Text('Son'))
                : const Icon(Icons.chevron_right_rounded),
            onTap: () => _openReader(context, pages, index),
          ),
        );
      },
    );
  }

  Widget _buildDesktopBody(BuildContext context, List<GrammarPage> pages) {
    final int totalWords = pages.fold<int>(
      0,
      (int sum, GrammarPage page) => sum + page.kelimeSayisi,
    );
    final int resumeIndex = initialPageId == null
        ? -1
        : pages.indexWhere((GrammarPage page) => page.id == initialPageId);

    return Row(
      key: const ValueKey<String>('grammar-module-pages-desktop-layout'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: AppSurfaceCard(
              variant: AppSurfaceVariant.feature,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    module.baslik,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${pages.length} sayfa · $totalWords kelime',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (resumeIndex >= 0) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Kaldigin sayfa',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${resumeIndex + 1}. ${pages[resumeIndex].baslik}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            itemCount: pages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final GrammarPage page = pages[index];
              final bool isResumePage =
                  initialPageId != null && page.id == initialPageId;

              return AppSurfaceCard(
                variant: AppSurfaceVariant.grouped,
                onTap: () => _openReader(context, pages, index),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(radius: 16, child: Text('${page.sayfaNo}')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            page.baslik,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${page.kelimeSayisi} kelime',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    isResumePage
                        ? const Chip(
                            label: Text('Son'),
                            visualDensity: VisualDensity.compact,
                          )
                        : const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openReader(BuildContext context, List<GrammarPage> pages, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GrammarReaderPage(
          module: module,
          pages: pages,
          initialIndex: index,
        ),
      ),
    );
  }

  bool _isLocalMissingError(Object error) {
    final String text = error.toString().toLowerCase();
    return text.contains('lokal gramer içerigi yok') ||
        text.contains('lokal icerik yok');
  }
}
