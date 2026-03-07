enum AppViewport { mobile, tablet, desktop }

class AppBreakpoints {
  static const double tabletMinWidth = 768;
  static const double desktopMinWidth = 960;

  static AppViewport viewportForWidth(double width) {
    if (width >= desktopMinWidth) {
      return AppViewport.desktop;
    }
    if (width >= tabletMinWidth) {
      return AppViewport.tablet;
    }
    return AppViewport.mobile;
  }

  static bool isDesktopWidth(double width) => width >= desktopMinWidth;

  static bool isTabletWidth(double width) =>
      width >= tabletMinWidth && width < desktopMinWidth;

  static bool isMobileWidth(double width) => width < tabletMinWidth;
}

extension AppViewportX on AppViewport {
  bool get isMobile => this == AppViewport.mobile;
  bool get isTablet => this == AppViewport.tablet;
  bool get isDesktop => this == AppViewport.desktop;
}
