import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/raw_splitter.dart';
import '../../../core/utils/word_selection_utils.dart';
import '../../../domain/entities/dictionary_lookup_result.dart';
import '../../../core/widgets/app_gradient_cta_button.dart';
import '../../../core/widgets/app_surface_card.dart';
import '../../../domain/entities/pack.dart';
import '../../../domain/entities/word_item.dart';
import '../../../domain/repositories/dictionary_repository.dart';
import '../../../domain/repositories/word_repository.dart';
import '../../../state/providers.dart';
import '../../../core/widgets/app_speak_button.dart';
import '../../flashcard/flashcard_session_page.dart';
import '../../words/widgets/dictionary_fallback_sheet.dart';
import '../../words/word_detail_page.dart';

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

  Future<void> _openRelatedWord(
    BuildContext context,
    WidgetRef ref,
    String rawWord,
    WordItem currentWord,
  ) async {
    final String normalized = normalizeWordToken(rawWord);
    if (normalized.isEmpty) {
      return;
    }

    final WordRepository wordRepository = ref.read(wordRepositoryProvider);
    final WordItem? target =
        await wordRepository.getWordByEnWordGlobal(normalized);

    if (!context.mounted) {
      return;
    }

    if (target != null) {
      if (target.id == currentWord.id) {
        return;
      }
      Navigator.of(context).pop();
      if (!hostContext.mounted) {
        return;
      }
      unawaited(Navigator.of(hostContext).push(
        MaterialPageRoute<void>(
          builder: (_) => WordDetailPage(word: target),
        ),
      ));
      return;
    }

    final DictionaryRepository dictionaryRepository =
        ref.read(dictionaryRepositoryProvider);
    final DictionaryLookupResult lookup =
        await dictionaryRepository.lookup(query: normalized);
    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DictionaryFallbackSheet(
        query: normalized,
        lookup: lookup,
      ),
    );
  }

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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
          minHeight: 260,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                normalized,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  AppSpeakButton(text: normalized),
                  OutlinedButton.icon(
                    onPressed: () => _copy(context, state, normalized),
                    icon: const Icon(Icons.copy),
                    label: const Text('Kopyala'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: const Text('Quick Word'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                  if ((state.sourceLabel ?? '').trim().isNotEmpty)
                    Chip(
                      label: Text(state.sourceLabel!.trim()),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: state.loading
                      ? const _LoadingContent()
                      : state.wordItem != null
                          ? _FoundWordContent(
                              hostContext: hostContext,
                              pack: pack,
                              word: state.wordItem!,
                              sourceLabel: state.sourceLabel,
                              onRelatedWordTap: (String token) {
                                return _openRelatedWord(
                                  context,
                                  ref,
                                  token,
                                  state.wordItem!,
                                );
                              },
                            )
                          : (state.translatedText ?? '').trim().isNotEmpty
                              ? _TranslatedWordContent(
                                  translatedText: state.translatedText!,
                                  sourceLabel: state.sourceLabel,
                                )
                              : _ErrorContent(
                                  error:
                                      state.error ?? 'Ceviri su an alinamadi.',
                                  onRetry: controller.retry,
                                ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
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
    BuildContext context,
    WordQuickViewState state,
    String normalized,
  ) {
    final String value = state.wordItem != null
        ? '${state.wordItem!.enWord} - ${state.wordItem!.trMeaning}'
        : '$normalized - ${(state.translatedText ?? '').trim()}';
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopyalandi.')),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return const Padding(
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
    );
  }
}

class _FoundWordContent extends StatelessWidget {
  const _FoundWordContent({
    required this.hostContext,
    required this.pack,
    required this.word,
    required this.sourceLabel,
    required this.onRelatedWordTap,
  });

  final BuildContext hostContext;
  final Pack pack;
  final WordItem word;
  final String? sourceLabel;
  final Future<void> Function(String rawWord) onRelatedWordTap;

  @override
  Widget build(BuildContext context) {
    final List<String> synonyms = parseRawList(word.synonymsRaw);
    final List<String> antonyms = parseRawList(word.antonymsRaw);
    final List<String> tags = parseRawList(word.tagsRaw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (word.pos.trim().isNotEmpty) Chip(label: Text(word.pos)),
                  if ((word.level ?? '').trim().isNotEmpty)
                    Chip(
                      label: Text('Level ${(word.level ?? '').trim()}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if ((sourceLabel ?? '').trim().isNotEmpty)
                    Chip(
                      label: Text(sourceLabel!.trim()),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                word.trMeaning,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                'Example EN',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                word.exampleEn,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if ((word.exampleTr ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Example TR',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.exampleTr!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                const Text('Tags'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map((String e) => Chip(label: Text(e)))
                      .toList(growable: false),
                ),
              ],
              if ((word.notes ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  'Not',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(word.notes!.trim()),
              ],
            ],
          ),
        ),
        if (synonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text('Synonyms'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: synonyms
                .map(
                  (String e) => ActionChip(
                    label: Text(e),
                    onPressed: () => onRelatedWordTap(e),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        if (antonyms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          const Text('Antonyms'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: antonyms
                .map(
                  (String e) => ActionChip(
                    label: Text(e),
                    onPressed: () => onRelatedWordTap(e),
                  ),
                )
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 10),
        AppGradientCtaButton(
          onTap: () {
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
          icon: Icons.school,
          label: 'Flashcard\'da Calis',
        ),
      ],
    );
  }
}

class _TranslatedWordContent extends StatelessWidget {
  const _TranslatedWordContent({
    required this.translatedText,
    required this.sourceLabel,
  });

  final String translatedText;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Ceviri (otomatik)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if ((sourceLabel ?? '').trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Chip(
              label: Text(sourceLabel!.trim()),
              visualDensity: VisualDensity.compact,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            translatedText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
    return AppSurfaceCard(
      child: Column(
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
      ),
    );
  }
}
