import 'package:flutter/material.dart';
import 'package:shared_domain/shared_domain.dart';

import '../../common/admin_page_parts.dart';

class AiQuestionsPanel extends StatelessWidget {
  const AiQuestionsPanel({
    super.key,
    required this.detail,
    required this.onChanged,
  });

  final AdminReadingDetail detail;
  final ValueChanged<AdminReadingDetail> onChanged;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Question Editor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < detail.questions.length; index++) ...[
            _QuestionCard(
              index: index,
              question: detail.questions[index],
              onChanged: (question) {
                final items = detail.questions.toList(growable: true);
                items[index] = question;
                onChanged(detail.copyWith(questions: _reindexQuestions(items)));
              },
              onRemove: detail.questions.length <= 1
                  ? null
                  : () {
                      final items = detail.questions.toList(growable: true)
                        ..removeAt(index);
                      onChanged(
                        detail.copyWith(questions: _reindexQuestions(items)),
                      );
                    },
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () {
              final items = detail.questions.toList(growable: true)
                ..add(
                  const AdminReadingQuestionInput(
                    sortOrder: 1,
                    question: '',
                    options: <String>['', ''],
                    correctOptionIndex: 0,
                  ),
                );
              onChanged(detail.copyWith(questions: _reindexQuestions(items)));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Soru Ekle'),
          ),
        ],
      ),
    );
  }

  List<AdminReadingQuestionInput> _reindexQuestions(
    List<AdminReadingQuestionInput> items,
  ) {
    return [
      for (var index = 0; index < items.length; index++)
        items[index].copyWith(sortOrder: index + 1),
    ];
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final AdminReadingQuestionInput question;
  final ValueChanged<AdminReadingQuestionInput> onChanged;
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
              Text('Soru ${index + 1}'),
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
            key: ValueKey(
              'question-text-${question.sortOrder}-${question.question}',
            ),
            initialValue: question.question,
            decoration: const InputDecoration(labelText: 'Question'),
            onChanged: (value) => onChanged(question.copyWith(question: value)),
          ),
          const SizedBox(height: 12),
          for (
            var optionIndex = 0;
            optionIndex < question.options.length;
            optionIndex++
          ) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey(
                      'question-option-${question.sortOrder}-$optionIndex-${question.options[optionIndex]}',
                    ),
                    initialValue: question.options[optionIndex],
                    decoration: InputDecoration(
                      labelText: 'Secenek ${optionIndex + 1}',
                    ),
                    onChanged: (value) {
                      final options = question.options.toList(growable: true);
                      options[optionIndex] = value;
                      onChanged(question.copyWith(options: options));
                    },
                  ),
                ),
                if (question.options.length > 2) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      final options = question.options.toList(growable: true)
                        ..removeAt(optionIndex);
                      final nextCorrectIndex =
                          question.correctOptionIndex >= options.length
                          ? options.length - 1
                          : question.correctOptionIndex;
                      onChanged(
                        question.copyWith(
                          options: options,
                          correctOptionIndex: nextCorrectIndex < 0
                              ? 0
                              : nextCorrectIndex,
                        ),
                      );
                    },
                    tooltip: 'Seçeneği sil',
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextButton.icon(
            onPressed: () {
              final options = question.options.toList(growable: true)..add('');
              onChanged(question.copyWith(options: options));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Secenek Ekle'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey(
              'question-correct-${question.sortOrder}-${question.correctOptionIndex}',
            ),
            initialValue: question.correctOptionIndex,
            decoration: const InputDecoration(labelText: 'Dogru Secenek'),
            items: [
              for (
                var optionIndex = 0;
                optionIndex < question.options.length;
                optionIndex++
              )
                DropdownMenuItem(
                  value: optionIndex,
                  child: Text('Secenek ${optionIndex + 1}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                onChanged(question.copyWith(correctOptionIndex: value));
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(
              'question-explanation-${question.sortOrder}-${question.explanation ?? ''}',
            ),
            initialValue: question.explanation ?? '',
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Explanation'),
            onChanged: (value) => onChanged(
              question.copyWith(
                explanation: value,
                clearExplanation: value.trim().isEmpty,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
