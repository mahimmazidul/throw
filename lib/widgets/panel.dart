import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// A grouped surface with hairline separators — the app's replacement for
/// "one card per idea".
///
/// Every reference studied groups settings and lists this way:
///
///  * Musify's settings page is a run of `CustomBar`s at `BorderRadius.zero`
///    sharing one `Material` surface, separated by the theme divider;
///  * LocalSend's device grid is `Card(margin: EdgeInsets.zero, radius: 10)`
///    tiles, flat on the canvas, no gaps and no borders;
///
/// Throw previously stacked four separate 28dp-radius, bordered, gapped cards
/// per screen. That reads as a dashboard of unrelated widgets rather than one
/// surface, and it is the exact pattern people mean by "AI slop".
///
/// [PanelGroup] is one tinted surface, softly rounded, with optional upper and
/// lower rounding. Rows inside are flush and separated by a 1px line that
/// indents past the leading icon, the way platform settings do it.
class PanelGroup extends StatelessWidget {
  const PanelGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.rounded = true,
  });

  final List<Widget> children;

  /// Small uppercase label above the group, e.g. "APPEARANCE".
  final String? header;

  /// Dim explanatory line below the group.
  final String? footer;

  /// False for groups that sit between others with shared edges.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        // Divider indents past a leading icon so it aligns with the label, the
        // way iOS/Android settings sheets do. A full-bleed line under an icon
        // is the tell of a hand-rolled list.
        rows.add(Padding(
          padding: const EdgeInsets.only(left: AppConstants.space5),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.45),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.space4,
              bottom: AppConstants.space2,
            ),
            child: Text(
              header!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Material(
          color: cs.surfaceContainerLow,
          borderRadius: rounded ? ThrowRadius.card : BorderRadius.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.space4,
              top: AppConstants.space2,
            ),
            child: Text(
              footer!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// A flush row inside a [PanelGroup]: leading glyph, title, optional subtitle,
/// trailing widget, and press feedback that does not fight the group surface.
class FlatRow extends StatelessWidget {
  const FlatRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.trailingText,
    this.minHeight = 60,
  });

  final String title;
  final String? subtitle;

  /// A 24dp `Icon` is the norm here, not a tinted circle — the badge is
  /// reserved for a row that genuinely needs emphasis.
  final Widget? leading;

  final Widget? trailing;

  /// Plain accent text in the trailing slot (e.g. "Rename").
  final String? trailingText;

  final VoidCallback? onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.space4,
        vertical: AppConstants.space3,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconTheme.of(context).copyWith(
                size: 22,
                color: ThrowTheme.accentFg(context),
              ),
              child: leading!,
            ),
            const SizedBox(width: AppConstants.space3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (trailingText != null)
            Padding(
              padding: const EdgeInsets.only(left: AppConstants.space2),
              child: Text(
                trailingText!,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: ThrowTheme.accentFg(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: AppConstants.space2),
            trailing!,
          ],
        ],
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: onTap == null
          ? content
          : InkWell(
              onTap: onTap,
              // The splash belongs to this row, not the whole group.
              splashColor: cs.primary.withValues(alpha: 0.10),
              child: content,
            ),
    );
  }
}
