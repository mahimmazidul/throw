import 'package:flutter/material.dart';

import '../core/breakpoints.dart';

/// Responsive layout wrapper that switches between compact, medium,
/// and expanded builders using [LayoutBuilder].
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context, BoxConstraints constraints)
      compact;
  final Widget Function(BuildContext context, BoxConstraints constraints)?
      medium;
  final Widget Function(BuildContext context, BoxConstraints constraints)?
      expanded;

  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Breakpoints.of(constraints.maxWidth);
        if (size.index >= WindowClass.expanded.index && expanded != null) {
          return expanded!(context, constraints);
        }
        if (size.index >= WindowClass.medium.index && medium != null) {
          return medium!(context, constraints);
        }
        return compact(context, constraints);
      },
    );
  }
}
