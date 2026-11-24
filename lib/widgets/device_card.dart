import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';

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
        return Icons.phone_android_rounded;
      case DevicePlatform.windows:
        return Icons.desktop_windows_rounded;
      case DevicePlatform.linux:
        return Icons.laptop_mac_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final transportLabel = device.channel == TransferChannel.wifiDirect
        ? l10n.speedWifi
        : l10n.speedBluetooth;

    return Pressable(
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: ThrowRadius.card,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: const RoundedRectangleBorder(borderRadius: ThrowRadius.card),
          onTap: onTap,
          leading: Icon(
            _platformIcon(device.platform),
            size: 26,
            color: device.isConnected
                ? ThrowTheme.accentFg(context)
                : colorScheme.onSurfaceVariant,
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
              ? Pressable(
                  child: IconButton(
                    icon: const Icon(Icons.link_off_rounded),
                    tooltip: l10n.actionClose,
                    onPressed: onDisconnect,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // An always-visible dot: connected reads at a glance down
                    // the list, the same way LocalSend's favourite check does.
                    AnimatedContainer(
                      duration: Motion.adapt(context, Motion.standard),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: device.isConnected
                            ? ThrowTheme.accentFg(context)
                            : colorScheme.outlineVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
