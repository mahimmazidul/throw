import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// A titled run of rows on the bare canvas.
///
/// This is the third and final answer to "why is everything in boxes". The
/// first pass stacked bordered cards. The second replaced them with one rounded
/// *filled* rectangle per section — better, but still a rectangle drawn around
/// content, and every section on every screen had one. The references do not do
/// that:
///
///  * LocalSend's device grid is flat tiles on the canvas with a hairline
///    under each row and no container at all (`Card(margin: zero)` with the
///    surface colour equal to the background);
///  * Musify's settings page is rows separated by the theme divider;
///  * Android Settings and iOS grouped lists both rely on a small caps label,
///    whitespace, and one hairline per row.
///
/// So [Section] draws **no surface**: an uppercase label, the rows, and a
/// hairline between them. Grouping comes from type and rhythm. The only filled
/// shapes left in the app are pills that are genuinely pressable (buttons,
/// peer chips) and the progress track, which is a gauge, not a container.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;

  /// Small uppercase label above the group, e.g. "THIS DEVICE".
  final String? header;

  /// Dim explanatory line below the group.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        // Indented past the leading glyph so the line aligns with the label,
        // the way platform settings sheets do.
        rows.add(Padding(
          padding: const EdgeInsets.only(left: AppConstants.space5),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.35),
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
              left: AppConstants.space1,
              bottom: AppConstants.space2,
            ),
            child: Text(
              header!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ...rows,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppConstants.space1,
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

/// A flush row: leading glyph, title, optional subtitle, trailing widget, and
/// press feedback on the canvas.
///
/// Sizing rules that stop the overflow reported in 1.2:
///
///  * the text column is inside an `Expanded`, so it can shrink;
///  * the title and subtitle both carry `maxLines` + ellipsis;
///  * the trailing slot is capped at 40% of the width, so a long value or a
///    switch can never push the title out of its own row.
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
    this.dense = false,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 2,
  });

  final String title;
  final String? subtitle;

  /// A 22dp `Icon` is the norm here, not a tinted circle — the badge is
  /// reserved for a row that genuinely needs emphasis.
  final Widget? leading;

  final Widget? trailing;

  /// Plain accent text in the trailing slot (e.g. "Rename").
  final String? trailingText;

  final VoidCallback? onTap;
  final double minHeight;
  final bool dense;
  final int titleMaxLines;
  final int subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppConstants.space2 : AppConstants.space1,
        vertical: dense ? AppConstants.space2 : AppConstants.space3,
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
                  style: (dense
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
                      maxLines: subtitleMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          if (trailingText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Padding(
                padding: const EdgeInsets.only(left: AppConstants.space2),
                child: Text(
                  trailingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ThrowTheme.accentFg(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (trailing != null) ...[
            const SizedBox(width: AppConstants.space2),
            // Cap the trailing slot: an unbounded child (a long value, a
            // switch row inside a Row) was what pushed titles out of the card.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.4,
              ),
              child: trailing!,
            ),
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
              borderRadius: ThrowRadius.row,
              splashColor: cs.primary.withValues(alpha: 0.08),
              highlightColor: cs.primary.withValues(alpha: 0.04),
              child: content,
            ),
    );
  }
}

/// A row whose entire body is a caller-supplied widget — used by lists that are
/// not simple label/value pairs (transfer rows, receipts). It keeps the same
/// press behaviour and hairline rhythm as [FlatRow] without imposing a layout.
class FlatContentRow extends StatelessWidget {
  const FlatContentRow({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppConstants.space1,
      vertical: AppConstants.space3,
    ),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: ThrowRadius.row,
      splashColor: cs.primary.withValues(alpha: 0.08),
      child: Padding(padding: padding, child: child),
    );
  }
}
