import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/transfer_provider.dart';
import '../widgets/entrance.dart';
import '../widgets/error_banner.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';
import '../widgets/transfer_progress.dart';

/// Transfers: what is moving now, and what moved recently.
///
/// Split into two sections because they answer different questions. Active rows
/// carry progress, speed and ETA; finished rows carry the outcome, the time it
/// took and — for received files — the folder they went to.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = context.watch<TransferProvider>();

    final active = provider.activeTransfers;
    final recent = provider.finishedTransfers;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppConstants.contentMax),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.space5,
              AppConstants.space5,
              AppConstants.space5,
              AppConstants.space6,
            ),
            children: [
              StaggeredEntrance(
                children: [
                  ScreenHeader(
                    title: l10n.navTransfers,
                    subtitle: l10n.transfersSubtitle,
                  ),
                  const SizedBox(height: AppConstants.space5),
                  if (provider.error != null) ...[
                    ErrorBanner(
                      error: provider.error!,
                      onDismiss: provider.clearError,
                    ),
                    const SizedBox(height: AppConstants.space4),
                  ],
                  if (active.isEmpty && recent.isEmpty)
                    Section(
                      children: [
                        FlatRow(
                          leading: const Icon(Icons.swap_horiz_rounded),
                          title: l10n.transfersEmptyTitle,
                          subtitle: l10n.transfersEmptyBody,
                          titleMaxLines: 2,
                          subtitleMaxLines: 2,
                        ),
                      ],
                    ),
                  if (active.isNotEmpty)
                    Section(
                      header: l10n.transfersActiveSection,
                      children: [
                        for (final transfer in active)
                          TransferProgressTile(
                            transfer: transfer,
                            onCancel: () => provider.cancelTransfer(transfer),
                          ),
                      ],
                    ),
                  if (active.isNotEmpty && recent.isNotEmpty)
                    const SizedBox(height: AppConstants.space5),
                  if (recent.isNotEmpty)
                    Section(
                      header: l10n.transfersRecentSection,
                      children: [
                        for (final transfer in recent.take(30))
                          TransferProgressTile(transfer: transfer),
                      ],
                    ),
                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.space4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Pressable(
                        child: TextButton(
                          onPressed: () {
                            provider.clearHistory();
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(content: Text(l10n.transfersCleared)),
                              );
                          },
                          style:
                              TextButton.styleFrom(foregroundColor: cs.error),
                          child: Text(l10n.transfersClearHistory),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
