import 'package:flutter/material.dart';

enum AppSurfaceVariant { feature, subtle, grouped }

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.variant = AppSurfaceVariant.subtle,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final AppSurfaceVariant variant;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isFeature = variant == AppSurfaceVariant.feature;
    final Color backgroundColor = switch (variant) {
      AppSurfaceVariant.feature => colorScheme.surface,
      AppSurfaceVariant.subtle => colorScheme.surfaceContainerLow,
      AppSurfaceVariant.grouped => colorScheme.surfaceContainerLowest,
    };
    final Widget content = Padding(padding: padding, child: child);

    return Card(
      margin: margin,
      clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isFeature
              ? colorScheme.outlineVariant.withValues(alpha: 0.7)
              : Colors.transparent,
        ),
      ),
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(18),
              mouseCursor: SystemMouseCursors.click,
              hoverColor: colorScheme.primary.withValues(alpha: 0.04),
              onTap: onTap,
              child: content,
            ),
    );
  }
}
