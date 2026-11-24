import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _checkForUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            SizedBox(width: 16),
            Expanded(child: Text('Checking for updates...')),
          ],
        ),
      ),
    );

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(
        'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest',
      ));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'Throw-App');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode != 200) {
        throw Exception('GitHub returned ${response.statusCode}');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final latestTag = (json['tag_name'] as String? ?? '').trim();
      final latest = latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;
      final current = AppConstants.appVersion;
      final hasUpdate = _isNewerVersion(latest, current);

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;

      if (hasUpdate) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Update available'),
            content: Text('Current: v$current\nLatest: $latestTag\n\nA newer version of Throw is available.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(json['html_url'] as String? ?? AppConstants.releasesUrl);
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: const Text('Open release'),
              ),
            ],
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('You are up to date (v$current).'),
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not check updates: $e')),
      );
    }
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> parse(String v) => v
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9].*$'), '')) ?? 0)
        .toList();
    final l = parse(latest);
    final c = parse(current);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
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
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your device, language, and appearance.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(l10n.settingsDeviceName),
                  subtitle: Text(deviceProvider.deviceName),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _editDeviceName(context, deviceProvider, l10n),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l10n.settingsLanguage),
                  subtitle: Text(
                    localeProvider.locale.languageCode == 'bn' ? 'বাংলা' : 'English',
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
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.system_update_rounded),
                  title: const Text('Check for updates'),
                  subtitle: Text('Current version: v${AppConstants.appVersion}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _checkForUpdates(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(l10n.settingsAbout),
                  subtitle: const Text('Throw v1.0.10 • Offline file sharing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
