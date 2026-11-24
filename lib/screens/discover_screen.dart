import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../widgets/error_banner.dart';
import '../widgets/nearby_device_list.dart';
import '../widgets/screen_header.dart';

/// Discover screen for scanning nearby devices and advertising availability.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<DeviceProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: l10n.navDiscover,
              subtitle: provider.isDiscovering
                  ? l10n.discoverScanningHint
                  : l10n.discoverIdleHint,
              tone: HeaderTone.raised,
              trailing: FilledButton.tonalIcon(
                onPressed: provider.isDiscovering
                    ? provider.stopDiscovery
                    : provider.startDiscovery,
                icon: Icon(
                  provider.isDiscovering
                      ? Icons.stop_rounded
                      : Icons.radar_rounded,
                  size: 18,
                ),
                label: Text(
                  provider.isDiscovering ? l10n.actionCancel : l10n.navDiscover,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.space3),
            Wrap(
              spacing: AppConstants.space2,
              runSpacing: AppConstants.space2,
              children: [
                ActionChip(
                  avatar: Icon(
                    provider.isAdvertising
                        ? Icons.wifi_tethering_rounded
                        : Icons.wifi_tethering_off_rounded,
                    size: 18,
                  ),
                  label: Text(
                    provider.isAdvertising
                        ? l10n.visibleAs(provider.deviceName)
                        : l10n.makeVisible,
                  ),
                  onPressed: provider.isAdvertising
                      ? provider.stopAdvertising
                      : provider.startAdvertising,
                ),
                Chip(
                  avatar: const Icon(Icons.devices_rounded, size: 18),
                  label: Text(l10n.devicesFoundCount(provider.devices.length)),
                ),
              ],
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
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.link_rounded,
                        color: ThrowTheme.accentFg(context),
                      ),
                      title: Text(l10n.incomingFrom(req.deviceName)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => provider.rejectConnection(req),
                            child: Text(l10n.actionReject),
                          ),
                          const SizedBox(width: AppConstants.space1),
                          FilledButton(
                            onPressed: () => provider.acceptConnection(req),
                            child: Text(l10n.actionAccept),
                          ),
                        ],
                      ),
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
