import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/device_model.dart';

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
          l10n.stateConnected.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppConstants.space2),
        Wrap(
          spacing: AppConstants.space2,
          runSpacing: AppConstants.space2,
          children: [
            for (final device in devices)
              Pressable(
                child: _DevicePill(
                  device: device,
                  isSelected: selected?.id == device.id,
                  onTap: () => onSelected(device),
                ),
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
      child: GestureDetector(
        onTap: onTap,
        // IntrinsicWidth, not the bare container: with `alignment` set a
        // container grows to fill the incoming constraints, so a lone pill
        // became a full-width button and two peers would stack full-width.
        // Intrinsic sizing keeps each pill as wide as its label.
        child: IntrinsicWidth(
          child: AnimatedContainer(
            duration: Motion.adapt(context, Motion.standard),
            curve: Motion.curve,
            // Without an explicit alignment the container shrink-wraps its child
            // and the minHeight below is silently ignored — the pill ended up
            // ~36dp tall in the render. The test that asserts 48dp catches it.
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.surfaceContainerHigh,
              borderRadius: ThrowRadius.chip,
            ),
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
                AnimatedSize(
                  duration: Motion.adapt(context, Motion.standard),
                  curve: Motion.curve,
                  child: isSelected
                      ? Padding(
                          padding: const EdgeInsets.only(
                            left: AppConstants.space2,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: cs.onPrimary,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown above the send panel while nothing is connected: one quiet line of
/// guidance instead of a container apologising for empty space.
class NoPeerHint extends StatelessWidget {
  const NoPeerHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.devices_other_rounded,
          size: 18,
          color: ThrowTheme.accentFg(context),
        ),
        const SizedBox(width: AppConstants.space2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeNoPeersTitle,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Text(
                l10n.homeNoPeersBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
