import 'package:flutter/material.dart';

class AppSurfaceCard extends StatelessWidget {
  const AppSurfaceCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: padding,
      child: child,
    );

    return Card(
      margin: margin,
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: content,
            ),
    );
  }
}
