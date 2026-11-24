/// App-wide constants: layout, spacing, transfer, and desktop window rules.
abstract final class AppConstants {
  static const String appVersion = '1.1.0';
  static const String githubRepo = 'mahimmazidul/throw';
  static const String releasesUrl =
      'https://github.com/mahimmazidul/throw/releases/latest';

  // ── Layout ──────────────────────────────────────────────────────

  /// Minimum touch target on every platform, mouse included.
  static const double touchTargetMin = 48;

  // ── Spacing grid (4px base) ─────────────────────────────────────

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;
  static const double space7 = 48;
  static const double space8 = 64;

  // ── Desktop window ──────────────────────────────────────────────

  static const double windowMinWidth = 400;
  static const double windowMinHeight = 600;
  static const double windowDefaultWidth = 900;
  static const double windowDefaultHeight = 650;

  // ── Discovery & transfer ────────────────────────────────────────

  /// Service name advertised during discovery.
  static const String serviceName = 'throw';

  /// Android Nearby service id (matches the application id in the manifest).
  static const String androidServiceId = 'com.mahimmazidul.throw.service';

  /// Stop discovery when nothing has shown up within this window.
  static const Duration discoveryTimeout = Duration(seconds: 30);

  /// Give up on a connection attempt after this long.
  static const Duration connectionTimeout = Duration(seconds: 15);

  /// Bytes read per chunk while streaming a payload.
  static const int chunkSize = 64 * 1024;

  // ── Speeds shown in the UI (approximate) ────────────────────────

  static const int wifiDirectSpeedMbps = 250;
  static const int bluetoothSpeedMbps = 3;
}
