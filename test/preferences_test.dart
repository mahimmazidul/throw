import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('AppPreferences on the platform store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('round-trips language, theme and device name', () async {
      final prefs = await AppPreferences.load();
      await prefs.setLocaleCode('bn');
      await prefs.setThemeModeIndex(ThemeMode.light.index);
      await prefs.setDeviceName('Mahim Desk');

      final reopened = await AppPreferences.load();
      expect(reopened.localeCode, 'bn');
      expect(reopened.themeModeIndex, ThemeMode.light.index);
      expect(reopened.deviceName, 'Mahim Desk');
    });

    test('reads values saved by a previous run', () async {
      SharedPreferences.setMockInitialValues({
        'locale': 'bn',
        'themeMode': ThemeMode.light.index,
        'deviceName': 'Old Name',
      });
      final prefs = await AppPreferences.load();
      expect(prefs.localeCode, 'bn');
      expect(prefs.themeModeIndex, ThemeMode.light.index);
      expect(prefs.deviceName, 'Old Name');
    });
  });

  group('LocaleProvider persistence', () {
    test('restore() applies a saved locale and theme', () async {
      SharedPreferences.setMockInitialValues({
        'locale': 'bn',
        'themeMode': ThemeMode.light.index,
      });
      final prefs = await AppPreferences.load();
      final provider = LocaleProvider(preferences: prefs);
      expect(provider.locale.languageCode, 'en');
      expect(provider.themeMode, ThemeMode.dark);

      provider.restore();
      expect(provider.locale.languageCode, 'bn');
      expect(provider.themeMode, ThemeMode.light);
    });

    test('changes write through to the store', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
      final provider = LocaleProvider(preferences: prefs);

      provider.toggleLocale();
      provider.setThemeMode(ThemeMode.light);
      expect(prefs.localeCode, 'bn');
      expect(prefs.themeModeIndex, ThemeMode.light.index);
    });

    test('restore() ignores corrupt or unsupported saved values', () async {
      SharedPreferences.setMockInitialValues({
        'locale': 'xx',
        'themeMode': 99,
      });
      final prefs = await AppPreferences.load();
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
      SharedPreferences.setMockInitialValues({'deviceName': 'Work Laptop'});
      final prefs = await AppPreferences.load();
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
      SharedPreferences.setMockInitialValues({});
      final prefs = await AppPreferences.load();
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
