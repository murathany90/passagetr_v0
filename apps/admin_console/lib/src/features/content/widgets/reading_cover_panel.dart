import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

import '../../common/admin_page_parts.dart';

typedef ReadingCoverUploadCallback =
    Future<AppResult<AdminReadingDetail>> Function({
      required Uint8List bytes,
      required String fileName,
      required String mimeType,
      String? altText,
    });

class ReadingCoverPanel extends StatefulWidget {
  const ReadingCoverPanel({
    super.key,
    required this.detail,
    required this.coverUrl,
    required this.onChanged,
    required this.onGenerate,
    required this.onUpload,
    required this.onRemove,
    required this.onMessage,
    this.enabled = true,
    this.disabledMessage,
    this.isBusy = false,
  });

  final AdminReadingDetail detail;
  final String? coverUrl;
  final ValueChanged<AdminReadingDetail> onChanged;
  final Future<AppResult<AdminReadingDetail>> Function() onGenerate;
  final ReadingCoverUploadCallback onUpload;
  final Future<AppResult<AdminReadingDetail>> Function() onRemove;
  final void Function(String message, {bool isError}) onMessage;
  final bool enabled;
  final String? disabledMessage;
  final bool isBusy;

  @override
  State<ReadingCoverPanel> createState() => _ReadingCoverPanelState();
}

class _ReadingCoverPanelState extends State<ReadingCoverPanel> {
  bool _isActing = false;

  bool get _canInteract => widget.enabled && !_isActing && !widget.isBusy;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final cover = detail.cover;
    final hasCover = cover.hasCover;

    return AdminPanelCard(
      title: 'Cover',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.enabled && widget.disabledMessage != null) ...[
            Text(widget.disabledMessage!),
            const SizedBox(height: 12),
          ],
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: widget.coverUrl != null && widget.coverUrl!.trim().isNotEmpty
                    ? Image.network(
                        widget.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _CoverPlaceholder(hasCover: hasCover);
                        },
                      )
                    : _CoverPlaceholder(hasCover: hasCover),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: ValueKey(
              'reading-cover-alt-${detail.metadata.id ?? 'draft'}-${cover.altText ?? ''}',
            ),
            initialValue: cover.altText ?? detail.title,
            decoration: const InputDecoration(labelText: 'Alt Text'),
            enabled: _canInteract,
            onChanged: (value) => widget.onChanged(
              detail.copyWith(
                cover: detail.cover.copyWith(
                  altText: value.trim(),
                  clearAltText: value.trim().isEmpty,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _canInteract ? _handleGenerate : null,
                icon: _isActing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(hasCover ? 'AI ile Yeniden Uret' : 'AI ile Uret'),
              ),
              OutlinedButton.icon(
                onPressed: _canInteract ? _handleUpload : null,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(hasCover ? 'Dosya ile Degistir' : 'Dosya Yukle'),
              ),
              OutlinedButton.icon(
                onPressed: _canInteract && hasCover ? _handleRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Sil'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleGenerate() async {
    await _runAction(
      widget.onGenerate,
      successMessage: widget.detail.cover.hasCover
          ? 'Cover yeniden uretildi.'
          : 'Cover olusturuldu.',
    );
  }

  Future<void> _handleUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      widget.onMessage('Secilen dosya okunamadi.', isError: true);
      return;
    }

    final mimeType = _mimeTypeFor(file.name);
    await _runAction(
      () => widget.onUpload(
        bytes: bytes,
        fileName: file.name,
        mimeType: mimeType,
        altText: widget.detail.cover.altText ?? widget.detail.title,
      ),
      successMessage: widget.detail.cover.hasCover
          ? 'Cover dosya ile guncellendi.'
          : 'Cover yuklendi.',
    );
  }

  Future<void> _handleRemove() async {
    await _runAction(
      widget.onRemove,
      successMessage: 'Cover kaldirildi.',
    );
  }

  Future<void> _runAction(
    Future<AppResult<AdminReadingDetail>> Function() action, {
    required String successMessage,
  }) async {
    setState(() {
      _isActing = true;
    });

    final result = await action();
    if (!mounted) {
      return;
    }

    setState(() {
      _isActing = false;
    });

    switch (result) {
      case AppSuccess<AdminReadingDetail>(value: final detail):
        widget.onChanged(detail);
        widget.onMessage(successMessage);
      case AppFailure<AdminReadingDetail>(message: final message):
        widget.onMessage(message, isError: true);
    }
  }

  String _mimeTypeFor(String fileName) {
    final lower = fileName.trim().toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/png';
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.hasCover});

  final bool hasCover;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasCover
                ? Icons.broken_image_outlined
                : Icons.landscape_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            hasCover ? 'Cover onizlemesi yuklenemedi.' : 'Henuz cover yok.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
