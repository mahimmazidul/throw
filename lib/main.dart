import 'package:flutter/material.dart';
import 'app.dart';

/// Throw entry point.
///
/// Fonts ship in `assets/fonts`, so runtime fetching is disabled — the app
/// must render correctly with no network, ever.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ThrowApp());
}
