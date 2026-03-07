import 'package:flutter/material.dart';

class ReadingFeedGrid extends StatelessWidget {
  const ReadingFeedGrid({
    required this.children,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.55,
    this.mainAxisExtent,
    super.key,
  });

  final List<Widget> children;
  final int crossAxisCount;
  final double childAspectRatio;
  final double? mainAxisExtent;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      key: const ValueKey<String>('reading-feed-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: mainAxisExtent == null ? childAspectRatio : 1,
        mainAxisExtent: mainAxisExtent,
      ),
      itemBuilder: (BuildContext context, int index) => children[index],
    );
  }
}
