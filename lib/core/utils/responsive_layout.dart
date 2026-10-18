import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.shortestSide >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static bool isTabletOrLarger(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.shortestSide >= 600 ||
        (media.orientation == Orientation.landscape && media.size.width >= 600);
  }

  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200 && desktop != null) {
          return desktop!;
        } else if (shortestSide >= 600 || (constraints.maxWidth >= 720 && constraints.maxHeight >= 500)) {
          return tablet;
        } else {
          return mobile;
        }
      },
    );
  }
}
