import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/transfer_provider.dart';
import '../widgets/error_banner.dart';
import '../widgets/transfer_progress.dart';

/// Transfers screen showing active and completed file/text transfers.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final provider = context.watch<TransferProvider>();
    final transfers = provider.transfers.reversed.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: ThrowRadius.chip,
                  child: Image.asset('assets/logo.png', width: 32, height: 32),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.navTransfers,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l10n.transfersSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.error != null) ...[
              ErrorBanner(error: provider.error!, onDismiss: provider.clearError),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: transfers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.stateNoDevices,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: transfers.length,
                      itemBuilder: (context, index) {
                        final transfer = transfers[index];
                        return TransferProgressTile(
                          transfer: transfer,
                          onCancel: () => provider.cancelTransfer(transfer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
