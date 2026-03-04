import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_gradient_cta_button.dart';
import '../../core/widgets/app_loading_block.dart';
import '../../core/widgets/app_section_header.dart';
import '../../core/widgets/app_surface_card.dart';
import '../../domain/entities/pack.dart';
import '../../state/providers.dart';
import 'reading_list_page.dart';

class ReadingHomePage extends ConsumerWidget {
  const ReadingHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Pack>> packsAsync = ref.watch(packListProvider);

    return packsAsync.when(
      loading: () =>
          const AppLoadingBlock(message: 'Okuma paketleri yukleniyor...'),
      error: (Object error, StackTrace stack) {
        return AppErrorState(
          title: 'Okuma paketleri yuklenemedi.',
          detail: error.toString(),
          onRetry: () => ref.invalidate(packListProvider),
        );
      },
      data: (List<Pack> packs) {
        if (packs.isEmpty) {
          return const AppEmptyState(
            title: 'Okuma paketi bulunamadi',
            message:
                'Okuma paketleri icin docs/supabase_readings_import.md adimlarini takip edin.',
            icon: Icons.menu_book_outlined,
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
            itemCount: packs.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return _ReadingHeroCard(
                  packCount: packs.length,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReadingListPage(pack: packs.first),
                      ),
                    );
                  },
                );
              }

              final Pack pack = packs[index - 1];
              return AppSurfaceCard(
                onTap: () => _openReadingList(context, pack),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const AppSectionHeader(title: 'Okuma Paketi'),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            pack.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${pack.wordCount} kelime',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        Chip(
                          label: Text(
                            '${pack.fromLang.toUpperCase()} -> ${pack.toLang.toUpperCase()}',
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Chip(
                          label: Text('Reading'),
                          visualDensity: VisualDensity.compact,
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
  }

  void _openReadingList(BuildContext context, Pack pack) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadingListPage(pack: pack),
      ),
    );
  }
}

class _ReadingHeroCard extends StatelessWidget {
  const _ReadingHeroCard({
    required this.packCount,
    required this.onTap,
  });

  final int packCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Paragraf Calis',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '$packCount okuma paketi hazir. Cumle bazli calis ve ceviriyle pekistir.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          AppGradientCtaButton(
            onTap: onTap,
            icon: Icons.play_arrow_rounded,
            label: 'Okumaya Basla',
          ),
        ],
      ),
    );
  }
}
