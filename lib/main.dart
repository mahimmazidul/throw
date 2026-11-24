import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/preferences.dart';
import 'core/temp_files.dart';

/// Throw entry point.
///
/// Fonts ship in `assets/fonts`, so runtime fetching is disabled — the app
/// must render correctly with no network, ever.
///
/// Preferences are loaded *before* the first frame so the saved language and
/// theme are the ones painted, rather than a dark flash that settles into the
/// user's choice a frame later.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await AppPreferences.load();
  final tempFiles = TempFileRegistry();
  unawaited(_reclaimTemporarySpace(tempFiles));
  runApp(ThrowApp(preferences: preferences, tempFiles: tempFiles));
}

/// Deletes every temporary copy left behind by a previous run.
///
/// Nothing can be mid-transfer before the app has started, so anything still
/// registered is debris — a cached share whose send failed, a pick that was
/// never sent, or an entry from a version that did not clean up at all. This
/// is what returns the space to a user who upgrades from a build that leaked,
/// without them having to clear app data.
///
/// Runs after `runApp`'s first frame is scheduled and swallows its own errors:
/// failing to reclaim space must never stop the app from opening.
Future<void> _reclaimTemporarySpace(TempFileRegistry tempFiles) async {
  try {
    await tempFiles.releaseEverything();
    // The File Picker keeps its own cache outside our registry, and its
    // `clearTemporaryFiles` was never called by earlier builds.
    if (Platform.isAndroid || Platform.isIOS) {
      await tempFiles.clearPickerCache();
    } else {
      // On desktop the picker hands back the user's real path rather than a
      // copy, so its cache dir is normally absent; clearing it is harmless and
      // covers the case where a plugin did copy.
      final cache = await getTemporaryDirectory();
      final dir = Directory('${cache.path}/file_picker');
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  } catch (_) {
    // Space reclamation is best-effort by definition.
  }
}
