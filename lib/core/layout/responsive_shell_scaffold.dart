import 'package:flutter/material.dart';

import 'app_breakpoints.dart';

class ResponsiveShellDestination {
  const ResponsiveShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

class ResponsiveShellScaffold extends StatelessWidget {
  const ResponsiveShellScaffold({
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.actions = const <Widget>[],
    this.topBanner,
    this.desktopRailWidth = 104,
    super.key,
  });

  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<ResponsiveShellDestination> destinations;
  final Widget body;
  final List<Widget> actions;
  final Widget? topBanner;
  final double desktopRailWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDesktop = AppBreakpoints.isDesktopWidth(
          constraints.maxWidth,
        );

        final Widget bodyContent = Column(
          children: <Widget>[
            if (topBanner != null) topBanner!,
            Expanded(
              key: const ValueKey<String>('shell-content-host'),
              child: body,
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: actions,
          ),
          body: isDesktop
              ? Row(
                  children: <Widget>[
                    SafeArea(
                      child: SizedBox(
                        width: desktopRailWidth,
                        child: NavigationRail(
                          key: const ValueKey<String>('shell-navigation-rail'),
                          selectedIndex: selectedIndex,
                          onDestinationSelected: onDestinationSelected,
                          labelType: NavigationRailLabelType.all,
                          groupAlignment: -1,
                          useIndicator: true,
                          destinations: destinations
                              .map(
                                (ResponsiveShellDestination destination) =>
                                    NavigationRailDestination(
                                  icon: destination.icon,
                                  selectedIcon: destination.selectedIcon,
                                  label: Text(destination.label),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: bodyContent),
                  ],
                )
              : bodyContent,
          bottomNavigationBar: isDesktop
              ? null
              : NavigationBar(
                  key: const ValueKey<String>('shell-navigation-bar'),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations
                      .map(
                        (ResponsiveShellDestination destination) =>
                            NavigationDestination(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: destination.label,
                        ),
                      )
                      .toList(growable: false),
                ),
        );
      },
    );
  }
}
