import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../widgets/nearby_device_list.dart';

/// Discover screen for scanning nearby devices and advertising availability.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final provider = context.watch<DeviceProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.navDiscover,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: provider.isDiscovering
                      ? provider.stopDiscovery
                      : provider.startDiscovery,
                  icon: Icon(
                    provider.isDiscovering
                        ? Icons.stop_rounded
                        : Icons.radar_rounded,
                  ),
                  label: Text(
                    provider.isDiscovering
                        ? l10n.actionCancel
                        : l10n.navDiscover,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: provider.isAdvertising
                      ? provider.stopAdvertising
                      : provider.startAdvertising,
                  icon: Icon(
                    provider.isAdvertising
                        ? Icons.wifi_tethering_rounded
                        : Icons.wifi_tethering_off_rounded,
                  ),
                  tooltip: provider.deviceName,
                ),
              ],
            ),
            if (provider.error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  title: Text(
                    provider.error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: provider.clearError,
                  ),
                ),
              ),
            ],
            if (provider.pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...provider.pendingRequests.map(
                (req) => Card(
                  child: ListTile(
                    title: Text(l10n.incomingFrom(req.name)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => provider.rejectConnection(req),
                          child: Text(l10n.actionReject),
                        ),
                        FilledButton(
                          onPressed: () => provider.acceptConnection(req),
                          child: Text(l10n.actionAccept),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
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
