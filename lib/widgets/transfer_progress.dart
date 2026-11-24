import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';

import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';

/// Displays a single file or text transfer with progress bar, status, and cancel.
class TransferProgressTile extends StatelessWidget {
  const TransferProgressTile({
    super.key,
    required this.transfer,
    this.onCancel,
  });

  final TransferModel transfer;
  final VoidCallback? onCancel;

  String _stateLabel(AppLocalizations l10n, TransferStatus status) {
    switch (status) {
      case TransferStatus.connecting:
        return l10n.stateConnecting;
      case TransferStatus.pending:
      case TransferStatus.transferring:
        return l10n.stateTransferring;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final firstPayload =
        transfer.payloads.isNotEmpty ? transfer.payloads.first : null;
    final isFile = firstPayload?.kind == PayloadKind.file;
    final title =
        isFile ? (firstPayload?.name ?? 'file') : (firstPayload?.text ?? '');
    final isActive = transfer.isActive;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (transfer.status) {
                    TransferStatus.completed => Icons.check_circle_rounded,
                    TransferStatus.failed => Icons.error_rounded,
                    TransferStatus.cancelled => Icons.cancel_rounded,
                    TransferStatus.rejected => Icons.block_rounded,
                    _ => Icons.swap_horiz_rounded,
                  },
                  size: 20,
                  color: switch (transfer.status) {
                    TransferStatus.completed => ThrowTheme.accentFg(context),
                    TransferStatus.failed => theme.colorScheme.error,
                    _ => theme.colorScheme.onSurfaceVariant,
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (isActive && onCancel != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: l10n.actionCancel,
                    onPressed: onCancel,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Animated, not snapped: a BLE transfer reports progress in
            // bursts, and a bar that jumps 4% at a time reads as broken.
            TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: isActive ? transfer.progress : 1.0,
              ),
              duration: Motion.adapt(context, Motion.standard),
              curve: Motion.curve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                borderRadius: ThrowRadius.track,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${transfer.peer.name} · ${_stateLabel(l10n, transfer.status)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${AppUtils.formatBytes(transfer.bytesTransferred)} / ${AppUtils.formatBytes(transfer.totalBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
