import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/preferences.dart';
import 'core/temp_files.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/device_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/share_inbox_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfer_screen.dart';
import 'widgets/adaptive_nav.dart';
import 'widgets/swipeable_tabs.dart';

class ThrowApp extends StatelessWidget {
  const ThrowApp({super.key, this.preferences, this.tempFiles});

  /// Injected by `main()` after loading the platform store; `null` keeps an
  /// in-memory store so tests and previews run without plugins.
  final AppPreferences? preferences;

  /// Owns deletion of temporary copies. Injected so tests can point it at a
  /// temp directory instead of the real cache.
  final TempFileRegistry? tempFiles;

  @override
  Widget build(BuildContext context) {
    final prefs = preferences ?? AppPreferences.inMemory();
    final temp = tempFiles ?? TempFileRegistry();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => LocaleProvider(preferences: prefs)..restore()),
        ChangeNotifierProvider(
          create: (_) => DeviceProvider(preferences: prefs),
        ),
        Provider<TempFileRegistry>.value(value: temp),
        ChangeNotifierProvider(
          create: (_) => TransferProvider(tempFiles: temp),
        ),
        ChangeNotifierProvider(
            create: (_) => ShareInboxProvider(tempFiles: temp)..initialize()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            // The OS task switcher can be in a different language than the
            // in-app UI; onGenerateTitle runs inside the l10n scope so the
            // label follows the user's choice instead of the hardcoded brand.
            onGenerateTitle: (context) =>
                AppLocalizations.of(context)!.appTitle,
            debugShowCheckedModeBanner: false,
            theme: ThrowTheme.light(),
            darkTheme: ThrowTheme.dark(),
            themeMode: localeProvider.themeMode,
            locale: localeProvider.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const _MainShell(),
          );
        },
      ),
    );
  }
}

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: a runtime permission dialog
    // interrupting the very first paint looks like a crash to a new user.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeviceProvider>().autoStart();
    });
  }

  static const List<Widget> _screens = [
    HomeScreen(),
    DiscoverScreen(),
    TransferScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveNav(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
      },
      // Same keep-alive guarantee as the IndexedStack it replaces, plus the
      // horizontal gesture. Swiping is on at every size: every screen scrolls
      // vertically, so a horizontal drag has nothing else to claim, and a
      // desktop user with a trackpad expects the same gesture as a phone user.
      body: SwipeableTabs(
        index: _selectedIndex,
        onChanged: (index) => setState(() => _selectedIndex = index),
        children: _screens,
      ),
    );
  }
}
