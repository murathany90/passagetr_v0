import 'package:flutter/material.dart';

import '../../../core/widgets/app_surface_card.dart';

enum ReadingDetailPanelType {
  empty,
  translation,
  dictionary,
}

class ReadingDetailSidePanel extends StatelessWidget {
  const ReadingDetailSidePanel({
    required this.type,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final ReadingDetailPanelType type;
  final String title;
  final Widget body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final String sectionLabel = switch (type) {
      ReadingDetailPanelType.empty => 'Detay Paneli',
      ReadingDetailPanelType.translation => 'Ceviri',
      ReadingDetailPanelType.dictionary => 'Sozluk',
    };

    return AppSurfaceCard(
      key: const ValueKey<String>('reading-detail-side-panel'),
      variant: type == ReadingDetailPanelType.empty
          ? AppSurfaceVariant.grouped
          : AppSurfaceVariant.feature,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            sectionLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          body,
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
