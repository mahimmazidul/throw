import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/entrance.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';

/// Settings, grouped the way the references group it: a run of flush rows on
/// one tinted surface per section, not one bordered card per pair of rows.
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
          Pressable(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel),
            ),
          ),
          Pressable(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(l10n.actionAccept),
            ),
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
              Pressable(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.actionLater),
                ),
              ),
              Pressable(
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final uri = Uri.parse(
                      json['html_url'] as String? ?? AppConstants.releasesUrl,
                    );
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(l10n.actionOpenRelease),
                ),
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
                title: l10n.navSettings,
                subtitle: l10n.settingsSubtitle,
              ),
              const SizedBox(height: AppConstants.space5),
              PanelGroup(
                header: l10n.settingsThisDevice,
                children: [
                  FlatRow(
                    leading: const Icon(Icons.badge_outlined),
                    title: l10n.settingsDeviceName,
                    subtitle: deviceProvider.deviceName,
                    trailingText: l10n.settingsEditName,
                    onTap: () => _editDeviceName(context, deviceProvider, l10n),
                  ),
                  FlatRow(
                    leading: const Icon(Icons.language_rounded),
                    title: l10n.settingsLanguage,
                    subtitle: localeProvider.locale.languageCode == 'bn'
                        ? 'বাংলা'
                        : 'English',
                    trailing: Pressable(
                      child: IconButton(
                        icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                        tooltip: l10n.settingsLanguage,
                        onPressed: localeProvider.toggleLocale,
                      ),
                    ),
                    onTap: localeProvider.toggleLocale,
                  ),
                  FlatRow(
                    leading: const Icon(Icons.dark_mode_outlined),
                    title: l10n.settingsTheme,
                    subtitle: isDark ? 'Dark' : 'Light',
                    onTap: () => localeProvider.setThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    ),
                    trailing: Pressable(
                      child: Switch(
                        value: isDark,
                        onChanged: (value) => localeProvider.setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.space4),
              PanelGroup(
                header: l10n.settingsAbout,
                children: [
                  FlatRow(
                    leading: const Icon(Icons.system_update_rounded),
                    title: l10n.settingsCheckUpdates,
                    subtitle:
                        l10n.settingsCurrentVersion(AppConstants.appVersion),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => _checkForUpdates(context),
                  ),
                  // The version is already in the subtitle; a trailing copy
                  // of the same string was pure noise.
                  FlatRow(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: l10n.settingsAbout,
                    subtitle: l10n.settingsAboutBody(AppConstants.appVersion),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
