import 'package:flutter/material.dart';

const double kMobileMaxWidth = 600;
const double kTabletMaxWidth = 1024;

bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < kMobileMaxWidth;
bool isTablet(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  return w >= kMobileMaxWidth && w < kTabletMaxWidth;
}
bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= kTabletMaxWidth;

T responsiveValue<T>({
  required double width,
  required T mobile,
  required T tablet,
  required T desktop,
}) {
  if (width < kMobileMaxWidth) return mobile;
  if (width < kTabletMaxWidth) return tablet;
  return desktop;
}

Orientation currentOrientation(BuildContext context) => MediaQuery.of(context).orientation;

