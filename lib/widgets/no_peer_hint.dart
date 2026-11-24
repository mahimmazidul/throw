import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';

/// Shown on Home while nothing is connected: one quiet line of guidance, not a
/// container apologising for empty space.
///
/// This lives beside the peer selection it explains. It used to live in a file
/// called `device_picker.dart` that also held a `DevicePicker` the Home screen
/// no longer uses — the picker became a plain section of rows, so only the hint
/// survived.
class NoPeerHint extends StatelessWidget {
  const NoPeerHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            Icons.devices_other_rounded,
            size: 18,
            color: ThrowTheme.accentFg(context),
          ),
        ),
        const SizedBox(width: AppConstants.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeNoPeersTitle,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.homeNoPeersBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
