import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

class AppPageContainer extends StatelessWidget {
  const AppPageContainer({
    required this.child,
    this.maxWidth = 1320,
    this.padding,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppViewport viewport = AppBreakpoints.viewportForWidth(
          constraints.maxWidth,
        );
        final EdgeInsetsGeometry resolvedPadding =
            padding ?? _paddingForViewport(viewport);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(padding: resolvedPadding, child: child),
          ),
        );
      },
    );
  }

  EdgeInsetsGeometry _paddingForViewport(AppViewport viewport) {
    switch (viewport) {
      case AppViewport.mobile:
        return const EdgeInsets.all(16);
      case AppViewport.tablet:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 18);
      case AppViewport.desktop:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 18);
    }
  }
}
