import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// The one header row used by every screen.
///
/// Home, Discover, Transfers and Settings each grew their own copy of
/// "logo, title, subtitle, optional trailing action", with three different
/// logo sizes and two different subtitles hardcoded in English. This is the
/// single version; LocalSend's tabs share their headers the same way.
///
/// [tone] switches between the plain header (list screens) and the raised
/// "hero" band (Discover, where the header also carries the scan action).
enum HeaderTone { plain, raised }

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showLogo = true,
    this.tone = HeaderTone.plain,
  });

  final String title;
  final String? subtitle;

  /// Usually a button; kept alive across rebuilds by the caller.
  final Widget? trailing;

  final bool showLogo;
  final HeaderTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoSize = tone == HeaderTone.raised ? 34.0 : 32.0;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showLogo) ...[
          ClipRRect(
            borderRadius: ThrowRadius.chip,
            child: Image.asset(
              'assets/logo.png',
              width: logoSize,
              height: logoSize,
            ),
          ),
          const SizedBox(width: AppConstants.space3),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
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
          const SizedBox(width: AppConstants.space2),
          trailing!,
        ],
      ],
    );

    if (tone == HeaderTone.plain) return row;

    return Container(
      padding: const EdgeInsets.all(AppConstants.space4),
      decoration: BoxDecoration(
        borderRadius: ThrowRadius.card,
        color: theme.colorScheme.primaryContainer,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: row,
    );
  }
}
