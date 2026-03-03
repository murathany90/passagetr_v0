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
import '../flashcard/flashcard_session_page.dart';
import '../readings/reading_list_page.dart';
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
      loading: () => const AppLoadingBlock(message: 'Packler yukleniyor...'),
      error: (Object error, StackTrace stack) {
        return AppErrorState(
          title: 'Pack listesi yuklenemedi.',
          detail: error.toString(),
          onRetry: () => ref.invalidate(packListProvider),
        );
      },
      data: (List<Pack> packs) {
        if (packs.isEmpty) {
          return AppEmptyState(
            title: 'Henuz paket yok',
            message: hintText(),
            icon: Icons.menu_book_outlined,
            actionLabel: 'Yenile',
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
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        Chip(
                          label: Text('${pack.wordCount} kelime'),
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
                          'Pack hub ac',
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
      appBar: AppBar(
        title: const Text('Pack List'),
      ),
      body: body,
    );
  }

  String hintText() {
    return emptyHint ??
        'CSV import rehberini docs/supabase_csv_import.md dosyasindan takip edin.';
  }
}

class PackDetailPage extends StatelessWidget {
  const PackDetailPage({required this.pack, super.key});

  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pack.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AppSurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  pack.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
          ),
          const SizedBox(height: 16),
          const AppSectionHeader(title: 'Calisma Modlari'),
          const SizedBox(height: 8),
          AppGradientCtaButton(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FlashcardSessionPage(pack: pack),
                ),
              );
            },
            icon: Icons.school,
            label: 'Kelime Calis',
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReadingListPage(pack: pack),
                ),
              );
            },
            icon: const Icon(Icons.menu_book),
            label: const Text('Paragraf Calis'),
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
            label: const Text('Test'),
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

class WordStudyHubPage extends StatelessWidget {
  const WordStudyHubPage({required this.pack, super.key});

  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelime Calis')),
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
