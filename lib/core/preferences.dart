import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small typed store for the handful of settings Throw keeps between launches:
/// language, theme, and the advertised device name.
///
/// This is deliberately a JSON file rather than `shared_preferences`.
/// `shared_preferences_android` declares compileSdk 36 and pulls in
/// `androidx.jni`, whose AAR metadata requires consumers to compile against
/// API 37 — but `bluetooth_low_energy_android` (the desktop/BLE plugin) does
/// not compile at 37, because API 37 made `BluetoothLeScanner` and
/// `BluetoothLeAdvertiser` nullable and its Kotlin stops type-checking. Those
/// two requirements cannot both be met, so the Android-side dependency is gone
/// and three keys live in a file instead. Fewer plugins, one less platform
/// channel, and nothing to reconcile at Gradle level.
///
/// [AppPreferences.inMemory] exists for tests and for the case where the file
/// store is unavailable: the app must never fail to start because a preference
/// could not be read.
class AppPreferences {
  AppPreferences._(this._store);

  /// The backing store. An in-memory map when no file could be opened — a
  /// value written and read back within one run still behaves, which is what
  /// tests and the file-unavailable fallback both need. Before this was
  /// nullable, `inMemory()` silently discarded every write, so a test could
  /// not tell a working preference path from a broken one.
  final _Store _store;

  static const String _kLocale = 'locale';
  static const String _kThemeMode = 'themeMode';
  static const String _kDeviceName = 'deviceName';

  /// A store that keeps values for the life of the process only.
  factory AppPreferences.inMemory() => AppPreferences._(_MemoryStore());

  /// Loads the platform store. Falls back to [inMemory] instead of throwing, so
  /// an unwritable data directory never blocks startup.
  static Future<AppPreferences> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final store = _FileStore(File('${dir.path}/throw_prefs.json'));
      await store.load();
      return AppPreferences._(store);
    } catch (_) {
      return AppPreferences.inMemory();
    }
  }

  /// Builds a store over an explicit file — used by tests to point at a temp
  /// directory instead of the real app-support path.
  static Future<AppPreferences> atFile(File file) async {
    final store = _FileStore(file);
    await store.load();
    return AppPreferences._(store);
  }

  /// Two-letter language code, or `null` when the user never chose one.
  String? get localeCode => _store.read(_kLocale) as String?;

  /// [ThemeMode.index] of the saved mode, or `null` when unset.
  int? get themeModeIndex => _store.read(_kThemeMode) as int?;

  /// Saved device name, or `null` when the user never renamed this device.
  String? get deviceName => _store.read(_kDeviceName) as String?;

  Future<void> setLocaleCode(String code) async {
    await _store.write(_kLocale, code);
  }

  Future<void> setThemeModeIndex(int index) async {
    await _store.write(_kThemeMode, index);
  }

  Future<void> setDeviceName(String name) async {
    await _store.write(_kDeviceName, name);
  }
}

/// The two implementations behind [AppPreferences].
abstract class _Store {
  dynamic read(String key);
  Future<void> write(String key, Object? value);
}

/// Process-lifetime store: values written here come back within the same run.
class _MemoryStore implements _Store {
  final Map<String, dynamic> _data = {};

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, Object? value) async {
    _data[key] = value;
  }
}

/// A tiny JSON document that is read once and rewritten whole on change.
///
/// Writes go to a temporary file and are renamed over the target, so a crash
/// mid-write cannot leave a truncated file that fails to parse on next launch.
/// A file that is unreadable or not a JSON map is treated as empty rather than
/// throwing — corrupt preferences should reset settings, not brick the app.
class _FileStore implements _Store {
  _FileStore(this._file);

  final File _file;
  Map<String, dynamic> _data = {};

  Future<void> load() async {
    try {
      if (!await _file.exists()) return;
      final raw = await _file.readAsString();
      if (raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) _data = decoded;
    } catch (_) {
      _data = {};
    }
  }

  @override
  dynamic read(String key) => _data[key];

  @override
  Future<void> write(String key, Object? value) async {
    _data[key] = value;
    await _flush();
  }

  Future<void> _flush() async {
    try {
      await _file.parent.create(recursive: true);
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(jsonEncode(_data), flush: true);
      await tmp.rename(_file.path);
    } catch (_) {
      // Preferences are best-effort: losing one must never surface as an
      // error in the UI, and the in-memory copy is still correct for this run.
    }
  }
}
