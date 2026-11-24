import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/preferences.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/providers/device_provider.dart';
import 'package:throw_app/providers/locale_provider.dart';
import 'package:throw_app/services/transfer_service.dart';

class _NullService implements TransferService {
  @override
  Stream<DeviceModel> get devices => const Stream.empty();
  @override
  Stream<TransferModel> get transfers => const Stream.empty();
  @override
  Stream<ConnectionRequest> get connectionRequests => const Stream.empty();
  @override
  Stream<PayloadModel> get receivedPayloads => const Stream.empty();
  @override
  Future<void> startAdvertising({required String deviceName}) async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(DeviceModel device) async {}
  @override
  Future<void> disconnect(String endpointId) async {}
  @override
  Future<void> acceptConnection(String endpointId) async {}
  @override
  Future<void> rejectConnection(String endpointId) async {}
  @override
  Future<void> sendText(
      {required String endpointId, required String text}) async {}
  @override
  Future<void> sendFile(
      {required String endpointId, required File file}) async {}
  @override
  Future<void> cancelTransfer(String transferId) async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every test gets its own file in a temp directory; nothing touches the real
  // app-support path.
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('throw_prefs_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<AppPreferences> store({String name = 'prefs.json'}) =>
      AppPreferences.atFile(File('${tempDir.path}/$name'));

  group('AppPreferences.inMemory', () {
    test('stores nothing but never throws', () async {
      final prefs = AppPreferences.inMemory();
      await prefs.setLocaleCode('bn');
      await prefs.setThemeModeIndex(2);
      await prefs.setDeviceName('Desk');
      expect(prefs.localeCode, isNull);
      expect(prefs.themeModeIndex, isNull);
      expect(prefs.deviceName, isNull);
    });
  });

  group('AppPreferences on the file store', () {
    test('round-trips language, theme and device name', () async {
      final prefs = await store();
      await prefs.setLocaleCode('bn');
      await prefs.setThemeModeIndex(ThemeMode.light.index);
      await prefs.setDeviceName('Mahim Desk');

      // A second store over the same file simulates a relaunch.
      final reopened = await store();
      expect(reopened.localeCode, 'bn');
      expect(reopened.themeModeIndex, ThemeMode.light.index);
      expect(reopened.deviceName, 'Mahim Desk');
    });

    test('missing file reads as empty rather than throwing', () async {
      final prefs = await store(name: 'never-written.json');
      expect(prefs.localeCode, isNull);
      expect(prefs.themeModeIndex, isNull);
      expect(prefs.deviceName, isNull);
    });

    test('a corrupt file resets settings instead of breaking startup', () async {
      final file = File('${tempDir.path}/corrupt.json');
      await file.writeAsString('{not json at all');
      final prefs = await AppPreferences.atFile(file);
      expect(prefs.localeCode, isNull);

      // And the store still works afterwards.
      await prefs.setDeviceName('Recovered');
      expect((await AppPreferences.atFile(file)).deviceName, 'Recovered');
    });

    test('writes are atomic: no .tmp file is left behind', () async {
      final prefs = await store();
      await prefs.setDeviceName('A');
      await prefs.setDeviceName('B');
      final leftovers = tempDir
          .listSync()
          .where((e) => e.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
      expect((await store()).deviceName, 'B');
    });

    test('creates the parent directory when it does not exist', () async {
      final nested = '${tempDir.path}/a/b/c/prefs.json';
      final prefs = await AppPreferences.atFile(File(nested));
      await prefs.setLocaleCode('bn');
      expect(File(nested).existsSync(), isTrue);
    });
  });

  group('LocaleProvider persistence', () {
    test('restore() applies a saved locale and theme', () async {
      final seed = await store();
      await seed.setLocaleCode('bn');
      await seed.setThemeModeIndex(ThemeMode.light.index);
      final prefs = await store();
      final provider = LocaleProvider(preferences: prefs);
      expect(provider.locale.languageCode, 'en');
      expect(provider.themeMode, ThemeMode.dark);

      provider.restore();
      expect(provider.locale.languageCode, 'bn');
      expect(provider.themeMode, ThemeMode.light);
    });

    test('changes write through to the store', () async {
      final prefs = await store();
      final provider = LocaleProvider(preferences: prefs);

      provider.toggleLocale();
      provider.setThemeMode(ThemeMode.light);
      expect(prefs.localeCode, 'bn');
      expect(prefs.themeModeIndex, ThemeMode.light.index);
    });

    test('restore() ignores corrupt or unsupported saved values', () async {
      final seed = await store();
      await seed.setLocaleCode('xx');
      await seed.setThemeModeIndex(99);
      final prefs = await store();
      final provider = LocaleProvider(preferences: prefs);

      provider.restore();
      expect(provider.locale.languageCode, 'en');
      expect(provider.themeMode, ThemeMode.dark);
    });

    test('unsupported locales are rejected at the setter', () {
      final provider = LocaleProvider(preferences: AppPreferences.inMemory());
      provider.setLocale(const Locale('fr'));
      expect(provider.locale.languageCode, 'en');
    });

    test('notifies listeners so the app re-themes', () {
      final provider = LocaleProvider(preferences: AppPreferences.inMemory());
      var notified = 0;
      provider.addListener(() => notified++);
      provider.setThemeMode(ThemeMode.light);
      provider.setThemeMode(ThemeMode.light); // no-op
      expect(notified, 1);
    });
  });

  group('DeviceProvider name persistence', () {
    test('a saved name wins over the platform-reported one', () async {
      final seed = await store();
      await seed.setDeviceName('Work Laptop');
      final prefs = await store();
      final provider = DeviceProvider(
        service: _NullService(),
        preferences: prefs,
      );
      // Give the async name initialiser a turn to run.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(provider.deviceName, 'Work Laptop');
      provider.dispose();
    });

    test('renaming persists', () async {
      final prefs = await store();
      final provider = DeviceProvider(
        service: _NullService(),
        preferences: prefs,
      );
      provider.setDeviceName('  Garden Phone  ');
      expect(provider.deviceName, 'Garden Phone');
      expect(prefs.deviceName, 'Garden Phone');
      provider.dispose();
    });

    test('blank names are ignored', () {
      final provider = DeviceProvider(
        service: _NullService(),
        preferences: AppPreferences.inMemory(),
      );
      final before = provider.deviceName;
      provider.setDeviceName('   ');
      expect(provider.deviceName, before);
      provider.dispose();
    });
  });
}
