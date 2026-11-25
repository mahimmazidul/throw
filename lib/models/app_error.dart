import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// What went wrong, without carrying any user-facing text.
///
/// Errors used to reach the UI as raw [String]s produced inside the providers
/// — hardcoded English, and sniffed for substrings downstream
/// (`error.toLowerCase().contains('settings')`) to decide whether to show a
/// button. That breaks the moment the app is in Bangla, and it leaves every
/// call site to invent its own presentation.
///
/// Carrying a *code* instead puts all three decisions in one place: the view
/// renders an [ErrorBanner], the banner picks its copy from the localization
/// layer, and its action comes from [offerSettings] rather than text matching.
enum AppErrorCode {
  /// Nearby/Bluetooth permission missing. The user can grant it in-app.
  permissionDenied,

  /// Permission was permanently denied — only system settings can fix it.
  permissionBlocked,

  /// The radio is off. Nothing will scan until it is on.
  bluetoothOff,

  /// This machine has no Bluetooth adapter at all.
  ///
  /// Distinct from [bluetoothOff] because there is nothing the user can switch
  /// on: a desktop without a radio is not failing, it simply has no such
  /// hardware. Reporting it as a discovery error put a red "Scanning for
  /// devices failed" banner on every launch of a perfectly healthy app.
  noRadio,

  /// Location services off; Android discovery needs them.
  locationOff,

  /// Starting or running a scan failed.
  discoveryFailed,

  /// A send or receive failed mid-flight.
  transferFailed,

  /// Checking for an app update failed for a reason that is not connectivity.
  updateFailed,

  /// There is no usable network right now. Distinct from [updateFailed]
  /// because it is not a fault: Throw is an offline app, and being offline is
  /// its normal state. Telling someone "that failed" for checking on a
  /// feature that is only a convenience is the wrong message.
  offline,

  /// Anything unrecognised; [AppError.detail] keeps the raw message.
  unknown,
}

/// A failure, classified.
@immutable
class AppError {
  const AppError(this.code, {this.detail});

  final AppErrorCode code;

  /// Raw platform message for [AppErrorCode.unknown] and [AppErrorCode.updateFailed].
  final String? detail;

  /// The user can only act on this from inside the app: system settings.
  ///
  /// Drives the button on the banner, replacing the old substring sniff.
  bool get offerSettings => code == AppErrorCode.permissionBlocked;

  /// Bad enough to keep visible until it is dismissed.
  bool get isSevere =>
      code == AppErrorCode.transferFailed ||
      code == AppErrorCode.discoveryFailed;

  /// Classify a thrown object once, here, rather than in every `catch`.
  ///
  /// [fallback] is the code to use when nothing about the message is
  /// recognisable. Callers know what they were doing — a discovery failure and
  /// a transfer failure are both "unknown exception" at this level but mean
  /// completely different things to the person reading the banner.
  factory AppError.fromObject(
    Object e, {
    AppErrorCode fallback = AppErrorCode.unknown,
  }) {
    final msg = e.toString();
    final m = msg.toLowerCase();
    if (m.contains('missing_permission') ||
        m.contains('security_exception') ||
        m.contains('securityexception') ||
        m.contains('security exception') ||
        m.contains('permission')) {
      return AppError(AppErrorCode.permissionDenied, detail: msg);
    }
    if (m.contains('bluetooth') &&
        (m.contains('off') ||
            m.contains('disabled') ||
            m.contains('not supported'))) {
      return AppError(AppErrorCode.bluetoothOff, detail: msg);
    }
    if (m.contains('location')) {
      return AppError(AppErrorCode.locationOff, detail: msg);
    }
    // A missing adapter, reported two ways: the BlueZ stack throws an
    // empty-collection error out of `adapters.first`, and the platform channels
    // throw an unsupported operation.
    //
    // The bare "No element" case is only treated as "no radio" when the caller
    // was discovering — an empty `.first` anywhere else (a transfer with no
    // payload, say) is a genuine fault and must keep its own fallback. Without
    // that guard this would quietly reclassify unrelated crashes as a
    // reassuring hardware message.
    if ((m.contains('bluetooth') || m.contains('adapter')) &&
        (m.contains('not supported') ||
            m.contains('not found') ||
            m.contains('unavailable') ||
            m.contains('no element'))) {
      return AppError(AppErrorCode.noRadio, detail: msg);
    }
    if (fallback == AppErrorCode.discoveryFailed && m.contains('no element')) {
      return AppError(AppErrorCode.noRadio, detail: msg);
    }
    if (_looksOffline(msg)) {
      return AppError(AppErrorCode.offline, detail: msg);
    }
    return AppError(fallback, detail: msg);
  }

  @override
  bool operator ==(Object other) =>
      other is AppError && other.code == code && other.detail == detail;

  @override
  int get hashCode => Object.hash(code, detail);

  @override
  String toString() =>
      'AppError(${code.name}${detail == null ? '' : ', $detail'})';
}

/// The one place that turns an [AppError] into a localized sentence.
String describeError(AppError error, AppLocalizations l10n) =>
    switch (error.code) {
      AppErrorCode.permissionDenied => l10n.errorPermissionDenied,
      AppErrorCode.permissionBlocked => l10n.errorPermissionBlocked,
      AppErrorCode.bluetoothOff => l10n.errorBluetoothOff,
      AppErrorCode.noRadio => l10n.errorNoRadio,
      AppErrorCode.locationOff => l10n.errorLocationOff,
      AppErrorCode.discoveryFailed => l10n.errorDiscoveryFailed,
      AppErrorCode.transferFailed => l10n.errorTransferFailed,
      AppErrorCode.offline => l10n.updateOffline,
      // Deliberately not `updateFailed(detail)`: the raw exception text is a
      // debugging aid, and "Could not check updates: SocketException: Failed
      // host lookup 'api.github.com'" is not something a person can act on.
      AppErrorCode.updateFailed => l10n.updateOfflineShort,
      // The raw exception text is a debugging aid, not copy. Showing
      // "Bad state: No element" to someone who tried to find their phone is
      // worse than saying nothing useful at all; it reads like the app is
      // broken rather than that the scan failed. The detail stays on the
      // object for logs and for the copy button in the banner.
      AppErrorCode.unknown => error.detail == null
          ? l10n.errorGeneric
          : l10n.errorGenericWithDetail,
    };

/// True when [message] reads like "there is no network", rather than like a
/// bug. Dart has no single offline exception, so this matches the shapes that
/// actually reach an app: `SocketException: Failed host lookup: 'api.github.com'`
/// (no DNS), `SocketException: Network is unreachable` (no route),
/// `HandshakeException` (captive portal), and the connect timeouts the update
/// check sets for itself.
///
/// Deliberately narrow. A 404 from the releases API is a real fault and must
/// keep reading as a fault, so nothing here matches on status codes.
bool _looksOffline(String message) {
  final m = message.toLowerCase();
  const signals = [
    'failed host lookup',
    'socketexception',
    'network is unreachable',
    'network is down',
    'no route to host',
    'connection refused',
    'connection reset',
    'connection timed out',
    'connection closed',
    'handshakeexception',
    'handshake failed',
    'temporary failure in name resolution',
    'nodename nor servname',
    'timed out',
    'timeout',
    'no address associated with hostname',
    'operation not permitted',
    'os error 51', // iOS: network connection lost
  ];
  return signals.any(m.contains);
}
