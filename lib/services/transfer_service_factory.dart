import 'dart:io';

import 'bluetooth_service.dart';
import 'nearby_service.dart';
import 'transfer_service.dart';

/// Selects the platform-appropriate [TransferService] implementation.
///
/// Android uses [NearbyService] (WiFi Direct + BLE via Nearby Connections).
/// Desktop platforms (Windows, Linux) use [BluetoothService] (BLE).
class TransferServiceFactory {
  TransferServiceFactory._();

  static TransferService? _instance;

  static TransferService get instance => _instance ??= _create();

  static TransferService _create() {
    if (Platform.isAndroid) {
      return NearbyService();
    }
    return BluetoothService();
  }
}
