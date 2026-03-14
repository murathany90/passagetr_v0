import 'package:flutter/material.dart';
import 'package:shared_domain/shared_domain.dart';

import '../../../core/admin_ai_assistant_controller.dart';
import '../../common/admin_page_parts.dart';

class AiLinkedWordsPanel extends StatelessWidget {
  const AiLinkedWordsPanel({
    super.key,
    required this.resolutions,
    required this.selectedPackName,
    required this.waitingForPackSelection,
    required this.onPendingWordChanged,
    required this.onRemove,
  });

  final List<AdminAiLinkedWordResolution> resolutions;
  final String? selectedPackName;
  final bool waitingForPackSelection;
  final void Function(String key, AdminWordDetail detail) onPendingWordChanged;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Linked Words',
      child: waitingForPackSelection
          ? const Text('Paket secildiginde linked words otomatik hazirlanacak.')
          : resolutions.isEmpty
          ? const Text('Bu taslak icin linked word onerisi yok.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in resolutions) ...[
                  if (item.isMatchedExisting && item.linkedWord != null)
                    _MatchedLinkedWordTile(
                      item: item,
                      selectedPackName: selectedPackName,
                      onRemove: onRemove,
                    )
                  else if (item.isPendingCreate && item.pendingWord != null)
                    _PendingLinkedWordTile(
                      item: item,
                      onChanged: onPendingWordChanged,
                      onRemove: onRemove,
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _MatchedLinkedWordTile extends StatelessWidget {
  const _MatchedLinkedWordTile({
    required this.item,
    required this.selectedPackName,
    required this.onRemove,
  });

  final AdminAiLinkedWordResolution item;
  final String? selectedPackName;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final linkedWord = item.linkedWord!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${linkedWord.enWord} (${item.source.pos})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(linkedWord.trMeaning),
          const SizedBox(height: 4),
          Text('Paket: ${selectedPackName ?? '-'}'),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => onRemove(item.key),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('Unlink'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingLinkedWordTile extends StatefulWidget {
  const _PendingLinkedWordTile({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final AdminAiLinkedWordResolution item;
  final void Function(String key, AdminWordDetail detail) onChanged;
  final ValueChanged<String> onRemove;

  @override
  State<_PendingLinkedWordTile> createState() => _PendingLinkedWordTileState();
}

class _PendingLinkedWordTileState extends State<_PendingLinkedWordTile> {
  late final TextEditingController _enWordController;
  late final TextEditingController _trMeaningController;
  late final TextEditingController _posController;
  late final TextEditingController _exampleEnController;
  late final TextEditingController _exampleTrController;
  late final TextEditingController _levelController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _seedControllers(widget.item.pendingWord!);
  }

  @override
  void didUpdateWidget(covariant _PendingLinkedWordTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextWord = widget.item.pendingWord!;
    final previousWord = oldWidget.item.pendingWord!;
    if (_wordChanged(previousWord, nextWord)) {
      _syncController(_enWordController, nextWord.enWord);
      _syncController(_trMeaningController, nextWord.trMeaning);
      _syncController(_posController, nextWord.pos);
      _syncController(_exampleEnController, nextWord.exampleEn);
      _syncController(_exampleTrController, nextWord.exampleTr ?? '');
      _syncController(_levelController, nextWord.level ?? '');
      _syncController(_notesController, nextWord.notes ?? '');
    }
  }

  @override
  void dispose() {
    _enWordController.dispose();
    _trMeaningController.dispose();
    _posController.dispose();
    _exampleEnController.dispose();
    _exampleTrController.dispose();
    _levelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

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
          Text(
            'Yeni Kelime Karti',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _enWordController,
                  decoration: const InputDecoration(labelText: 'English word'),
                  onChanged: (_) => _emitUpdate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _trMeaningController,
                  decoration: const InputDecoration(
                    labelText: 'Turkish meaning',
                  ),
                  onChanged: (_) => _emitUpdate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _posController,
                  decoration: const InputDecoration(labelText: 'POS'),
                  onChanged: (_) => _emitUpdate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _levelController,
                  decoration: const InputDecoration(labelText: 'Level'),
                  onChanged: (_) => _emitUpdate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _exampleEnController,
            decoration: const InputDecoration(labelText: 'Example EN'),
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => _emitUpdate(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _exampleTrController,
            decoration: const InputDecoration(labelText: 'Example TR'),
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => _emitUpdate(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => _emitUpdate(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => widget.onRemove(widget.item.key),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  void _seedControllers(AdminWordDetail detail) {
    _enWordController = TextEditingController(text: detail.enWord);
    _trMeaningController = TextEditingController(text: detail.trMeaning);
    _posController = TextEditingController(text: detail.pos);
    _exampleEnController = TextEditingController(text: detail.exampleEn);
    _exampleTrController = TextEditingController(text: detail.exampleTr ?? '');
    _levelController = TextEditingController(text: detail.level ?? '');
    _notesController = TextEditingController(text: detail.notes ?? '');
  }

  bool _wordChanged(AdminWordDetail left, AdminWordDetail right) {
    return left.enWord != right.enWord ||
        left.trMeaning != right.trMeaning ||
        left.pos != right.pos ||
        left.exampleEn != right.exampleEn ||
        left.exampleTr != right.exampleTr ||
        left.level != right.level ||
        left.notes != right.notes;
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.text = value;
  }

  void _emitUpdate() {
    final current = widget.item.pendingWord!;
    widget.onChanged(
      widget.item.key,
      current.copyWith(
        enWord: _enWordController.text.trim(),
        trMeaning: _trMeaningController.text.trim(),
        pos: _posController.text.trim().isEmpty
            ? 'n.'
            : _posController.text.trim(),
        exampleEn: _exampleEnController.text.trim(),
        exampleTr: _exampleTrController.text.trim(),
        level: _nullableText(_levelController.text),
        notes: _nullableText(_notesController.text),
        clearExampleTr: _exampleTrController.text.trim().isEmpty,
        clearLevel: _levelController.text.trim().isEmpty,
        clearNotes: _notesController.text.trim().isEmpty,
      ),
    );
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
