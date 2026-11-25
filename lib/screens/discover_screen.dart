import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/atmosphere.dart';
import '../core/constants.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../providers/device_provider.dart';
import '../widgets/depth_button.dart';
import '../widgets/entrance.dart';
import '../widgets/error_banner.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';

/// Discover: find the other device, and decide whether it can find you.
///
/// The two switches are separate on purpose. Before, "Scan" and "Make visible"
/// were one button whose label flipped, so the user could not tell whether the
/// other phone would be able to see them at the same time as looking.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final provider = context.watch<DeviceProvider>();
    final devices = provider.devices;
    final connected = devices.where((d) => d.isConnected).toList();
    final nearby = devices.where((d) => !d.isConnected).toList();

    return AmbientBackdrop(
      child: SafeArea(
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
                    title: l10n.navDiscover,
                    subtitle: provider.isDiscovering
                        ? l10n.discoverScanningHint
                        : l10n.discoverIdleHint,
                  ),
                  const SizedBox(height: AppConstants.space5),

                  // Both switches, one section, no surface.
                  Section(
                    header: l10n.settingsThisDevice,
                    children: [
                      FlatRow(
                        leading: const Icon(Icons.wifi_tethering_rounded),
                        title: l10n.discoverVisibleSwitch,
                        subtitle: provider.isAdvertising
                            ? l10n.visibleAs(provider.deviceName)
                            : l10n.makeVisible,
                        trailing: Pressable(
                          child: Switch(
                            value: provider.isAdvertising,
                            onChanged: (value) => value
                                ? provider.startAdvertising()
                                : provider.stopAdvertising(),
                          ),
                        ),
                        onTap: () => provider.isAdvertising
                            ? provider.stopAdvertising()
                            : provider.startAdvertising(),
                      ),
                      FlatRow(
                        // The radar row is the only place in the app that says
                        // "still looking" with nothing to show. The pulse makes
                        // that legible at a glance — and it stops the instant a
                        // device appears or the scan is switched off, so motion
                        // always means work in progress.
                        leading: RadarPulse(
                          active: provider.isDiscovering,
                          child: const Icon(Icons.radar_rounded),
                        ),
                        title: l10n.discoverFindingSwitch,
                        subtitle: provider.isDiscovering
                            ? l10n.stateSearching
                            : l10n.discoverIdleHint,
                        trailing: Pressable(
                          child: Switch(
                            value: provider.isDiscovering,
                            onChanged: (value) => value
                                ? provider.startDiscovery()
                                : provider.stopDiscovery(),
                          ),
                        ),
                        onTap: () => provider.isDiscovering
                            ? provider.stopDiscovery()
                            : provider.startDiscovery(),
                      ),
                    ],
                  ),

                  if (provider.error != null) ...[
                    const SizedBox(height: AppConstants.space4),
                    ErrorBanner(
                      error: provider.error!,
                      onDismiss: provider.clearError,
                    ),
                  ],

                  if (provider.pendingRequests.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.space5),
                    Section(
                      header: l10n.incomingTitle,
                      children: [
                        for (final req in provider.pendingRequests)
                          _ConnectionRequestRow(
                            title: l10n.incomingFrom(req.displayName),
                            acceptLabel: l10n.actionAccept,
                            rejectLabel: l10n.actionReject,
                            onAccept: () => provider.acceptConnection(req),
                            onReject: () => provider.rejectConnection(req),
                          ),
                      ],
                    ),
                  ],

                  if (connected.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.space5),
                    Section(
                      header: l10n.stateConnected,
                      children: [
                        for (final device in connected)
                          _DeviceRow(
                            device: device,
                            onTap: () => provider.disconnect(device),
                            trailingLabel: l10n.disconnectFrom,
                            connected: true,
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppConstants.space5),
                  // The single most-asked question about this app: does it
                  // need a WiFi network, and does it hijack my WiFi? Stated
                  // once, here, rather than repeated on every device row.
                  if (nearby.isNotEmpty || provider.isDiscovering) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppConstants.space3,
                      ),
                      child: Text(
                        l10n.transportNoteWifi,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                  if (nearby.isEmpty && !provider.isDiscovering)
                    // No `header` here: the row's own title already says "No
                    // devices nearby yet", and a heading repeating it directly
                    // above was the kind of duplicate the last round set out to
                    // remove.
                    Section(
                      children: [
                        FlatRow(
                          leading: const Icon(Icons.radar_rounded),
                          title: l10n.stateNoDevices,
                          subtitle: l10n.discoverIdleHint,
                          titleMaxLines: 2,
                          subtitleMaxLines: 2,
                        ),
                      ],
                    )
                  else if (nearby.isNotEmpty)
                    Section(
                      header: l10n.devicesFoundCount(nearby.length),
                      children: [
                        for (final device in nearby)
                          _DeviceRow(
                            device: device,
                            onTap: () => provider.connect(device),
                            trailingLabel: l10n.connectTo,
                            connected: false,
                          ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppConstants.space5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: AppConstants.space3),
                          Flexible(
                            child: Text(
                              l10n.stateSearching,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.onTap,
    required this.trailingLabel,
    required this.connected,
  });

  final DeviceModel device;
  final VoidCallback onTap;
  final String trailingLabel;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return FlatRow(
      leading: Icon(switch (device.platform) {
        DevicePlatform.android => Icons.phone_android_rounded,
        DevicePlatform.windows => Icons.desktop_windows_rounded,
        DevicePlatform.linux => Icons.laptop_mac_rounded,
        DevicePlatform.unknown => Icons.devices_other_rounded,
      }),
      title: device.displayName,
      subtitle: device.channel == TransferChannel.wifiDirect
          ? AppLocalizations.of(context)!.speedWifi
          : AppLocalizations.of(context)!.speedBluetooth,
      trailingText: trailingLabel,
      onTap: onTap,
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
    return FlatRow(
      leading: const Icon(Icons.link_rounded),
      title: title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            child: TextButton(
              onPressed: onReject,
              child: Text(rejectLabel),
            ),
          ),
          const SizedBox(width: AppConstants.space1),
          Pressable(
            child: DepthButton(
              onPressed: onAccept,
              child: Text(acceptLabel),
            ),
          ),
        ],
      ),
    );
  }
}
