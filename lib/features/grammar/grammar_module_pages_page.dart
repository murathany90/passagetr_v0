import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_state.dart';
import '../../core/widgets/app_shimmer_block.dart';
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
    final AsyncValue<List<GrammarPage>> pagesAsync =
        ref.watch(grammarPagesProvider(module.id));

    return Scaffold(
      appBar: AppBar(title: Text(module.baslik)),
      body: pagesAsync.when(
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
          return AppErrorState(
            title: 'Sayfalar yuklenemedi.',
            detail: error.toString(),
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final GrammarPage page = pages[index];
              final bool isResumePage = initialPageId != null && page.id == initialPageId;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${page.sayfaNo}'),
                  ),
                  title: Text(page.baslik),
                  subtitle: Text('${page.kelimeSayisi} kelime'),
                  trailing: isResumePage
                      ? const Chip(label: Text('Son'))
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GrammarReaderPage(
                          module: module,
                          pages: pages,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
