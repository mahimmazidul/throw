import 'package:flutter/material.dart';

/// Manages the active app [Locale] and [ThemeMode].
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.dark;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('bn'),
  ];

  void setLocale(Locale locale) {
    if (!supportedLocales.contains(locale) || _locale == locale) return;
    _locale = locale;
    notifyListeners();
  }

  void toggleLocale() {
    _locale = _locale.languageCode == 'en'
        ? const Locale('bn')
        : const Locale('en');
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}
