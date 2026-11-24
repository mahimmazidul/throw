import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import 'device_card.dart';
import 'empty_state.dart';

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
      // A radar that is actually running: a still icon next to the word
      // "Searching" claims activity it does not show.
      if (isSearching) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: AppConstants.space4),
              Text(
                l10n.stateSearching,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      return EmptyState(
        icon: Icons.radar_rounded,
        title: l10n.stateNoDevices,
        body: l10n.discoverIdleHint,
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
