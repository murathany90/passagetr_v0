import 'package:flutter/material.dart';
import 'package:shared_domain/shared_domain.dart';

import '../../../core/admin_console_models.dart';
import '../../common/admin_page_parts.dart';

class AiGenerationForm extends StatelessWidget {
  const AiGenerationForm({
    super.key,
    required this.topicController,
    required this.targetWordCountController,
    required this.focusWordCountController,
    required this.questionCountController,
    required this.extraInstructionsController,
    required this.cefrLevel,
    required this.provider,
    required this.model,
    required this.selectedPackId,
    required this.packs,
    required this.modelOptions,
    required this.isGenerating,
    required this.onCefrLevelChanged,
    required this.onProviderChanged,
    required this.onModelChanged,
    required this.onPackChanged,
    required this.onGenerate,
  });

  final TextEditingController topicController;
  final TextEditingController targetWordCountController;
  final TextEditingController focusWordCountController;
  final TextEditingController questionCountController;
  final TextEditingController extraInstructionsController;
  final String cefrLevel;
  final String provider;
  final String? model;
  final String? selectedPackId;
  final List<AdminPackRecord> packs;
  final List<String> modelOptions;
  final bool isGenerating;
  final ValueChanged<String> onCefrLevelChanged;
  final ValueChanged<String> onProviderChanged;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String?> onPackChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Generation Parametreleri',
      trailing: FilledButton.icon(
        onPressed: isGenerating ? null : onGenerate,
        icon: isGenerating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_outlined),
        label: Text(isGenerating ? 'Uretiliyor' : 'Generate'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('ai-topic-field'),
            controller: topicController,
            decoration: const InputDecoration(
              labelText: 'Topic',
              hintText: 'Ornek: Renewable energy in daily life',
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('ai-provider-dropdown'),
                  initialValue: provider,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Provider'),
                  items: const [
                    DropdownMenuItem(
                      value: adminAiProviderGemini,
                      child: Text('Gemini'),
                    ),
                    DropdownMenuItem(
                      value: adminAiProviderOpenRouter,
                      child: Text('OpenRouter'),
                    ),
                  ],
                  onChanged: isGenerating
                      ? null
                      : (value) {
                          if (value != null) {
                            onProviderChanged(value);
                          }
                        },
                ),
              ),
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('ai-model-dropdown-$provider'),
                  initialValue: model,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Model'),
                  items: [
                    for (final item in modelOptions)
                      DropdownMenuItem(
                        value: item,
                        child: Text(adminAiModelLabel(item)),
                      ),
                  ],
                  onChanged: isGenerating || modelOptions.length <= 1
                      ? null
                      : (value) {
                          if (value != null) {
                            onModelChanged(value);
                          }
                        },
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('ai-pack-dropdown-${selectedPackId ?? 'none'}'),
                  initialValue: selectedPackId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pack'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Generate icin opsiyonel'),
                    ),
                    for (final pack in packs)
                      DropdownMenuItem<String?>(
                        value: pack.id,
                        child: Text(pack.name),
                      ),
                  ],
                  onChanged: isGenerating ? null : onPackChanged,
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('ai-cefr-dropdown'),
                  initialValue: cefrLevel,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'CEFR'),
                  items: const [
                    DropdownMenuItem(value: 'A1', child: Text('A1')),
                    DropdownMenuItem(value: 'A2', child: Text('A2')),
                    DropdownMenuItem(value: 'B1', child: Text('B1')),
                    DropdownMenuItem(value: 'B2', child: Text('B2')),
                    DropdownMenuItem(value: 'C1', child: Text('C1')),
                    DropdownMenuItem(value: 'C2', child: Text('C2')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onCefrLevelChanged(value);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  key: const ValueKey('ai-target-word-count-field'),
                  controller: targetWordCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target Words'),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  key: const ValueKey('ai-focus-word-count-field'),
                  controller: focusWordCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Focus Words'),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  key: const ValueKey('ai-question-count-field'),
                  controller: questionCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Questions'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: extraInstructionsController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Extra Instructions',
              hintText: 'Tone, specific vocabulary, or product notes.',
            ),
          ),
        ],
      ),
    );
  }
}
