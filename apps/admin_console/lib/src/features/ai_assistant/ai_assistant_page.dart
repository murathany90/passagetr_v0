import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

import '../../core/admin_ai_assistant_controller.dart';
import '../../core/admin_console_models.dart';
import '../../core/admin_providers.dart';
import '../common/admin_page_parts.dart';
import '../content/widgets/reading_cover_panel.dart';
import 'widgets/ai_draft_editor.dart';
import 'widgets/ai_generation_form.dart';
import 'widgets/ai_linked_words_panel.dart';
import 'widgets/ai_publish_panel.dart';
import 'widgets/ai_questions_panel.dart';

class AdminAiAssistantPage extends ConsumerStatefulWidget {
  const AdminAiAssistantPage({super.key});

  @override
  ConsumerState<AdminAiAssistantPage> createState() =>
      _AdminAiAssistantPageState();
}

class _AdminAiAssistantPageState extends ConsumerState<AdminAiAssistantPage> {
  late final TextEditingController _topicController;
  late final TextEditingController _targetWordCountController;
  late final TextEditingController _focusWordCountController;
  late final TextEditingController _questionCountController;
  late final TextEditingController _extraInstructionsController;
  String _cefrLevel = 'B1';
  String _provider = adminAiProviderGemini;
  String? _model = adminAiGeminiDefaultModel;
  String? _selectedPackId;

  @override
  void initState() {
    super.initState();
    const request = AdminAiGenerateReadingRequest();
    _topicController = TextEditingController(text: request.topic);
    _targetWordCountController = TextEditingController(
      text: request.targetWordCount.toString(),
    );
    _focusWordCountController = TextEditingController(
      text: request.focusWordCount.toString(),
    );
    _questionCountController = TextEditingController(
      text: request.questionCount.toString(),
    );
    _extraInstructionsController = TextEditingController(
      text: request.extraInstructions ?? '',
    );
    _provider = request.provider;
    _model = request.model;
  }

  @override
  void dispose() {
    _topicController.dispose();
    _targetWordCountController.dispose();
    _focusWordCountController.dispose();
    _questionCountController.dispose();
    _extraInstructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessContext = ref.watch(adminAccessProvider);
    final state = ref.watch(adminAiAssistantControllerProvider);
    final packs = ref.watch(adminPacksProvider);
    final words = ref.watch(adminWordEntriesProvider);
    final packItems = packs.valueOrNull ?? const <AdminPackRecord>[];

    return AdminShellFrame(
      destination: AdminDestination.aiAssistant,
      title: 'AI Asistan',
      subtitle:
          'Reading-first AI draft uretimi, linked word cozumleme ve publish akisi.',
      accessContext: accessContext,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AiGenerationForm(
            topicController: _topicController,
            targetWordCountController: _targetWordCountController,
            focusWordCountController: _focusWordCountController,
            questionCountController: _questionCountController,
            extraInstructionsController: _extraInstructionsController,
            cefrLevel: _cefrLevel,
            provider: _provider,
            model: _model,
            selectedPackId: _selectedPackId,
            packs: packItems,
            modelOptions: adminAiModelsForProvider(_provider),
            isGenerating: state.status == AdminAiAssistantStatus.loading,
            onCefrLevelChanged: (value) {
              setState(() {
                _cefrLevel = value;
              });
            },
            onProviderChanged: (value) {
              setState(() {
                _provider = value;
                _model = adminAiDefaultModelForProvider(value);
              });
            },
            onModelChanged: (value) {
              setState(() {
                _model = value;
              });
            },
            onPackChanged: (value) {
              setState(() {
                _selectedPackId = value;
              });
              ref
                  .read(adminAiAssistantControllerProvider.notifier)
                  .updateSelectedPackId(
                    value,
                    wordCatalog: words.valueOrNull ?? const <AdminWordRecord>[],
                  );
            },
            onGenerate: _handleGenerate,
          ),
          const SizedBox(height: 18),
          if (state.errorMessage != null || state.noticeMessage != null) ...[
            _StatusBanner(
              message: state.errorMessage ?? state.noticeMessage ?? '',
              isError: state.errorMessage != null,
              onDismiss: () => ref
                  .read(adminAiAssistantControllerProvider.notifier)
                  .clearMessage(),
            ),
            const SizedBox(height: 18),
          ],
          if (state.editableDraft == null)
            const AdminEmptyState(
              title: 'Heniz AI draft yok',
              message:
                  'Parametreleri doldurup generate ettiginizde editable reading taslagi burada acilir.',
            )
          else
            packs.when(
              data: (packItems) => words.when(
                data: (_) => _buildEditorLayout(state: state, packs: packItems),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text(error.toString()),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(error.toString()),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorLayout({
    required AdminAiAssistantState state,
    required List<AdminPackRecord> packs,
  }) {
    final editableDraft = state.editableDraft!;
    final metadata =
        editableDraft.aiGenerationMeta ?? state.generatedDraft?.generationMeta;
    final selectedPackName = _packNameForId(packs, state.selectedPackId);

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiDraftEditor(
          detail: editableDraft,
          onChanged: (detail) => ref
              .read(adminAiAssistantControllerProvider.notifier)
              .replaceEditableDraft(detail),
        ),
        const SizedBox(height: 18),
        AiQuestionsPanel(
          detail: editableDraft,
          onChanged: (detail) => ref
              .read(adminAiAssistantControllerProvider.notifier)
              .replaceEditableDraft(detail),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiLinkedWordsPanel(
          resolutions: state.linkedWordResolutions,
          selectedPackName: selectedPackName,
          waitingForPackSelection: state.isWaitingForPackSelection,
          onPendingWordChanged: (key, detail) => ref
              .read(adminAiAssistantControllerProvider.notifier)
              .updatePendingLinkedWord(key, detail),
          onRemove: (key) => ref
              .read(adminAiAssistantControllerProvider.notifier)
              .removeLinkedWord(key),
        ),
        const SizedBox(height: 18),
        AiPublishPanel(
          detail: editableDraft,
          selectedPackName: selectedPackName,
          isBusy: state.isBusy,
          onChanged: (detail) => ref
              .read(adminAiAssistantControllerProvider.notifier)
              .replaceEditableDraft(detail),
          onSaveDraft: () => _handlePersist(isPublish: false, packs: packs),
          onPublish: () => _handlePersist(isPublish: true, packs: packs),
        ),
        const SizedBox(height: 18),
        ReadingCoverPanel(
          detail: editableDraft,
          coverUrl: _coverUrlForAsset(editableDraft.cover),
          selectedModel: adminAiCoverAutoModel,
          poolStatus: ref.watch(adminAiCoverPoolStatusProvider).valueOrNull,
          enabled: editableDraft.metadata.id?.trim().isNotEmpty ?? false,
          disabledMessage: editableDraft.metadata.id?.trim().isNotEmpty ?? false
              ? null
              : 'Cover islemleri icin once taslagi kaydedip reading ID alin.',
          isBusy: state.isBusy,
          onChanged: (detail) => ref
              .read(adminAiAssistantControllerProvider.notifier)
              .replaceEditableDraft(detail),
          onGenerate: (selectedModel) =>
              _generateCoverForDraft(editableDraft, selectedModel),
          onUpload:
              ({
                required bytes,
                required fileName,
                required mimeType,
                String? altText,
              }) => _uploadCoverForDraft(
                detail: editableDraft,
                bytes: bytes,
                fileName: fileName,
                mimeType: mimeType,
                altText: altText,
              ),
          onRemove: () => _removeCoverForDraft(editableDraft),
          onMessage: _showMessage,
        ),
        const SizedBox(height: 18),
        _AiMetadataPanel(metadata: metadata),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [leftColumn, const SizedBox(height: 18), rightColumn],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: leftColumn),
            const SizedBox(width: 18),
            Expanded(flex: 4, child: rightColumn),
          ],
        );
      },
    );
  }

  Future<void> _handleGenerate() async {
    List<AdminWordRecord> wordItems = const <AdminWordRecord>[];
    if (_selectedPackId != null) {
      try {
        wordItems = await ref.read(adminWordEntriesProvider.future);
      } catch (_) {
        wordItems = const <AdminWordRecord>[];
      }
    }
    final request = AdminAiGenerateReadingRequest(
      topic: _topicController.text.trim(),
      cefrLevel: _cefrLevel,
      targetWordCount:
          int.tryParse(_targetWordCountController.text.trim()) ?? 0,
      focusWordCount: int.tryParse(_focusWordCountController.text.trim()) ?? 0,
      questionCount: int.tryParse(_questionCountController.text.trim()) ?? 0,
      provider: _provider,
      model: _model,
      extraInstructions: _emptyAsNull(_extraInstructionsController.text),
    );
    final controller = ref.read(adminAiAssistantControllerProvider.notifier);
    controller.updateSelectedPackId(_selectedPackId, wordCatalog: wordItems);
    controller.updateDraftRequest(request);
    await controller.generateDraft(wordCatalog: wordItems);
  }

  Future<void> _handlePersist({
    required bool isPublish,
    required List<AdminPackRecord> packs,
  }) async {
    final controller = ref.read(adminAiAssistantControllerProvider.notifier);
    final result = isPublish
        ? await controller.publish()
        : await controller.saveDraft();
    if (result is AppSuccess<AdminReadingDetail>) {
      final record = adminReadingRecordFromDetail(
        detail: result.value,
        packs: packs,
        fallbackId: 'ai-reading-draft',
      );
      ref.read(adminReadingChangesProvider.notifier).upsert(record);
    }
  }

  Future<AppResult<AdminReadingDetail>> _generateCoverForDraft(
    AdminReadingDetail detail,
    String selectedModel,
  ) async {
    final readingId = detail.metadata.id?.trim();
    if (readingId == null || readingId.isEmpty) {
      return const AppFailure<AdminReadingDetail>(
        'Cover uretimi icin taslak once kaydedilmeli.',
      );
    }

    final result = await ref
        .read(adminAiReadingRepositoryProvider)
        .generateReadingCover(
          AdminAiGenerateReadingCoverRequest(
            readingId: readingId,
            provider: adminAiCoverProviderForModel(selectedModel),
            model: selectedModel,
          ),
        );
    ref.invalidate(adminAiCoverPoolStatusProvider);
    if (result case AppSuccess<AdminReadingDetail>()) {
      ref
          .read(adminAiAssistantControllerProvider.notifier)
          .replaceEditableDraft(result.value);
    }
    return result;
  }

  Future<AppResult<AdminReadingDetail>> _uploadCoverForDraft({
    required AdminReadingDetail detail,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? altText,
  }) async {
    final readingId = detail.metadata.id?.trim();
    if (readingId == null || readingId.isEmpty) {
      return const AppFailure<AdminReadingDetail>(
        'Cover yuklemek icin taslak once kaydedilmeli.',
      );
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .uploadReadingCover(
          readingId: readingId,
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
          altText: altText,
        );
    if (result case AppSuccess<AdminReadingDetail>()) {
      ref
          .read(adminAiAssistantControllerProvider.notifier)
          .replaceEditableDraft(result.value);
    }
    return result;
  }

  Future<AppResult<AdminReadingDetail>> _removeCoverForDraft(
    AdminReadingDetail detail,
  ) async {
    final readingId = detail.metadata.id?.trim();
    if (readingId == null || readingId.isEmpty) {
      return const AppFailure<AdminReadingDetail>(
        'Cover silmek icin taslak once kaydedilmeli.',
      );
    }

    final result = await ref
        .read(adminContentRepositoryProvider)
        .removeReadingCover(readingId: readingId);
    if (result case AppSuccess<AdminReadingDetail>()) {
      ref
          .read(adminAiAssistantControllerProvider.notifier)
          .replaceEditableDraft(result.value);
    }
    return result;
  }

  String? _coverUrlForAsset(AdminReadingCoverAsset cover) {
    final bucket = cover.bucketName?.trim();
    final storagePath = cover.storagePath?.trim();
    if (bucket == null ||
        bucket.isEmpty ||
        storagePath == null ||
        storagePath.isEmpty) {
      return null;
    }

    final supabaseUrl = ref.read(adminAppConfigProvider).supabaseUrl.trim();
    if (supabaseUrl.isEmpty) {
      return null;
    }

    final normalizedBase = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    final encodedPath = storagePath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    return '$normalizedBase/storage/v1/object/public/$bucket/$encodedPath';
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.errorContainer
              : null,
        ),
      );
  }

  String? _emptyAsNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _packNameForId(List<AdminPackRecord> packs, String? packId) {
    final normalizedPackId = _emptyAsNull(packId ?? '');
    if (normalizedPackId == null) {
      return null;
    }
    for (final pack in packs) {
      if (pack.id == normalizedPackId) {
        return pack.name;
      }
    }
    return null;
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isError
        ? colorScheme.errorContainer
        : colorScheme.secondaryContainer;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSecondaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: foreground),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Kapat',
            icon: Icon(Icons.close_rounded, color: foreground),
          ),
        ],
      ),
    );
  }
}

class _AiMetadataPanel extends StatelessWidget {
  const _AiMetadataPanel({required this.metadata});

  final AdminAiGenerationMeta? metadata;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'AI Metadata',
      child: metadata == null
          ? const Text('Generate sonrasi metadata burada gorunur.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetadataRow(label: 'Provider', value: metadata!.provider),
                _MetadataRow(label: 'Model', value: metadata!.model),
                _MetadataRow(label: 'Topic', value: metadata!.topic),
                _MetadataRow(label: 'CEFR', value: metadata!.cefrLevel),
                _MetadataRow(
                  label: 'Word Count',
                  value:
                      '${metadata!.actualWordCount} / hedef ${metadata!.targetWordCount}',
                ),
                _MetadataRow(
                  label: 'Focus Words',
                  value: metadata!.focusWordCount.toString(),
                ),
                _MetadataRow(
                  label: 'Questions',
                  value: metadata!.questionCount.toString(),
                ),
                _MetadataRow(
                  label: 'Generated At',
                  value: metadata!.generatedAt.toIso8601String(),
                ),
              ],
            ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
