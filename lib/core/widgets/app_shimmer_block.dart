import 'package:flutter/material.dart';

/// A shimmer/skeleton placeholder block for loading states.
///
/// Uses a repeating gradient animation to create a shimmer effect.
/// Defaults to a rounded rectangle; customize with [width], [height],
/// and [borderRadius].
class AppShimmerBlock extends StatefulWidget {
  const AppShimmerBlock({
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<AppShimmerBlock> createState() => _AppShimmerBlockState();
}

class _AppShimmerBlockState extends State<AppShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color base = colors.surfaceContainerHighest;
    final Color highlight = colors.surfaceContainerLow;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: <Color>[base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

/// A pre-composed shimmer card that mimics the visual footprint of an
/// [AppSurfaceCard] during loading. Perfect for list placeholders.
class AppShimmerCard extends StatelessWidget {
  const AppShimmerCard({this.lineCount = 3, super.key});

  final int lineCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppShimmerBlock(width: 140, height: 16, borderRadius: 6),
          const SizedBox(height: 12),
          for (int i = 0; i < lineCount; i++) ...<Widget>[
            AppShimmerBlock(
              width: i == lineCount - 1 ? 200 : double.infinity,
              height: 12,
              borderRadius: 4,
            ),
            if (i < lineCount - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
