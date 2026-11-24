import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/device_model.dart';
import 'accent_icon_badge.dart';

/// Peer-first target selection for the Home screen.
///
/// The old Home screen made the peer a `DropdownButtonFormField`: hidden behind
/// a tap, one peer visible at a time, no connection state, and it fought
/// `DeviceModel`'s identity-by-id equality inside a form field. Every sharing
/// app worth comparing against — LocalSend's device grid, Android's share
/// sheet — makes the peer the first object on screen. This is the compact,
/// horizontal version of that idea: one tap per peer, state visible at rest,
/// wrapping to as many rows as the window needs.
class DevicePicker extends StatelessWidget {
  const DevicePicker({
    super.key,
    required this.devices,
    required this.selected,
    required this.onSelected,
  });

  /// Connected peers only — sending to a disconnected device cannot work.
  final List<DeviceModel> devices;

  final DeviceModel? selected;
  final ValueChanged<DeviceModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.stateConnected,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppConstants.space2),
        Wrap(
          spacing: AppConstants.space2,
          runSpacing: AppConstants.space2,
          children: [
            for (final device in devices)
              _DevicePill(
                device: device,
                isSelected: selected?.id == device.id,
                onTap: () => onSelected(device),
              ),
          ],
        ),
      ],
    );
  }
}

class _DevicePill extends StatelessWidget {
  const _DevicePill({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  final DeviceModel device;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _platformIcon => switch (device.platform) {
        DevicePlatform.android => Icons.phone_android_rounded,
        DevicePlatform.windows => Icons.desktop_windows_rounded,
        DevicePlatform.linux => Icons.laptop_mac_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: device.name,
      child: Material(
        color: isSelected ? cs.primary : cs.surfaceContainerHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            // 48dp minimum target, per AppConstants.touchTargetMin.
            constraints: const BoxConstraints(minHeight: AppConstants.space7),
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.space4,
              vertical: AppConstants.space2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _platformIcon,
                  size: 18,
                  color:
                      isSelected ? cs.onPrimary : ThrowTheme.accentFg(context),
                ),
                const SizedBox(width: AppConstants.space2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected ? cs.onPrimary : cs.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: AppConstants.space2),
                  Icon(Icons.check_rounded, size: 16, color: cs.onPrimary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown in Home's send cards while no peer is selected: a quiet hint instead
/// of four greyed-out buttons with no explanation.
class NoPeerHint extends StatelessWidget {
  const NoPeerHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.space4,
        vertical: AppConstants.space3,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: ThrowRadius.card,
      ),
      child: Row(
        children: [
          const AccentIconBadge(icon: Icons.touch_app_rounded, size: 32),
          const SizedBox(width: AppConstants.space3),
          Expanded(
            child: Text(
              l10n.homePickDeviceFirst,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
