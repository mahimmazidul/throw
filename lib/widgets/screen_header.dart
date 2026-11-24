import 'package:flutter/material.dart';

import '../core/constants.dart';

/// The one header used by every screen: a title, an optional line under it,
/// and an optional trailing action.
///
/// The app icon used to sit here on all five screens — Home, Discover,
/// Transfers and Settings each had their own copy of it, and Home and Discover
/// additionally drew a filled band behind theirs. A logo repeated on every
/// screen inside the app adds nothing the window chrome does not already say,
/// and the band was the first thing that made the UI read as boxes: a big
/// tinted container holding a small tinted container holding content.
///
/// Headers are now flat type on the canvas. Separation comes from spacing and
/// from what follows, not from a rectangle.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;

  /// Usually one action; kept alive across rebuilds by the caller.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                // A tight, heavy 28 is what the reference apps use for a page
                // title (LocalSend's tabs, Musify's pages). headlineMedium was
                // chosen here over headlineSmall so removing the logo does not
                // leave the screen headless.
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppConstants.space3),
          trailing!,
        ],
      ],
    );
  }
}
