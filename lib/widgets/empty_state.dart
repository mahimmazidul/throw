import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Centred empty state: a tinted circular glyph, a title, an optional body,
/// and an optional action.
///
/// Replaces the three hand-rolled "icon + one grey line" variants in Discover,
/// Transfers and Home. Titles are required so an empty screen always says
/// *what* is empty (the old Transfers screen showed the Discover screen's
/// copy by accident), and the body is where the "what do I do about it" line
/// goes.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 34,
                // accentFg, not the fill accent: the fill is ~3:1 on its own
                // tint and fails AA for a glyph this size.
                color: ThrowTheme.accentFg(context),
              ),
              const SizedBox(height: AppConstants.space4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (body != null) ...[
                const SizedBox(height: AppConstants.space2),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppConstants.space4),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
