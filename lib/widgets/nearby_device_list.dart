import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import 'device_card.dart';

/// Displays the list of discovered nearby devices or an empty/searching state.
class NearbyDeviceList extends StatelessWidget {
  final List<DeviceModel> devices;
  final bool isSearching;
  final ValueChanged<DeviceModel> onDeviceTap;
  final ValueChanged<DeviceModel>? onDisconnect;

  const NearbyDeviceList({
    super.key,
    required this.devices,
    required this.isSearching,
    required this.onDeviceTap,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (devices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSearching ? Icons.radar_rounded : Icons.devices_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                isSearching ? l10n.stateSearching : l10n.stateNoDevices,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: devices.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) {
        final device = devices[index];
        return DeviceCard(
          device: device,
          onTap: () => onDeviceTap(device),
          onDisconnect:
              onDisconnect != null ? () => onDisconnect!(device) : null,
        );
      },
    );
  }
}
