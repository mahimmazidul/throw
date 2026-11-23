import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';

/// Root widget: localization, theming, and the bootstrap shell.
class ThrowApp extends StatelessWidget {
  const ThrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Throw',
      debugShowCheckedModeBanner: false,
      // Dark first; light follows the system when the user asks for it.
      theme: ThrowTheme.light(),
      darkTheme: ThrowTheme.dark(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('bn'),
      ],
      home: const _BootstrapShell(),
    );
  }
}

/// Placeholder home until the home screen lands — proves l10n + theme work.
class _BootstrapShell extends StatelessWidget {
  const _BootstrapShell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.appTitle, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              l10n.tagline,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
