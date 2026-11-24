import 'package:shared_preferences/shared_preferences.dart';

/// Small typed wrapper over [SharedPreferences] for the handful of settings
/// Throw keeps between launches: language, theme, and the advertised device
/// name.
///
/// The previous revision kept these in memory only, so every relaunch reset
/// the user's language, theme, and device name — a toggle that forgets itself
/// teaches people the toggle is broken.
///
/// [AppPreferences.inMemory] exists for tests and for the rare case where the
/// platform store is unavailable: the app must never fail to start because a
/// preference could not be read.
class AppPreferences {
  AppPreferences._(this._prefs);

  /// A store that persists nothing. Default for tests and as a fallback.
  factory AppPreferences.inMemory() => AppPreferences._(null);

  static const String _kLocale = 'locale';
  static const String _kThemeMode = 'themeMode';
  static const String _kDeviceName = 'deviceName';

  final SharedPreferences? _prefs;

  /// Loads the platform store. Falls back to [inMemory] instead of throwing so
  /// a broken keystore/registry never blocks startup.
  static Future<AppPreferences> load() async {
    try {
      return AppPreferences._(await SharedPreferences.getInstance());
    } catch (_) {
      return AppPreferences.inMemory();
    }
  }

  /// Two-letter language code, or `null` when the user never chose one.
  String? get localeCode => _prefs?.getString(_kLocale);

  /// [ThemeMode.index] of the saved mode, or `null` when unset.
  int? get themeModeIndex => _prefs?.getInt(_kThemeMode);

  /// Saved device name, or `null` when the user never renamed this device.
  String? get deviceName => _prefs?.getString(_kDeviceName);

  Future<void> setLocaleCode(String code) async {
    await _prefs?.setString(_kLocale, code);
  }

  Future<void> setThemeModeIndex(int index) async {
    await _prefs?.setInt(_kThemeMode, index);
  }

  Future<void> setDeviceName(String name) async {
    await _prefs?.setString(_kDeviceName, name);
  }
}
