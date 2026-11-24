import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/device_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/transfer_provider.dart';
import 'screens/discover_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/transfer_screen.dart';
import 'widgets/adaptive_nav.dart';

class ThrowApp extends StatelessWidget {
  const ThrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => TransferProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'Throw',
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
    );
  }
}
