import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions for discovery and transfer.
///
/// Desktop platforms need none at runtime — BlueZ/D-Bus and Windows pair
/// without OS permission prompts — so every check short-circuits there.
abstract final class Permissions {
  /// Requests everything discovery needs and reports whether transfer can
  /// start.
  ///
  /// Android gates WiFi Direct on NEARBY_WIFI_DEVICES (13+) or location
  /// (older), and BLE discovery on scan/connect (12+) or the legacy
  /// Bluetooth install-time grant (older). Either side of each pair being
  /// granted is enough, because only one applies on any given OS version.
  static Future<bool> ensureNearbyAccess() async {
    if (!Platform.isAndroid) return true;

    final results = await <Permission>[
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetooth,
    ].request();

    bool granted(Permission p) =>
        (results[p] ?? PermissionStatus.denied).isGranted;

    // WiFi Direct gate: NEARBY_WIFI_DEVICES on Android 13+, location before.
    final wifiReady = granted(Permission.nearbyWifiDevices) ||
        granted(Permission.locationWhenInUse);
    // BLE gate: scan/connect on Android 12+, legacy Bluetooth before.
    final bleReady = granted(Permission.bluetoothScan) ||
        granted(Permission.bluetoothConnect) ||
        granted(Permission.bluetooth);

    return wifiReady && bleReady;
  }

  /// True when [ensureNearbyAccess] would succeed without prompting.
  static Future<bool> hasNearbyAccess() async {
    if (!Platform.isAndroid) return true;

    final wifiReady = await Permission.nearbyWifiDevices.isGranted ||
        await Permission.locationWhenInUse.isGranted;
    final bleReady = await Permission.bluetoothScan.isGranted ||
        await Permission.bluetoothConnect.isGranted ||
        await Permission.bluetooth.isGranted;
    return wifiReady && bleReady;
  }

  /// True when the user tapped "don't ask again" — the UI should send them
  /// to system settings instead of re-prompting.
  static Future<bool> isPermanentlyDenied() async {
    if (!Platform.isAndroid) return false;

    for (final p in [
      Permission.nearbyWifiDevices,
      Permission.locationWhenInUse,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ]) {
      if (await p.isPermanentlyDenied) return true;
    }
    return false;
  }

  /// Opens this app's system settings page (used after a permanent denial).
  static Future<void> openSettings() => openAppSettings();
}
