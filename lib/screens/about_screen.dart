import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/entrance.dart';
import '../widgets/panel.dart';
import '../widgets/screen_header.dart';

/// About: what the app is, who made it, and every real link for it.
///
/// The 1.1 build had an "About" row whose subtitle repeated the version already
/// shown one row above, and no developer or contact information anywhere. This
/// screen is the one place a person looks when they want to know who to thank,
/// who to complain to, or where the source is.
///
/// Every link below is real and resolves; no invented handles.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.openLinkFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aboutTitle),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.space5,
          AppConstants.space2,
          AppConstants.space5,
          AppConstants.space6,
        ),
        children: [
          StaggeredEntrance(
            children: [
              ScreenHeader(
                title: l10n.appTitle,
                subtitle: l10n.aboutVersion(
                  AppConstants.appVersion,
                  AppConstants.appBuild,
                ),
              ),
              const SizedBox(height: AppConstants.space3),
              Text(
                l10n.aboutWhatItIs,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant, height: 1.55),
              ),
              const SizedBox(height: AppConstants.space5),

              Section(
                header: l10n.developerSection,
                children: [
                  FlatRow(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: l10n.developerName,
                    subtitle: l10n.developerRole,
                    titleMaxLines: 1,
                  ),
                  FlatRow(
                    leading: const Icon(Icons.place_outlined),
                    title: l10n.developerLocation,
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.space5),

              Section(
                header: l10n.linksSection,
                children: [
                  FlatRow(
                    leading: const Icon(Icons.code_rounded),
                    title: l10n.linkGithub,
                    subtitle: AppConstants.developerHandle,
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(context, AppConstants.developerGithubUrl),
                  ),
                  FlatRow(
                    leading: const Icon(Icons.public_rounded),
                    title: l10n.linkWebsite,
                    subtitle: AppConstants.developerDomain,
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(context, AppConstants.developerWebsiteUrl),
                  ),
                  FlatRow(
                    leading: const Icon(Icons.folder_open_rounded),
                    title: l10n.linkRepository,
                    subtitle: AppConstants.githubRepo,
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(context, AppConstants.repoUrl),
                  ),
                  FlatRow(
                    leading: const Icon(Icons.tune_rounded),
                    title: l10n.linkReleases,
                    subtitle: AppConstants.versionTag,
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(context, AppConstants.releasesUrl),
                  ),
                  FlatRow(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: l10n.linkIssues,
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(context, AppConstants.issuesUrl),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.space5),

              Section(
                header: l10n.legalSection,
                footer: l10n.aboutCredits,
                children: [
                  FlatRow(
                    leading: const Icon(Icons.gavel_rounded),
                    title: l10n.linkLicense,
                    subtitle: l10n.licenseName,
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: () => _open(context, AppConstants.licenseUrl),
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
