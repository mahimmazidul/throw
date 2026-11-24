import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/device_model.dart';

void main() {
  group('DeviceModel', () {
    final now = DateTime(2026, 11, 24);

    test('constructs with required fields and defaults', () {
      final device = DeviceModel(
        id: 'dev-1',
        name: 'Pixel 8',
        platform: DevicePlatform.android,
        channel: TransferChannel.wifiDirect,
        lastSeen: now,
      );

      expect(device.id, 'dev-1');
      expect(device.name, 'Pixel 8');
      expect(device.platform, DevicePlatform.android);
      expect(device.channel, TransferChannel.wifiDirect);
      expect(device.isConnected, isFalse);
    });

    test('copyWith updates only specified fields', () {
      final device = DeviceModel(
        id: 'dev-1',
        name: 'Pixel 8',
        platform: DevicePlatform.android,
        channel: TransferChannel.wifiDirect,
        isConnected: false,
        lastSeen: now,
      );

      final connected = device.copyWith(isConnected: true);
      expect(connected.id, 'dev-1');
      expect(connected.name, 'Pixel 8');
      expect(connected.isConnected, isTrue);

      final renamed = connected.copyWith(name: 'Pixel 8 Pro');
      expect(renamed.name, 'Pixel 8 Pro');
      expect(renamed.isConnected, isTrue);
    });

    test('equality is based on id', () {
      final a = DeviceModel(
        id: 'same-id',
        name: 'Device A',
        platform: DevicePlatform.windows,
        channel: TransferChannel.bluetooth,
        lastSeen: now,
      );
      final b = DeviceModel(
        id: 'same-id',
        name: 'Device B',
        platform: DevicePlatform.linux,
        channel: TransferChannel.bluetooth,
        isConnected: true,
        lastSeen: now,
      );
      final c = DeviceModel(
        id: 'other-id',
        name: 'Device A',
        platform: DevicePlatform.windows,
        channel: TransferChannel.bluetooth,
        lastSeen: now,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
