import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/motion.dart';
import '../core/temp_files.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../l10n/app_localizations.dart';
import '../models/app_error.dart';
import '../providers/device_provider.dart';
import '../providers/locale_provider.dart';
import '../services/update_service.dart';
import '../widgets/depth_button.dart';
import '../widgets/entrance.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';
import '../widgets/storage_row.dart';
import 'about_screen.dart';

/// Settings: three flat sections on the canvas — this device, appearance,
/// about. Every row is a hairline apart; no surface is drawn.
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.pop(context, value),
              decoration: InputDecoration(
                hintText: l10n.settingsNameHint,
                border: OutlineInputBorder(borderRadius: ThrowRadius.button),
              ),
            ),
            const SizedBox(height: AppConstants.space3),
            Text(
              l10n.settingsDeviceNameHelp,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          Pressable(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.actionCancel),
            ),
          ),
          Pressable(
            child: DepthButton(
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

  /// Opens the update check. The check itself lives in [_UpdateCheckTile],
  /// which owns the in-flight guard; this only hands it a context.
  void _checkForUpdates(BuildContext context) => runUpdateCheck(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final deviceProvider = context.watch<DeviceProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isDark = localeProvider.themeMode == ThemeMode.dark;
    final isBangla = localeProvider.locale.languageCode == 'bn';

    return SafeArea(
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
                    title: l10n.navSettings,
                    subtitle: l10n.settingsSubtitle,
                  ),
                  const SizedBox(height: AppConstants.space5),
                  Section(
                    header: l10n.settingsThisDevice,
                    children: [
                      FlatRow(
                        leading: const Icon(Icons.badge_outlined),
                        title: l10n.settingsDeviceName,
                        subtitle: deviceProvider.deviceName,
                        trailingText: l10n.settingsEditName,
                        onTap: () =>
                            _editDeviceName(context, deviceProvider, l10n),
                      ),
                      FlatRow(
                        leading: const Icon(Icons.tune_rounded),
                        title: l10n.settingsCheckUpdates,
                        subtitle: l10n.settingsCurrentVersion(
                          AppConstants.appVersion,
                        ),
                        trailing:
                            const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => _checkForUpdates(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space5),
                  Section(
                    header: l10n.settingsAppearanceSection,
                    children: [
                      FlatRow(
                        leading: const Icon(Icons.language_rounded),
                        title: l10n.settingsLanguage,
                        subtitle: isBangla
                            ? l10n.languageBangla
                            : l10n.languageEnglish,
                        trailing:
                            const Icon(Icons.swap_horiz_rounded, size: 20),
                        onTap: localeProvider.toggleLocale,
                      ),
                      FlatRow(
                        leading: const Icon(Icons.dark_mode_outlined),
                        title: l10n.settingsTheme,
                        subtitle: isDark ? l10n.themeDark : l10n.themeLight,
                        trailing: Pressable(
                          child: Switch(
                            value: isDark,
                            onChanged: (value) => localeProvider.setThemeMode(
                              value ? ThemeMode.dark : ThemeMode.light,
                            ),
                          ),
                        ),
                        onTap: () => localeProvider.setThemeMode(
                          isDark ? ThemeMode.light : ThemeMode.dark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space5),
                  Section(
                    header: l10n.settingsStorageSection,
                    children: [
                      Provider<TempFileRegistry>.value(
                        value: context.read<TempFileRegistry>(),
                        child: const StorageRow(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.space5),
                  Section(
                    header: l10n.settingsAboutSection,
                    children: [
                      FlatRow(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: l10n.settingsAboutOpen,
                        subtitle: l10n.settingsAboutSummary,
                        trailing:
                            const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AboutScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runs an update check and reports the result.
///
/// No re-entry guard is needed: the progress dialog uses a non-dismissible
/// barrier, which absorbs every tap until it is popped, so a second check
/// cannot be started while one is in flight.
Future<void> runUpdateCheck(BuildContext context) async {
    final service = UpdateService();
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UpdateCheckingDialog(),
    );

    final result = await service.check();

    if (!context.mounted) return;
    // Dismiss the progress dialog and wait for it to actually go, so the
    // result is never shown behind a lingering barrier.
    Navigator.of(context, rootNavigator: true).pop();
    await dialog;
    if (!context.mounted) return;

    final release = result.release;
    if (release == null) {
      // Classified, never stringified: no `SocketException` reaches the user.
      final code = switch (result.failure) {
        UpdateFailure.offline => AppErrorCode.offline,
        _ => AppErrorCode.updateFailed,
      };
      messenger.showSnackBar(
        SnackBar(content: Text(describeError(AppError(code), l10n))),
      );
      return;
    }

    const current = AppConstants.appVersion;
    if (AppUtils.isNewerVersion(release.version, current)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.updateAvailableTitle),
          content: Text(l10n.updateAvailableBody(current, release.tag)),
          actions: [
            Pressable(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.actionLater),
              ),
            ),
            Pressable(
              child: DepthButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await launchUrl(
                    Uri.parse(release.url),
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(l10n.actionOpenRelease),
              ),
            ),
          ],
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.updateUpToDate(current)),
          backgroundColor: theme.colorScheme.surfaceContainerHigh,
        ),
      );
    }
  }


/// The blocking progress dialog shown while a check is in flight.
class _UpdateCheckingDialog extends StatelessWidget {
  const _UpdateCheckingDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
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
    );
  }
}
