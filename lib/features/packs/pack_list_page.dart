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
import '../../state/providers.dart';
import '../flashcard/flashcard_session_page.dart';
import '../tests/test_hub_page.dart';
import '../words/word_list_page.dart';

class PackListPage extends ConsumerWidget {
  const PackListPage({
    super.key,
    this.embedded = false,
    this.onPackTap,
    this.emptyHint,
  });

  final bool embedded;
  final void Function(BuildContext context, Pack pack)? onPackTap;
  final String? emptyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Pack>> packsAsync = ref.watch(packListProvider);

    final Widget body = packsAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            AppShimmerCard(),
            SizedBox(height: 10),
            AppShimmerCard(lineCount: 2),
            SizedBox(height: 10),
            AppShimmerCard(),
          ],
        ),
      ),
      error: (Object error, StackTrace stack) {
        return AppErrorState(
          title: TrUiTexts.packListLoadError,
          detail: error.toString(),
          onRetry: () => ref.invalidate(packListProvider),
        );
      },
      data: (List<Pack> packs) {
        if (packs.isEmpty) {
          return AppEmptyState(
            title: TrUiTexts.packListEmptyTitle,
            message: hintText(),
            icon: Icons.menu_book_outlined,
            actionLabel: TrUiTexts.refresh,
            onAction: () => ref.invalidate(packListProvider),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(packListProvider);
            await ref.read(packListProvider.future);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemBuilder: (BuildContext context, int index) {
              final Pack pack = packs[index];

              return AppSurfaceCard(
                onTap: () {
                  if (onPackTap != null) {
                    onPackTap!(context, pack);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PackDetailPage(pack: pack),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            pack.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Chip(
                          label: Text(
                            pack.wordCount > 0
                                ? TrUiTexts.packWordCount(pack.wordCount)
                                : TrUiTexts.packOnlyReading,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${pack.fromLang.toUpperCase()} -> ${pack.toLang.toUpperCase()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          TrUiTexts.packOpenHubCta,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: packs.length,
          ),
        );
      },
    );

    if (embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text(TrUiTexts.packsAppBarTitle)),
      body: body,
    );
  }

  String hintText() {
    return emptyHint ?? TrUiTexts.csvImportHint;
  }
}

class PackDetailPage extends StatelessWidget {
  const PackDetailPage({required this.pack, super.key});

  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pack.name)),
      body: AppPageContainer(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isDesktop = AppBreakpoints.isDesktopWidth(
              constraints.maxWidth,
            );
            return isDesktop
                ? _buildDesktopBody(context)
                : _buildMobileBody(context);
          },
        ),
      ),
    );
  }

  Widget _buildMobileBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        _PackSummaryCard(pack: pack),
        const SizedBox(height: 16),
        const AppSectionHeader(title: TrUiTexts.packModesHeader),
        const SizedBox(height: 8),
        AppGradientCtaButton(
          onTap: () => _openFlashcard(context),
          icon: Icons.school,
          label: TrUiTexts.wordStudyCta,
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => _openTestHub(context),
          icon: const Icon(Icons.quiz),
          label: const Text('Test'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _openWordList(context),
          icon: const Icon(Icons.list),
          label: const Text('Kelime Listesi'),
        ),
      ],
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final bool hasWordContent = pack.wordCount > 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        key: const ValueKey<String>('pack-detail-desktop-layout'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _PackSummaryCard(pack: pack),
                const SizedBox(height: 12),
                AppSurfaceCard(
                  variant: AppSurfaceVariant.grouped,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Kisa Ozet',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasWordContent
                            ? 'Bu paket kelime calisma, test ve liste gorunumu icin hazir.'
                            : 'Bu paket agirlikli olarak okuma odakli icerik sunuyor.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppSectionHeader(title: TrUiTexts.packModesHeader),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final int columnCount = constraints.maxWidth >= 760 ? 3 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columnCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 156,
                      children: <Widget>[
                        _ModeActionCard(
                          title: TrUiTexts.wordStudyCta,
                          description: 'Flashcard ile hizli tekrar et.',
                          icon: Icons.school_rounded,
                          onTap: () => _openFlashcard(context),
                        ),
                        _ModeActionCard(
                          title: 'Test',
                          description: 'Test modlarina hizli gecis yap.',
                          icon: Icons.quiz_outlined,
                          onTap: () => _openTestHub(context),
                        ),
                        _ModeActionCard(
                          title: 'Kelime Listesi',
                          description: 'Tum kelimeleri yogun listede incele.',
                          icon: Icons.format_list_bulleted_rounded,
                          onTap: () => _openWordList(context),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: AppSurfaceCard(
                        variant: AppSurfaceVariant.grouped,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Icerik Ozeti',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            _CompactInfoRow(
                              label: 'Dil Yonu',
                              value:
                                  '${pack.fromLang.toUpperCase()} -> ${pack.toLang.toUpperCase()}',
                            ),
                            const SizedBox(height: 8),
                            _CompactInfoRow(
                              label: 'Icerik',
                              value: hasWordContent
                                  ? '${pack.wordCount} kelime'
                                  : 'Okuma odakli',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppSurfaceCard(
                        variant: AppSurfaceVariant.grouped,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Onerilen Akis',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              hasWordContent
                                  ? '1. Kelime Calis  2. Test  3. Liste'
                                  : '1. Kelime Listesi  2. Test',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
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

  void _openFlashcard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FlashcardSessionPage(pack: pack)),
    );
  }

  void _openTestHub(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => TestHubPage(pack: pack)));
  }

  void _openWordList(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => WordListPage(pack: pack)));
  }
}

class _PackSummaryCard extends StatelessWidget {
  const _PackSummaryCard({required this.pack});

  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            pack.name,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '${pack.wordCount} kelime - ${pack.fromLang.toUpperCase()} -> ${pack.toLang.toUpperCase()}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ModeActionCard extends StatelessWidget {
  const _ModeActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      variant: AppSurfaceVariant.grouped,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _CompactInfoRow extends StatelessWidget {
  const _CompactInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextStyle? labelStyle =
        Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            );
    final TextStyle? valueStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class WordStudyHubPage extends StatelessWidget {
  const WordStudyHubPage({required this.pack, super.key});

  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(TrUiTexts.wordStudyCta)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AppGradientCtaButton(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FlashcardSessionPage(pack: pack),
                ),
              );
            },
            icon: Icons.style,
            label: 'Flashcard',
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TestHubPage(pack: pack),
                ),
              );
            },
            icon: const Icon(Icons.quiz),
            label: const Text('Test Hub'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WordListPage(pack: pack),
                ),
              );
            },
            icon: const Icon(Icons.list),
            label: const Text('Kelime Listesi'),
          ),
        ],
      ),
    );
  }
}
