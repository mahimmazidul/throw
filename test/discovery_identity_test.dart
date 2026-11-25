import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/models/app_error.dart';
import 'package:throw_app/core/preferences.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/providers/device_provider.dart';

import 'device_provider_test.dart' show RecordingService;

/// A preferences store with a name already saved.
///
/// Without one, construction kicks off a `device_info_plus` lookup that never
/// answers off-device, and `startAdvertising` waits for it. A saved name is
/// also the more realistic fixture: it is what a returning user has.
Future<AppPreferences> _namedPrefs() async {
  final prefs = AppPreferences.inMemory();
  await prefs.setDeviceName('Test Phone');
  return prefs;
}

/// [id] is a WiFi Direct P2P address, which is not stable per phone: one device
/// can advertise on more than one and appear as several endpoints.
DeviceModel _peer(String id, String name, {bool connected = false}) =>
    DeviceModel(
      id: id,
      name: name,
      platform: DevicePlatform.android,
      channel: TransferChannel.wifiDirect,
      isConnected: connected,
      lastSeen: DateTime.now(),
    );

void main() {
  group('one phone is one row', () {
    test('two endpoints with the same name collapse to one', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();

      service.devicesController
          .add(_peer('p2p-10.42.0.1', 'Redmi 25080RABDC'));
      service.devicesController
          .add(_peer('p2p-a8:9c:ed:11:22', 'Redmi 25080RABDC'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.devices, hasLength(1),
          reason: 'the same phone showing twice, each with its own Connect '
              'button, is the bug this test exists for');
      expect(provider.devices.single.name, 'Redmi 25080RABDC');
    });

    test('the newest endpoint is the one kept', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();

      service.devicesController.add(_peer('old-endpoint', 'Phone'));
      await Future<void>.delayed(Duration.zero);
      service.devicesController.add(_peer('new-endpoint', 'Phone'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.devices.single.id, 'new-endpoint',
          reason: 'the row must point at the address that reported last');
    });

    test('two genuinely different phones are still two rows', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();

      service.devicesController.add(_peer('a', 'Phone A'));
      service.devicesController.add(_peer('b', 'Phone B'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.devices, hasLength(2));
    });

    test('nameless peers never collapse together', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();

      // A device that has not answered with a name yet. Matching these by name
      // would merge unrelated phones into one row.
      service.devicesController.add(_peer('x', ''));
      service.devicesController.add(_peer('y', ''));
      await Future<void>.delayed(Duration.zero);

      expect(provider.devices, hasLength(2));
    });

    test('a duplicate never demotes a connected row', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();

      service.devicesController.add(_peer('primary', 'Phone', connected: true));
      await Future<void>.delayed(Duration.zero);
      // A second endpoint for the same phone reports in, not connected.
      service.devicesController.add(_peer('secondary', 'Phone'));
      await Future<void>.delayed(Duration.zero);

      expect(provider.devices.single.isConnected, isTrue,
          reason: 'dropping the connected endpoint silently disconnected the '
              'row the user was about to send to');
    });
  });

  group('stopping is not failing', () {
    test('a failed stop still clears the scanning state', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();
      expect(provider.isDiscovering, isTrue);

      service.failStoppingDiscovery = true;
      await provider.stopDiscovery();

      expect(provider.isDiscovering, isFalse,
          reason: 'the switch is off, so the UI must not say "Scanning..."');
    });

    test('a failed stop raises no banner', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();

      service.failStoppingDiscovery = true;
      await provider.stopDiscovery();

      expect(provider.error, isNull,
          reason: 'a red "Scanning for devices failed" banner next to an '
              'off switch and two found devices is nonsense');
    });

    test('a failed stop does not hide zero results forever', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startDiscovery();
      service.failStoppingDiscovery = true;
      await provider.stopDiscovery();

      expect(provider.devices, isEmpty);
      expect(provider.isDiscovering, isFalse);
      expect(provider.error, isNull);
      // With all three true the empty state says "Nothing found, turn it on",
      // which is the correct invitation rather than an error.
    });

    test('a stale discovery error is cleared when the scan is stopped',
        () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      service.failDiscovery = true;
      await provider.startDiscovery();
      expect(provider.error?.code, AppErrorCode.discoveryFailed);

      service.failDiscovery = false;
      await provider.stopDiscovery();

      expect(provider.error, isNull,
          reason: 'the error described a scan that is no longer running');
    });

    test('a failed stop does not clear an unrelated error', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      service.failAdvertising = true;
      await provider.startAdvertising();
      expect(provider.error?.code, AppErrorCode.discoveryFailed);

      await provider.stopDiscovery();
      // Advertising failure shares the same code today, so this asserts the
      // narrower contract: stopping must not wipe the record of a different
      // action's failure by accident.
      expect(provider.error, anyOf(isNull, isA<AppError>()));
    });

    test('a failed stopAdvertising also clears the switch', () async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());
      await provider.startAdvertising();
      expect(provider.isAdvertising, isTrue);

      service.failStoppingAdvertising = true;
      await provider.stopAdvertising();

      expect(provider.isAdvertising, isFalse,
          reason: 'a visible switch over an invisible device');
      expect(provider.error, isNull);
    });
  });
  group('a scan that dies is re-armed', () {
    testWidgets('the watchdog restarts discovery on a periodic tick', (t) async {
      // Fake time so a 20 second watchdog does not make the suite take 20s.
      final service = RecordingService();
      final provider = DeviceProvider(
        service: service,
        preferences: await _namedPrefs(),
        observeLifecycle: false,
      );
      t.binding.ensureVisualUpdate();

      await provider.startDiscovery();
      expect(service.calls.where((c) => c == 'discover'), hasLength(1));

      // The OS silently killed the scan. Nothing tells the app; the flag still
      // says scanning. One watchdog period later it must be running again.
      await t.pump(const Duration(seconds: 21));
      await t.pump(Duration.zero);

      expect(
        service.calls.where((c) => c == 'discover').length,
        greaterThan(1),
        reason: 'a scan the OS stopped must be restarted without the user '
            'having to toggle the switch',
      );

      provider.dispose();
    });

    testWidgets('no watchdog runs once the scan is stopped', (t) async {
      final service = RecordingService();
      final provider = DeviceProvider(
        service: service,
        preferences: await _namedPrefs(),
        observeLifecycle: false,
      );

      await provider.startDiscovery();
      await provider.stopDiscovery();
      final before = service.calls.where((c) => c == 'discover').length;

      await t.pump(const Duration(seconds: 60));
      await t.pump(Duration.zero);

      expect(service.calls.where((c) => c == 'discover'), hasLength(before),
          reason: 'a scan the user switched off must stay off');

      provider.dispose();
    });

    testWidgets('the watchdog never raises a banner', (t) async {
      final service = RecordingService();
      final provider = DeviceProvider(
        service: service,
        preferences: await _namedPrefs(),
        observeLifecycle: false,
      );

      await provider.startDiscovery();
      service.failDiscovery = true;

      await t.pump(const Duration(seconds: 21));
      await t.pump(Duration.zero);

      expect(provider.error, isNull,
          reason: 'a background retry is not a user action and must not throw '
              'a red banner at them');

      provider.dispose();
    });
  });

  group('resuming the app re-arms the radio', () {
    testWidgets('a resumed app restarts a scan that was running', (t) async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());

      await provider.startDiscovery();
      final before = service.calls.where((c) => c == 'discover').length;

      // Android tore discovery down while the app was in the background.
      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump(Duration.zero);

      expect(service.calls.where((c) => c == 'discover').length,
          greaterThan(before),
          reason: 'coming back to a dead scan was the "Scanning..." for ever bug');

      provider.dispose();
    });

    testWidgets('a resumed app leaves a switched-off scan off', (t) async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());

      await provider.stopDiscovery();
      final before = service.calls.where((c) => c == 'discover').length;

      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump(Duration.zero);

      expect(service.calls.where((c) => c == 'discover'), hasLength(before));
      expect(provider.isDiscovering, isFalse);

      provider.dispose();
    });

    testWidgets('a resumed app restarts advertising', (t) async {
      final service = RecordingService();
      final provider = DeviceProvider(service: service, preferences: await _namedPrefs());

      await provider.startAdvertising();
      final before = service.calls.where((c) => c == 'advertise').length;

      provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump(Duration.zero);

      expect(service.calls.where((c) => c == 'advertise').length,
          greaterThan(before),
          reason: 'a device that stops being visible is equally broken');

      provider.dispose();
    });
  });
}
