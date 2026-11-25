import 'package:flutter/material.dart';

import '../core/motion.dart';

import '../core/theme.dart';

import '../core/breakpoints.dart';
import '../l10n/app_localizations.dart';

/// Adaptive navigation shell: bottom navigation bar on compact screens,
/// navigation rail on medium/expanded, and permanent drawer on large+.
class AdaptiveNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  const AdaptiveNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final size = Breakpoints.of(width);

    final destinations = [
      (icon: Icons.home_rounded, activeIcon: Icons.home, label: l10n.navHome),
      (
        icon: Icons.radar_rounded,
        activeIcon: Icons.radar,
        label: l10n.navDiscover
      ),
      (
        icon: Icons.sync_alt_rounded,
        activeIcon: Icons.swap_horiz,
        label: l10n.navTransfers
      ),
      (
        icon: Icons.tune_rounded,
        activeIcon: Icons.settings,
        label: l10n.navSettings
      ),
    ];

    if (size == ScreenClass.compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations
              .map(
                (d) => NavigationDestination(
                  icon: _NavIcon(icon: d.icon),
                  selectedIcon: _NavIcon(icon: d.activeIcon, selected: true),
                  label: d.label,
                ),
              )
              .toList(),
        ),
      );
    }

    final extended = Breakpoints.hasPermanentSidebar(width);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: theme.colorScheme.surface,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: ClipRRect(
                borderRadius: ThrowRadius.button,
                child: Image.asset('assets/logo.png', width: 36, height: 36),
              ),
            ),
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: _NavIcon(icon: d.icon),
                    selectedIcon: _NavIcon(icon: d.activeIcon, selected: true),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// A destination icon that reacts to being selected.
///
/// Stock `NavigationBar` swaps one icon for another instantly, which on a
/// desktop rail reads as a flicker rather than a selection. iOS never hard-cuts
/// a selected control: the glyph grows slightly and settles. 1.08 over 180 ms
/// with the same overshoot curve the buttons use is enough to make the change
/// legible without drawing attention to itself.
class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, this.selected = false});

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final reduce = Motion.reduceMotion(context);
    return AnimatedScale(
      scale: selected && !reduce ? 1.08 : 1.0,
      duration: reduce ? Duration.zero : Motion.pressOut,
      curve: Motion.releaseCurve,
      child: Icon(icon),
    );
  }
}
