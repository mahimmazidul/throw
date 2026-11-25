/// App-wide constants: layout, spacing, transfer, and desktop window rules.
abstract final class AppConstants {
  static const String appVersion = '1.3.3';

  /// Build number, kept next to [appVersion] because the About screen shows
  /// both and `pubspec.yaml`'s `+N` is not readable at runtime.
  static const String appBuild = '22';

  /// The version with its `v` prefix, as GitHub tags it.
  static const String versionTag = 'v$appVersion';

  static const String githubRepo = 'mahimmazidul/throw';
  static const String releasesUrl =
      'https://github.com/mahimmazidul/throw/releases/latest';

  // ── Developer links (shown on About) ─────────────────────────────
  //
  // Plain data, not copy: a handle and a domain do not get translated, and
  // keeping them here means the About screen has no string literals for the
  // localization guard to flag.
  static const String developerHandle = 'mahimmazidul';
  static const String developerDomain = 'mahim.dev';
  static const String developerGithubUrl =
      'https://github.com/mahimmazidul';
  static const String developerWebsiteUrl = 'https://mahim.dev';
  static const String repoUrl =
      'https://github.com/mahimmazidul/throw';
  static const String issuesUrl =
      'https://github.com/mahimmazidul/throw/issues';
  static const String licenseUrl =
      'https://github.com/mahimmazidul/throw/blob/main/LICENSE';

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

  /// Maximum width of a content column. Beyond this, prose lines get too long
  /// to read comfortably and controls drift away from the thing they act on.
  /// 720dp is the widest single column that still holds a 60–75 character
  /// measure at this type scale.
  static const double contentMax = 720;

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
