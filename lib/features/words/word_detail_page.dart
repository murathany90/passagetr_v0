import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/raw_splitter.dart';
import '../../core/utils/word_selection_utils.dart';
import '../../domain/entities/dictionary_lookup_result.dart';
import '../../domain/entities/word_item.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../../domain/repositories/word_repository.dart';
import '../../state/providers.dart';
import '../../core/widgets/app_speak_button.dart';
import 'widgets/dictionary_fallback_sheet.dart';

class WordDetailPage extends ConsumerStatefulWidget {
  const WordDetailPage({required this.word, super.key});

  final WordItem word;

  @override
  ConsumerState<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends ConsumerState<WordDetailPage> {
  bool _resolvingRelatedWord = false;

  Future<void> _openRelatedWord(String rawWord) async {
    final String normalized = normalizeWordToken(rawWord);
    if (normalized.isEmpty || _resolvingRelatedWord) {
      return;
    }

    setState(() {
      _resolvingRelatedWord = true;
    });

    try {
      final WordRepository wordRepository = ref.read(wordRepositoryProvider);
      final WordItem? target =
          await wordRepository.getWordByEnWordGlobal(normalized);

      if (!mounted) {
        return;
      }

      if (target != null) {
        if (target.id == widget.word.id) {
          return;
        }
        unawaited(Navigator.of(context).push(
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

      if (!mounted) {
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
    } finally {
      if (mounted) {
        setState(() {
          _resolvingRelatedWord = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> synonyms = parseRawList(widget.word.synonymsRaw);
    final List<String> antonyms = parseRawList(widget.word.antonymsRaw);
    final List<String> tags = parseRawList(widget.word.tagsRaw);
    final String level = (widget.word.level ?? '').trim().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(widget.word.enWord)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        widget.word.enWord,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    AppSpeakButton(text: widget.word.enWord),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(label: Text(widget.word.pos)),
                    if (level.isNotEmpty) Chip(label: Text('Level $level')),
                    const Chip(label: Text('Kelime karti')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _DetailBlock(title: 'TR Anlam', value: widget.word.trMeaning),
          _DetailBlock(title: 'EN Ornek', value: widget.word.exampleEn),
          if ((widget.word.exampleTr ?? '').trim().isNotEmpty)
            _DetailBlock(title: 'TR Ornek', value: widget.word.exampleTr!),
          if ((widget.word.notes ?? '').trim().isNotEmpty)
            _DetailBlock(title: 'Not', value: widget.word.notes!),
          if (synonyms.isNotEmpty)
            _ChipSection(
              title: 'Synonyms',
              values: synonyms,
              onTap: _openRelatedWord,
            ),
          if (antonyms.isNotEmpty)
            _ChipSection(
              title: 'Antonyms',
              values: antonyms,
              onTap: _openRelatedWord,
            ),
          if (tags.isNotEmpty) _ChipSection(title: 'Tags', values: tags),
          if (_resolvingRelatedWord) ...<Widget>[
            const SizedBox(height: 6),
            const Row(
              children: <Widget>[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Iliskili kelime araniyor...'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(value),
          ],
        ),
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.values,
    this.onTap,
  });

  final String title;
  final List<String> values;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((String item) {
              if (onTap == null) {
                return Chip(label: Text(item));
              }
              return ActionChip(
                label: Text(item),
                onPressed: () => onTap!(item),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}
