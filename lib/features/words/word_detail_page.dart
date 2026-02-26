import 'package:flutter/material.dart';

import '../../core/utils/raw_splitter.dart';
import '../../domain/entities/word_item.dart';

class WordDetailPage extends StatelessWidget {
  const WordDetailPage({required this.word, super.key});

  final WordItem word;

  @override
  Widget build(BuildContext context) {
    final List<String> synonyms = parseRawList(word.synonymsRaw);
    final List<String> antonyms = parseRawList(word.antonymsRaw);
    final List<String> tags = parseRawList(word.tagsRaw);

    return Scaffold(
      appBar: AppBar(title: Text(word.enWord)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(word.enWord, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Chip(label: Text(word.pos)),
          const SizedBox(height: 12),
          _DetailItem(title: 'TR Anlam', value: word.trMeaning),
          _DetailItem(title: 'EN Ornek', value: word.exampleEn),
          if ((word.exampleTr ?? '').trim().isNotEmpty)
            _DetailItem(title: 'TR Ornek', value: word.exampleTr!),
          if ((word.level ?? '').trim().isNotEmpty)
            _DetailItem(title: 'Seviye', value: word.level!),
          if ((word.notes ?? '').trim().isNotEmpty)
            _DetailItem(title: 'Not', value: word.notes!),
          if (synonyms.isNotEmpty)
            _ChipSection(title: 'Synonyms', values: synonyms),
          if (antonyms.isNotEmpty)
            _ChipSection(title: 'Antonyms', values: antonyms),
          if (tags.isNotEmpty) _ChipSection(title: 'Tags', values: tags),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({required this.title, required this.values});

  final String title;
  final List<String> values;

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
            children: values.map((String e) => Chip(label: Text(e))).toList(),
          ),
        ],
      ),
    );
  }
}
