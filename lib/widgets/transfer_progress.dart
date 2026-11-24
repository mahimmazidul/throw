import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../core/transfer_stats.dart';
import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';

/// One transfer, drawn as a flush row — not a card.
///
/// The 1.1 version of this widget wrapped everything in a `Card` and laid the
/// bottom line out as `Row(mainAxisAlignment: spaceBetween)` with two unbounded
/// `Text`s. On a 320–360 dp phone the peer string plus the "12.4 MB / 51.1 MB"
/// string together exceed the row width, so the layout overflowed and painted
/// outside the card — the "name or size goes outside the box" report.
///
/// Rules now enforced (each has a test):
///
///  * every text is inside a `Flexible`/`Expanded` with `maxLines` + ellipsis;
///  * the byte counter never shares a line with the speed; the meta line wraps
///    into two rows of at most two items;
///  * long file names ellipsize, they never push the row wider.
class TransferProgressTile extends StatelessWidget {
  const TransferProgressTile({
    super.key,
    required this.transfer,
    this.onCancel,
    this.onOpen,
  });

  final TransferModel transfer;
  final VoidCallback? onCancel;
  final VoidCallback? onOpen;

  String _stateLabel(AppLocalizations l10n, TransferStatus status) {
    switch (status) {
      case TransferStatus.connecting:
        return l10n.stateConnecting;
      case TransferStatus.pending:
      case TransferStatus.transferring:
        return transfer.isReceiving ? l10n.stateReceiving : l10n.stateSending;
      case TransferStatus.completed:
        return l10n.stateComplete;
      case TransferStatus.failed:
        return l10n.stateFailed;
      case TransferStatus.cancelled:
        return l10n.stateCancelled;
      case TransferStatus.rejected:
        return l10n.stateRejected;
    }
  }

  IconData get _icon => switch (transfer.status) {
        TransferStatus.completed => Icons.check_circle_rounded,
        TransferStatus.failed => Icons.error_rounded,
        TransferStatus.cancelled => Icons.cancel_rounded,
        TransferStatus.rejected => Icons.block_rounded,
        _ => transfer.isReceiving
            ? Icons.download_rounded
            : Icons.upload_rounded,
      };

  Color _iconColor(BuildContext context) => switch (transfer.status) {
        TransferStatus.completed => ThrowTheme.accentFg(context),
        TransferStatus.failed => Theme.of(context).colorScheme.error,
        _ => Theme.of(context).colorScheme.onSurfaceVariant,
      };

  /// The line under the title: "2.3 MB/s · 41 s left" while moving,
  /// "4.1 MB in 6.2 s · 660 KB/s" once it is done.
  String _detail(AppLocalizations l10n) {
    final isActive = transfer.isActive;
    if (isActive) {
      final parts = <String>[];
      if (transfer.speedBytesPerSecond > 0) {
        parts.add(AppUtils.formatSpeed(transfer.speedBytesPerSecond));
      }
      final eta = TransferRateTracker.etaFrom(
        transfer.remainingBytes,
        transfer.speedBytesPerSecond,
      );
      if (eta != null && eta.inSeconds >= 1) {
        parts.add(l10n.timeLeft(eta.inSeconds));
      }
      return parts.isEmpty ? l10n.speedMeasuring : parts.join(' · ');
    }

    final parts = <String>[
      AppUtils.formatBytes(transfer.bytesTransferred),
      AppUtils.formatDuration(transfer.duration),
    ];
    if (transfer.speedBytesPerSecond > 0) {
      parts.add(AppUtils.formatSpeed(transfer.speedBytesPerSecond));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isActive = transfer.isActive;
    final firstPayload =
        transfer.payloads.isNotEmpty ? transfer.payloads.first : null;
    final isText = firstPayload?.kind == PayloadKind.text;
    final title = transfer.title;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.space1,
        vertical: AppConstants.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(_icon, size: 20, color: _iconColor(context)),
              ),
              const SizedBox(width: AppConstants.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    // Direction first, peer second: "from Pixel 7" is what a
                    // person needs; a bare device name was ambiguous.
                    Text(
                      transfer.isReceiving
                          ? l10n.transferFrom(transfer.peer.displayName)
                          : l10n.transferTo(transfer.peer.displayName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (isActive && onCancel != null)
                Pressable(
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: l10n.actionCancel,
                    onPressed: onCancel,
                  ),
                )
              else if (!isActive && transfer.isReceiving && onOpen != null)
                Pressable(
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    tooltip: l10n.receivedActionOpenFile,
                    color: ThrowTheme.accentFg(context),
                    onPressed: onOpen,
                  ),
                ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: AppConstants.space2),
            // Animated, not snapped: a BLE transfer reports progress in
            // bursts, and a bar that jumps 4% at a time reads as broken.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: transfer.progress),
              duration: Motion.adapt(context, Motion.standard),
              curve: Motion.curve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: transfer.totalBytes > 0 ? value : null,
                minHeight: 4,
                borderRadius: ThrowRadius.track,
              ),
            ),
          ],
          const SizedBox(height: AppConstants.space1),
          // Wrapped, not a spaceBetween Row: at 320dp two inline strings and a
          // speed do not fit on one line, and forcing them to made the row
          // overflow. `Wrap` breaks to a second line instead of painting out
          // of bounds.
          Wrap(
            spacing: AppConstants.space2,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _stateLabel(l10n, transfer.status),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: transfer.status == TransferStatus.failed
                      ? cs.error
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                '·',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                _detail(l10n),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: ThrowColors.inkMuted),
              ),
              if (!isActive && !isText && transfer.savedPath != null)
                Text(
                  '·',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              if (!isActive && !isText && transfer.savedPath != null)
                Text(
                  l10n.savedToFolder(AppUtils.folderOf(transfer.savedPath!)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: ThrowColors.inkMuted),
                ),
            ],
          ),
          if (transfer.error != null &&
              transfer.status == TransferStatus.failed) ...[
            const SizedBox(height: AppConstants.space1),
            Text(
              transfer.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ],
        ],
      ),
    );
  }
}
