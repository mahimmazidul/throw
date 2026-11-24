import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../models/payload_model.dart';
import '../models/transfer_model.dart';

/// Displays a single file or text transfer with progress bar, status, and cancel.
class TransferProgressTile extends StatelessWidget {
  final TransferModel transfer;
  final VoidCallback? onCancel;

  const TransferProgressTile({
    super.key,
    required this.transfer,
    this.onCancel,
  });

  String _stateLabel(AppLocalizations l10n, TransferState state) {
    switch (state) {
      case TransferState.pending:
      case TransferState.transferring:
        return l10n.stateTransferring;
      case TransferState.completed:
        return l10n.stateComplete;
      case TransferState.failed:
        return l10n.stateFailed;
      case TransferState.cancelled:
        return l10n.stateCancelled;
      case TransferState.rejected:
        return l10n.stateRejected;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isFile = transfer.payload.type == PayloadType.file;
    final title = isFile
        ? (transfer.payload.fileName ?? 'file')
        : (transfer.payload.text ?? '');
    final isActive = transfer.state == TransferState.pending ||
        transfer.state == TransferState.transferring;

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
                  transfer.direction == TransferDirection.outgoing
                      ? Icons.upload_rounded
                      : Icons.download_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
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
            LinearProgressIndicator(
              value: isActive ? transfer.progress : 1.0,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${transfer.device.name} · ${_stateLabel(l10n, transfer.state)}',
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
