import 'package:flutter/widgets.dart';

/// Responsive tiers for Throw's adaptive layout.
///
/// Widths are logical pixels (dp). Derive them from [LayoutBuilder] inside
/// widgets, and from [MediaQuery] only at screen or scaffold level.
enum ScreenClass {
  /// 0–599dp — phones in portrait. Single column, bottom navigation.
  compact,

  /// 600–839dp — tablet portrait, phone landscape. Two columns, nav rail.
  medium,

  /// 840–1199dp — tablet landscape, unfolded foldables. Master-detail.
  expanded,

  /// 1200–1599dp — desktop windows. Permanent sidebar.
  large,

  /// 1600dp+ — large desktops. Extra room for three-panel layouts.
  extraLarge,
}

/// Screen width breakpoints, matching the project's responsive spec.
abstract final class Breakpoints {
  /// Smallest width — compact starts here.
  static const double compact = 0;

  /// Tablet portrait and phone landscape.
  static const double medium = 600;

  /// Tablet landscape and foldables — master-detail kicks in.
  static const double expanded = 840;

  /// Desktop windows.
  static const double large = 1200;

  /// Large desktops.
  static const double extraLarge = 1600;

  /// Tier for a given [width]. Call with a width from [LayoutBuilder] or,
  /// at screen level, from [MediaQuery.sizeOf].
  static ScreenClass of(double width) {
    if (width >= extraLarge) return ScreenClass.extraLarge;
    if (width >= large) return ScreenClass.large;
    if (width >= expanded) return ScreenClass.expanded;
    if (width >= medium) return ScreenClass.medium;
    return ScreenClass.compact;
  }

  /// Convenience for screen/scaffold-level use only.
  static ScreenClass ofContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);

  /// True when the width fits a permanent sidebar layout.
  static bool hasPermanentSidebar(double width) => width >= large;

  /// True when device list and transfer panel fit side by side.
  static bool isMasterDetail(double width) => width >= expanded;
}
