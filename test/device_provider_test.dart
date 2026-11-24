import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/preferences.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/providers/device_provider.dart';
import 'package:throw_app/services/transfer_service.dart';

/// A service that records the order of calls and what name it was handed.
class RecordingService implements TransferService {
  final devicesController = StreamController<DeviceModel>.broadcast();
  final calls = <String>[];
  final advertisedNames = <String>[];
  bool failAdvertising = false;

  @override
  Stream<DeviceModel> get devices => devicesController.stream;
  @override
  Stream<TransferModel> get transfers => const Stream.empty();
  @override
  Stream<ConnectionRequest> get connectionRequests => const Stream.empty();
  @override
  Stream<PayloadModel> get receivedPayloads => const Stream.empty();

  @override
  String get localDeviceName =>
      advertisedNames.isEmpty ? 'unset' : advertisedNames.last;

  @override
  Future<void> startAdvertising({required String deviceName}) async {
    calls.add('advertise');
    if (failAdvertising) throw StateError('radio off');
    advertisedNames.add(deviceName);
  }

  @override
  Future<void> stopAdvertising() async => calls.add('stopAdvertise');

  @override
  Future<void> startDiscovery() async => calls.add('discover');

  @override
  Future<void> stopDiscovery() async => calls.add('stopDiscover');

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
  Future<void> sendFile({
    required String endpointId,
    required File file,
    String? displayName,
    int? sizeBytes,
  }) async {}

  @override
  Future<void> cancelTransfer(String transferId) async {}

  @override
  Future<void> dispose() async {
    await devicesController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the advertised name is never the placeholder', () {
    test('a saved name is advertised verbatim', () async {
      final service = RecordingService();
      final prefs = AppPreferences.inMemory();
      await prefs.setDeviceName('Mahim\'s Pixel');
      final provider = DeviceProvider(service: service, preferences: prefs);

      await provider.startAdvertising();

      // This is the bug the other phone saw: it advertised before the name
      // resolved and every install came up as "Throw".
      expect(service.advertisedNames, ['Mahim\'s Pixel']);
      provider.dispose();
      await service.dispose();
    });

    test('advertising waits for name resolution', () async {
      final service = RecordingService();
      final provider = DeviceProvider(
        service: service,
        preferences: AppPreferences.inMemory(),
      );
      // Let the async name lookup settle before advertising.
      final name = await provider.resolvedDeviceName();
      expect(name.trim(), isNotEmpty);

      await provider.startAdvertising();
      expect(service.advertisedNames.single, name);
      provider.dispose();
      await service.dispose();
    });

    test('renaming while visible re-advertises under the new name', () async {
      final service = RecordingService();
      final prefs = AppPreferences.inMemory();
      await prefs.setDeviceName('Old name');
      final provider = DeviceProvider(service: service, preferences: prefs);

      await provider.startAdvertising();
      provider.setDeviceName('New name');
      // The re-advertise runs unawaited; give it a turn to finish.
      await Future<void>.delayed(Duration.zero);

      expect(service.advertisedNames, contains('New name'));
      provider.dispose();
      await service.dispose();
    });

    test('a blank rename is ignored rather than advertising nothing', () async {
      final service = RecordingService();
      final prefs = AppPreferences.inMemory();
      await prefs.setDeviceName('Keep me');
      final provider = DeviceProvider(service: service, preferences: prefs);

      provider.setDeviceName('   ');
      expect(provider.deviceName, 'Keep me');
      provider.dispose();
      await service.dispose();
    });
  });

  group('autoStart', () {
    test('advertises and discovers in that order, once', () async {
      final service = RecordingService();
      final provider = DeviceProvider(
        service: service,
        preferences: AppPreferences.inMemory(),
      );

      await provider.autoStart();
      // A second call must not repeat the work (or re-prompt for permission).
      await provider.autoStart();

      expect(service.calls.where((c) => c == 'advertise').length, 1);
      expect(service.calls.where((c) => c == 'discover').length, 1);
      // Advertising must come first so the other device can find us while we
      // are looking for it.
      expect(service.calls.indexOf('advertise'),
          lessThan(service.calls.indexOf('discover')));
      provider.dispose();
      await service.dispose();
    });

    test('a failed advertise does not then ask for discovery', () async {
      final service = RecordingService()..failAdvertising = true;
      final provider = DeviceProvider(
        service: service,
        preferences: AppPreferences.inMemory(),
      );

      await provider.autoStart();

      expect(provider.error, isNotNull);
      expect(service.calls, isNot(contains('discover')),
          reason: 'the same permission failure would repeat');
      provider.dispose();
      await service.dispose();
    });
  });

  group('device stream merging', () {
    test('a nameless update does not erase a learned name', () async {
      final service = RecordingService();
      final provider = DeviceProvider(
        service: service,
        preferences: AppPreferences.inMemory(),
      );
      final now = DateTime(2026, 11, 24);

      service.devicesController.add(DeviceModel(
        id: 'peer',
        name: 'Mahim Pixel',
        platform: DevicePlatform.android,
        channel: TransferChannel.wifiDirect,
        isConnected: true,
        lastSeen: now,
      ));
      await Future<void>.delayed(Duration.zero);

      // A later event from the transport that carries no name.
      service.devicesController.add(DeviceModel(
        id: 'peer',
        name: 'peer',
        platform: DevicePlatform.unknown,
        channel: TransferChannel.wifiDirect,
        isConnected: true,
        lastSeen: now.add(const Duration(seconds: 5)),
      ));
      await Future<void>.delayed(Duration.zero);

      final device = provider.connectedDevices.single;
      expect(device.name, 'Mahim Pixel');
      expect(device.displayName, 'Mahim Pixel');
      // The platform learned earlier also survives.
      expect(device.platform, DevicePlatform.android);
      provider.dispose();
      await service.dispose();
    });
  });
}
