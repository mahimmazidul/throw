import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../widgets/entrance.dart';
import '../widgets/error_banner.dart';
import '../widgets/nearby_device_list.dart';
import '../widgets/screen_header.dart';

/// Discover: scan and advertise.
///
/// The filled header band is gone. A page-level action belongs next to the
/// title, and the state of the scan is a line of text — wrapping both in a
/// tinted rectangle just added a second background competing with the canvas.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = context.watch<DeviceProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.space5,
          AppConstants.space5,
          AppConstants.space5,
          AppConstants.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: l10n.navDiscover,
              subtitle: provider.isDiscovering
                  ? l10n.discoverScanningHint
                  : l10n.discoverIdleHint,
              trailing: Pressable(
                child: FilledButton.tonalIcon(
                  onPressed: provider.isDiscovering
                      ? provider.stopDiscovery
                      : provider.startDiscovery,
                  icon: Icon(
                    provider.isDiscovering
                        ? Icons.stop_rounded
                        : Icons.radar_rounded,
                    size: 17,
                  ),
                  label: Text(
                    provider.isDiscovering
                        ? l10n.actionCancel
                        : l10n.navDiscover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppConstants.space3),
            // Visibility is a toggle, not a button that reads "make visible"
            // until pressed: a switch states the current condition, which is
            // what the user actually needs to know.
            Pressable(
              enabled: true,
              child: Material(
                color: cs.surfaceContainerLow,
                borderRadius: ThrowRadius.card,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: provider.isAdvertising
                      ? provider.stopAdvertising
                      : provider.startAdvertising,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.space4,
                      AppConstants.space2,
                      AppConstants.space2,
                      AppConstants.space2,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          provider.isAdvertising
                              ? Icons.wifi_tethering_rounded
                              : Icons.wifi_tethering_off_rounded,
                          size: 22,
                          color: provider.isAdvertising
                              ? ThrowTheme.accentFg(context)
                              : cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppConstants.space3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                provider.isAdvertising
                                    ? l10n.visibleAs(provider.deviceName)
                                    : l10n.makeVisible,
                                style: theme.textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                l10n.devicesFoundCount(provider.devices.length),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: provider.isAdvertising,
                          onChanged: (value) => value
                              ? provider.startAdvertising()
                              : provider.stopAdvertising(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (provider.error != null) ...[
              const SizedBox(height: AppConstants.space3),
              ErrorBanner(
                error: provider.error!,
                onDismiss: provider.clearError,
              ),
            ],
            if (provider.pendingRequests.isNotEmpty) ...[
              const SizedBox(height: AppConstants.space3),
              ...provider.pendingRequests.map(
                (req) => Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.space2),
                  child: Entrance(
                    child: _ConnectionRequestRow(
                      title: l10n.incomingFrom(req.deviceName),
                      acceptLabel: l10n.actionAccept,
                      rejectLabel: l10n.actionReject,
                      onAccept: () => provider.acceptConnection(req),
                      onReject: () => provider.rejectConnection(req),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppConstants.space3),
            Expanded(
              child: NearbyDeviceList(
                devices: provider.devices,
                isSearching: provider.isDiscovering,
                onDeviceTap: (device) {
                  if (!device.isConnected) {
                    provider.connect(device);
                  }
                },
                onDisconnect: provider.disconnect,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionRequestRow extends StatelessWidget {
  const _ConnectionRequestRow({
    required this.title,
    required this.acceptLabel,
    required this.rejectLabel,
    required this.onAccept,
    required this.onReject,
  });

  final String title;
  final String acceptLabel;
  final String rejectLabel;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: ThrowRadius.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.space4,
          AppConstants.space3,
          AppConstants.space3,
          AppConstants.space3,
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded,
                size: 20, color: ThrowTheme.accentFg(context)),
            const SizedBox(width: AppConstants.space3),
            Expanded(
              child: Text(title, style: theme.textTheme.bodyMedium),
            ),
            Pressable(
              child: TextButton(
                onPressed: onReject,
                child: Text(rejectLabel),
              ),
            ),
            const SizedBox(width: AppConstants.space1),
            Pressable(
              child: FilledButton(
                onPressed: onAccept,
                child: Text(acceptLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
