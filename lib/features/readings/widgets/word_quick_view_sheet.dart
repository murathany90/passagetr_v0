import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/raw_splitter.dart';
import '../../../core/utils/word_selection_utils.dart';
import '../../../domain/entities/pack.dart';
import '../../../domain/entities/word_item.dart';
import '../../../state/providers.dart';
import '../../flashcard/flashcard_session_page.dart';

class WordQuickViewSheet extends ConsumerWidget {
  const WordQuickViewSheet({
    required this.hostContext,
    required this.pack,
    required this.selectedWord,
    super.key,
  });

  final BuildContext hostContext;
  final Pack pack;
  final String selectedWord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String normalized = normalizeSelectedWord(selectedWord);
    final WordQuickViewRequest request = WordQuickViewRequest(
      packId: pack.id,
      word: normalized,
    );
    final WordQuickViewState state = ref.watch(
      wordQuickViewControllerProvider(request),
    );
    final WordQuickViewController controller = ref.read(
      wordQuickViewControllerProvider(request).notifier,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              normalized,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (state.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Yukleniyor...'),
                  ],
                ),
              )
            else if (state.wordItem != null)
              _FoundWordContent(
                hostContext: hostContext,
                pack: pack,
                word: state.wordItem!,
              )
            else if ((state.translatedText ?? '').trim().isNotEmpty)
              _TranslatedWordContent(
                normalizedWord: normalized,
                translatedText: state.translatedText!,
              )
            else
              _ErrorContent(
                error: state.error ?? 'Ceviri su an alinamadi.',
                onRetry: controller.retry,
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _copy(context, state, normalized),
                  icon: const Icon(Icons.copy),
                  label: const Text('Kopyala'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openSource(context, normalized),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Kaynakta Ac'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(BuildContext context, String word) async {
    final Uri uri = buildCambridgeDictionaryUrl(word);
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaynak acilamadi.')),
      );
    }
  }

  void _copy(
      BuildContext context, WordQuickViewState state, String normalized) {
    final String value = state.wordItem != null
        ? '${state.wordItem!.enWord} - ${state.wordItem!.trMeaning}'
        : '$normalized - ${(state.translatedText ?? '').trim()}';
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopyalandi.')),
    );
  }
}

class _FoundWordContent extends StatelessWidget {
  const _FoundWordContent({
    required this.hostContext,
    required this.pack,
    required this.word,
  });

  final BuildContext hostContext;
  final Pack pack;
  final WordItem word;

  @override
  Widget build(BuildContext context) {
    final List<String> synonyms = parseRawList(word.synonymsRaw);
    final List<String> antonyms = parseRawList(word.antonymsRaw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Chip(label: Text(word.pos)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                word.trMeaning,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('EN: ${word.exampleEn}'),
        if ((word.exampleTr ?? '').trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text('TR: ${word.exampleTr}'),
        ],
        if (synonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const Text('Synonyms'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: synonyms
                .map((String e) => Chip(label: Text(e)))
                .toList(growable: false),
          ),
        ],
        if (antonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          const Text('Antonyms'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: antonyms
                .map((String e) => Chip(label: Text(e)))
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(hostContext).push(
              MaterialPageRoute<void>(
                builder: (_) => FlashcardSessionPage(
                  pack: pack,
                  customWordIds: <String>[word.id],
                  sessionLabel: 'Quick Word',
                ),
              ),
            );
          },
          icon: const Icon(Icons.school),
          label: const Text('Flashcard\'da Calis'),
        ),
      ],
    );
  }
}

class _TranslatedWordContent extends StatelessWidget {
  const _TranslatedWordContent({
    required this.normalizedWord,
    required this.translatedText,
  });

  final String normalizedWord;
  final String translatedText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          translatedText,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Ceviri (otomatik)',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          error,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
