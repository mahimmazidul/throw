import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/device_model.dart';

/// Displays a discovered or connected nearby device with transport badge
/// and connect/disconnect action.
class DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback? onTap;
  final VoidCallback? onDisconnect;

  const DeviceCard({
    super.key,
    required this.device,
    this.onTap,
    this.onDisconnect,
  });

  IconData _platformIcon(DevicePlatform platform) {
    switch (platform) {
      case DevicePlatform.android:
        return Icons.android_rounded;
      case DevicePlatform.windows:
        return Icons.desktop_windows_rounded;
      case DevicePlatform.linux:
        return Icons.laptop_rounded;
      case DevicePlatform.unknown:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final transportLabel = device.transport == TransportType.wifiDirect
        ? l10n.speedWifi
        : l10n.speedBluetooth;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: device.isConnected
              ? colorScheme.primary.withValues(alpha: 0.16)
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            _platformIcon(device.platform),
            color: device.isConnected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(
          device.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          device.isConnected
              ? '${l10n.stateConnected} · $transportLabel'
              : transportLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: device.isConnected && onDisconnect != null
            ? IconButton(
                icon: const Icon(Icons.link_off_rounded),
                tooltip: l10n.actionClose,
                onPressed: onDisconnect,
              )
            : Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
      ),
    );
  }
}
