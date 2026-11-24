import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A circular accent-tinted glyph — the app's one "leading icon" treatment.
///
/// Device cards, Home's send cards, received rows, and error banners all drew
/// their own `CircleAvatar(backgroundColor: primary.withValues(alpha: 0.14))`.
/// They now share this, so the tint, the glyph colour (always the AA-safe
/// [ThrowTheme.accentFg] cut, never the fill accent) and the sizes match.
class AccentIconBadge extends StatelessWidget {
  const AccentIconBadge({
    super.key,
    required this.icon,
    this.size = 40,
    this.iconSize,
    this.emphasis = BadgeEmphasis.tinted,
  });

  final IconData icon;

  /// Diameter of the circle in logical pixels.
  final double size;

  final double? iconSize;

  /// Tinted (default) or solid accent fill for the one leading action on a
  /// screen.
  final BadgeEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final solid = emphasis == BadgeEmphasis.solid;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: solid ? cs.primary : cs.primary.withValues(alpha: 0.13),
      ),
      child: Icon(
        icon,
        size: iconSize ?? size * 0.5,
        color: solid ? cs.onPrimary : ThrowTheme.accentFg(context),
      ),
    );
  }
}

enum BadgeEmphasis { tinted, solid }
