import 'package:flutter/material.dart';

import 'app.dart';
import 'core/preferences.dart';

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
  runApp(ThrowApp(preferences: preferences));
}
