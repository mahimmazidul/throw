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

  /// Location services off; Android discovery needs them.
  locationOff,

  /// Starting or running a scan failed.
  discoveryFailed,

  /// A send or receive failed mid-flight.
  transferFailed,

  /// Checking for an app update failed (usually offline).
  updateFailed,

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
      AppErrorCode.locationOff => l10n.errorLocationOff,
      AppErrorCode.discoveryFailed => l10n.errorDiscoveryFailed,
      AppErrorCode.transferFailed => l10n.errorTransferFailed,
      AppErrorCode.updateFailed => l10n.updateFailed(error.detail ?? ''),
      // The raw exception text is a debugging aid, not copy. Showing
      // "Bad state: No element" to someone who tried to find their phone is
      // worse than saying nothing useful at all; it reads like the app is
      // broken rather than that the scan failed. The detail stays on the
      // object for logs and for the copy button in the banner.
      AppErrorCode.unknown => error.detail == null
          ? l10n.errorGeneric
          : l10n.errorGenericWithDetail,
    };
