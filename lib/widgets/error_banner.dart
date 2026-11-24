import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/permissions.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/app_error.dart';

/// The app's single on-screen error surface.
///
/// Replaces three things: the hand-rolled `Card` in the discover screen, the
/// `SnackBar`s in settings, and the `TransferProvider` errors that were
/// stored but never displayed anywhere at all.
///
/// Shape follows the rest of the app — a soft 28dp panel with a circular
/// icon badge and pill actions, so an error state never looks like a
/// different product from the happy state.
class ErrorBanner extends StatefulWidget {
  const ErrorBanner({super.key, required this.error, this.onDismiss});

  final AppError error;

  /// Omit to leave a retryable failure in place until it resolves or is
  /// explicitly dismissed.
  final VoidCallback? onDismiss;

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final onDismiss = widget.onDismiss;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final cs = theme.colorScheme;
    final message = describeError(error, l10n);
    // A technical detail exists but is not worth shouting: it goes behind a
    // disclosure. Before this the raw exception was concatenated into the
    // message, so users read "Something went wrong: Bad state: No element".
    final detail = error.detail;
    final hasDetail = detail != null &&
        detail.trim().isNotEmpty &&
        error.code == AppErrorCode.unknown;

    return Semantics(
      liveRegion: true,
      container: true,
      label: message,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 12, onDismiss == null ? 14 : 8, 12),
        decoration: BoxDecoration(
          color: cs.errorContainer,
          borderRadius: ThrowRadius.card,
          border: Border.all(color: cs.error.withValues(alpha: 0.38)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.error.withValues(alpha: 0.16),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 20,
                    color: cs.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: l10n.actionClose,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: cs.onErrorContainer,
                    ),
                  ),
              ],
            ),
            if (hasDetail) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Pressable(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showDetail = !_showDetail),
                    icon: Icon(
                      _showDetail
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: cs.onErrorContainer,
                    ),
                    label: Text(
                      l10n.errorShowDetail,
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: Motion.adapt(context, Motion.fast),
                curve: Motion.curve,
                alignment: Alignment.topCenter,
                child: _showDetail
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: SelectableText(
                          detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onErrorContainer.withValues(alpha: 0.8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
            if (error.offerSettings) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: Permissions.openSettings,
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: cs.onErrorContainer,
                  ),
                  label: Text(
                    l10n.openSystemSettings,
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
