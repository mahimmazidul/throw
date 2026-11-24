import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';

/// Settings screen for device name, language, theme, and app info.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _editDeviceName(
    BuildContext context,
    DeviceProvider deviceProvider,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController(text: deviceProvider.deviceName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsDeviceName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(l10n.actionAccept),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      deviceProvider.setDeviceName(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final deviceProvider = context.watch<DeviceProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.navSettings,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(l10n.settingsDeviceName),
                  subtitle: Text(deviceProvider.deviceName),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () =>
                      _editDeviceName(context, deviceProvider, l10n),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l10n.settingsLanguage),
                  subtitle: Text(
                    localeProvider.locale.languageCode == 'bn'
                        ? 'বাংলা'
                        : 'English',
                  ),
                  onTap: localeProvider.toggleLocale,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.dark_mode_outlined),
                  title: Text(l10n.settingsTheme),
                  value: localeProvider.themeMode == ThemeMode.dark,
                  onChanged: (isDark) => localeProvider.setThemeMode(
                    isDark ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(l10n.settingsAbout),
              subtitle: const Text(
                '${AppConstants.appName} v${AppConstants.appVersion}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
