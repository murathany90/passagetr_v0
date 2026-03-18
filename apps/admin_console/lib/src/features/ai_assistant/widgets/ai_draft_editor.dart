import 'package:flutter/material.dart';
import 'package:shared_domain/shared_domain.dart';

import '../../common/admin_page_parts.dart';

class AiDraftEditor extends StatelessWidget {
  const AiDraftEditor({
    super.key,
    required this.detail,
    required this.onChanged,
  });

  final AdminReadingDetail detail;
  final ValueChanged<AdminReadingDetail> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Draft Editor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: ValueKey('draft-title-${detail.title}'),
            initialValue: detail.title,
            decoration: const InputDecoration(labelText: 'Baslik'),
            onChanged: (value) => onChanged(detail.copyWith(title: value)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 160,
                child: TextFormField(
                  key: ValueKey('draft-level-${detail.level ?? ''}'),
                  initialValue: detail.level ?? '',
                  decoration: const InputDecoration(labelText: 'Seviye'),
                  onChanged: (value) => onChanged(
                    detail.copyWith(
                      level: value.trim(),
                      clearLevel: value.trim().isEmpty,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextFormField(
                  key: ValueKey('draft-category-${detail.category ?? ''}'),
                  initialValue: detail.category ?? '',
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  onChanged: (value) => onChanged(
                    detail.copyWith(
                      category: value.trim(),
                      clearCategory: value.trim().isEmpty,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextFormField(
                  key: ValueKey('draft-tags-${detail.tagsRaw ?? ''}'),
                  initialValue: detail.tagsRaw ?? '',
                  decoration: const InputDecoration(labelText: 'Tags Raw'),
                  onChanged: (value) => onChanged(
                    detail.copyWith(
                      tagsRaw: value.trim(),
                      clearTagsRaw: value.trim().isEmpty,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < detail.sentences.length; index++) ...[
            _SentenceEditorCard(
              index: index,
              sentence: detail.sentences[index],
              onChanged: (sentence) {
                final items = detail.sentences.toList(growable: true);
                items[index] = sentence;
                onChanged(detail.copyWith(sentences: _reindexSentences(items)));
              },
              onRemove: detail.sentences.length <= 1
                  ? null
                  : () {
                      final items = detail.sentences.toList(growable: true)
                        ..removeAt(index);
                      onChanged(
                        detail.copyWith(sentences: _reindexSentences(items)),
                      );
                    },
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () {
              final items = detail.sentences.toList(growable: true)
                ..add(
                  AdminReadingSentenceInput(
                    idx: detail.sentences.length + 1,
                    sentenceEn: '',
                  ),
                );
              onChanged(detail.copyWith(sentences: _reindexSentences(items)));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Cumle Ekle'),
          ),
        ],
      ),
    );
  }

  List<AdminReadingSentenceInput> _reindexSentences(
    List<AdminReadingSentenceInput> sentences,
  ) {
    return [
      for (var index = 0; index < sentences.length; index++)
        sentences[index].copyWith(idx: index + 1),
    ];
  }
}

class _SentenceEditorCard extends StatelessWidget {
  const _SentenceEditorCard({
    required this.index,
    required this.sentence,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final AdminReadingSentenceInput sentence;
  final ValueChanged<AdminReadingSentenceInput> onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Cumle ${index + 1}'),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          TextFormField(
            key: ValueKey('sentence-en-${sentence.idx}-${sentence.sentenceEn}'),
            initialValue: sentence.sentenceEn,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Sentence EN'),
            onChanged: (value) =>
                onChanged(sentence.copyWith(sentenceEn: value)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(
              'sentence-tr-${sentence.idx}-${sentence.sentenceTr ?? ''}',
            ),
            initialValue: sentence.sentenceTr ?? '',
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Sentence TR'),
            onChanged: (value) => onChanged(
              sentence.copyWith(
                sentenceTr: value,
                clearSentenceTr: value.trim().isEmpty,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
