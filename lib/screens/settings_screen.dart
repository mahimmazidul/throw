import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/screen_header.dart';

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
        shape: const RoundedRectangleBorder(borderRadius: ThrowRadius.card),
        title: Text(l10n.settingsDeviceName),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: ThrowRadius.card),
          ),
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
    final l10n = AppLocalizations.of(context)!;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: ThrowRadius.card),
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.updateChecking)),
          ],
        ),
      ),
    ));

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(
        'https://api.github.com/repos/${AppConstants.githubRepo}/releases/latest',
      ));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'Throw-App');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);

      if (response.statusCode != 200) {
        throw Exception('GitHub returned ${response.statusCode}');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      final latestTag = (json['tag_name'] as String? ?? '').trim();
      final latest =
          latestTag.startsWith('v') ? latestTag.substring(1) : latestTag;
      const current = AppConstants.appVersion;
      final hasUpdate = AppUtils.isNewerVersion(latest, current);

      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;

      if (hasUpdate) {
        unawaited(showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: ThrowRadius.card),
            title: Text(l10n.updateAvailableTitle),
            content: Text(l10n.updateAvailableBody(current, latestTag)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.actionLater),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                    json['html_url'] as String? ?? AppConstants.releasesUrl,
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Text(l10n.actionOpenRelease),
              ),
            ],
          ),
        ));
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.updateUpToDate(current)),
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.updateFailed(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final deviceProvider = context.watch<DeviceProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isDark = localeProvider.themeMode == ThemeMode.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.space5),
        children: [
          ScreenHeader(
            title: l10n.navSettings,
            subtitle: l10n.settingsSubtitle,
          ),
          const SizedBox(height: AppConstants.space5),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(l10n.settingsDeviceName),
                subtitle: Text(deviceProvider.deviceName),
                trailing: Text(
                  l10n.settingsEditName,
                  style: TextStyle(
                    color: ThrowTheme.accentFg(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                trailing: const Icon(Icons.swap_horiz_rounded),
                onTap: localeProvider.toggleLocale,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.settingsTheme),
                subtitle: Text(isDark ? 'Dark' : 'Light'),
                value: isDark,
                onChanged: (value) => localeProvider.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space4),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.system_update_rounded),
                title: Text(l10n.settingsCheckUpdates),
                subtitle: Text(
                  l10n.settingsCurrentVersion(AppConstants.appVersion),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _checkForUpdates(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l10n.settingsAbout),
                subtitle: Text(
                  l10n.settingsAboutBody(AppConstants.appVersion),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card that clips its first and last [ListTile] to the shared 28dp radius.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
