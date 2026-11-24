import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/transfer_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/screen_header.dart';
import '../widgets/transfer_progress.dart';

/// Transfers screen showing active and completed file/text transfers.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TransferProvider>();
    final transfers = provider.transfers.reversed.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: l10n.navTransfers,
              subtitle: l10n.transfersSubtitle,
            ),
            const SizedBox(height: AppConstants.space4),
            if (provider.error != null) ...[
              ErrorBanner(
                error: provider.error!,
                onDismiss: provider.clearError,
              ),
              const SizedBox(height: AppConstants.space3),
            ],
            Expanded(
              child: transfers.isEmpty
                  ? EmptyState(
                      icon: Icons.swap_horiz_rounded,
                      // This used to render `stateNoDevices` — Discover's copy
                      // on the Transfers screen. It now says what is actually
                      // empty and what will land here.
                      title: l10n.transfersEmptyTitle,
                      body: l10n.transfersEmptyBody,
                    )
                  : ListView.builder(
                      itemCount: transfers.length,
                      padding:
                          const EdgeInsets.only(bottom: AppConstants.space4),
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
