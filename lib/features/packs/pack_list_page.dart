import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/pack.dart';
import '../../state/providers.dart';
import '../flashcard/flashcard_session_page.dart';
import '../readings/reading_list_page.dart';
import '../tests/test_hub_page.dart';
import '../words/word_list_page.dart';

class PackListPage extends ConsumerWidget {
  const PackListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Pack>> packsAsync = ref.watch(packListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pack List'),
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) {
          return _ErrorState(
            message: 'Pack listesi yuklenemedi.',
            detail: error.toString(),
            onRetry: () => ref.invalidate(packListProvider),
          );
        },
        data: (List<Pack> packs) {
          if (packs.isEmpty) {
            return _EmptyPackState(
              onRetry: () => ref.invalidate(packListProvider),
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
                return Card(
                  child: ListTile(
                    title: Text(pack.name),
                    subtitle: Text(
                      '${pack.wordCount} kelime - ${pack.fromLang.toUpperCase()} -> ${pack.toLang.toUpperCase()}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PackDetailPage(pack: pack),
                        ),
                      );
                    },
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: packs.length,
            ),
          );
        },
      ),
    );
  }
}

class PackDetailPage extends StatelessWidget {
  const PackDetailPage({required this.pack, super.key});

  final Pack pack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(pack.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '${pack.wordCount} kelime',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => WordStudyHubPage(pack: pack),
                  ),
                );
              },
              icon: const Icon(Icons.school),
              label: const Text('Kelime Calis'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
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
          ],
        ),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FlashcardSessionPage(pack: pack),
                  ),
                );
              },
              icon: const Icon(Icons.style),
              label: const Text('Flashcard'),
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
      ),
    );
  }
}

class _EmptyPackState extends StatelessWidget {
  const _EmptyPackState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'Henuz paket yok.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'CSV import rehberini docs/supabase_csv_import.md dosyasindan takip edin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(detail, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
