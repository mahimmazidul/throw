import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/device_model.dart';

void main() {
  group('DeviceModel', () {
    test('constructs with required fields and defaults', () {
      const device = DeviceModel(
        id: 'dev-1',
        name: 'Pixel 8',
        platform: DevicePlatform.android,
        transport: TransportType.wifiDirect,
      );

      expect(device.id, 'dev-1');
      expect(device.name, 'Pixel 8');
      expect(device.platform, DevicePlatform.android);
      expect(device.transport, TransportType.wifiDirect);
      expect(device.isConnected, isFalse);
    });

    test('copyWith updates only specified fields', () {
      const device = DeviceModel(
        id: 'dev-1',
        name: 'Pixel 8',
        platform: DevicePlatform.android,
        transport: TransportType.wifiDirect,
        isConnected: false,
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
      const a = DeviceModel(
        id: 'same-id',
        name: 'Device A',
        platform: DevicePlatform.windows,
        transport: TransportType.bluetooth,
      );
      const b = DeviceModel(
        id: 'same-id',
        name: 'Device B',
        platform: DevicePlatform.linux,
        transport: TransportType.bluetooth,
        isConnected: true,
      );
      const c = DeviceModel(
        id: 'other-id',
        name: 'Device A',
        platform: DevicePlatform.windows,
        transport: TransportType.bluetooth,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
