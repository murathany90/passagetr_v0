import 'package:flutter/material.dart';
import 'package:shared_domain/shared_domain.dart';

import '../../common/admin_page_parts.dart';

class AiPublishPanel extends StatelessWidget {
  const AiPublishPanel({
    super.key,
    required this.detail,
    required this.selectedPackName,
    required this.isBusy,
    required this.onChanged,
    required this.onSaveDraft,
    required this.onPublish,
  });

  final AdminReadingDetail detail;
  final String? selectedPackName;
  final bool isBusy;
  final ValueChanged<AdminReadingDetail> onChanged;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Publish Panel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(
            label: 'Paket',
            value: selectedPackName ?? 'Save veya publish oncesi secin',
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: detail.isPro,
            onChanged: (value) => onChanged(detail.copyWith(isPro: value)),
            title: const Text('Pro icerik'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(
              'publish-at-${detail.publishAt?.toIso8601String() ?? ''}',
            ),
            initialValue: _formatDateTime(detail.publishAt),
            decoration: const InputDecoration(
              labelText: 'Publish At',
              helperText: 'YYYY-MM-DD HH:MM',
            ),
            onChanged: (value) {
              final parsed = _parseDateTime(value);
              if (value.trim().isEmpty) {
                onChanged(detail.copyWith(clearPublishAt: true));
              } else if (parsed != null) {
                onChanged(detail.copyWith(publishAt: parsed));
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(
              'unpublish-at-${detail.unpublishAt?.toIso8601String() ?? ''}',
            ),
            initialValue: _formatDateTime(detail.unpublishAt),
            decoration: const InputDecoration(
              labelText: 'Unpublish At',
              helperText: 'YYYY-MM-DD HH:MM',
            ),
            onChanged: (value) {
              final parsed = _parseDateTime(value);
              if (value.trim().isEmpty) {
                onChanged(detail.copyWith(clearUnpublishAt: true));
              } else if (parsed != null) {
                onChanged(detail.copyWith(unpublishAt: parsed));
              }
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: isBusy ? null : onSaveDraft,
                child: const Text('Save Draft'),
              ),
              OutlinedButton(
                onPressed: isBusy ? null : onPublish,
                child: const Text('Publish'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '';
    }
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  DateTime? _parseDateTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 84, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    );
  }
}
