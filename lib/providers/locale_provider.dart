import 'package:flutter/material.dart';

import '../core/preferences.dart';

/// Manages the active app [Locale] and [ThemeMode], persisted across launches.
///
/// Both values used to live in memory only: closing Throw reset the language
/// to English and the theme to dark, which reads as a broken toggle. [restore]
/// reads the saved pair at startup; every setter writes straight through.
class LocaleProvider extends ChangeNotifier {
  LocaleProvider({AppPreferences? preferences})
      : _preferences = preferences ?? AppPreferences.inMemory();

  final AppPreferences _preferences;

  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.dark;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('bn'),
  ];

  /// Applies the values saved by a previous run, if any. Unknown or corrupt
  /// values fall back to the defaults instead of throwing.
  void restore() {
    final code = _preferences.localeCode;
    if (code != null) {
      final saved = Locale(code);
      if (supportedLocales.contains(saved)) _locale = saved;
    }

    final modeIndex = _preferences.themeModeIndex;
    if (modeIndex != null &&
        modeIndex >= 0 &&
        modeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[modeIndex];
    }
    notifyListeners();
  }

  void setLocale(Locale locale) {
    if (!supportedLocales.contains(locale) || _locale == locale) return;
    _locale = locale;
    notifyListeners();
    _preferences.setLocaleCode(locale.languageCode);
  }

  void toggleLocale() {
    setLocale(
      _locale.languageCode == 'en' ? const Locale('bn') : const Locale('en'),
    );
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    _preferences.setThemeModeIndex(mode.index);
  }
}
