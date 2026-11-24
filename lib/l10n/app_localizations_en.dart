// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Throw';

  @override
  String get tagline => 'Send files and text to nearby devices.';

  @override
  String get navHome => 'Home';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionSend => 'Send';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionAccept => 'Accept';

  @override
  String get actionReject => 'Reject';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionPaste => 'Paste';

  @override
  String get actionClose => 'Close';

  @override
  String get stateSearching => 'Searching for devices…';

  @override
  String get stateNoDevices => 'No devices nearby yet.';

  @override
  String get stateConnected => 'Connected';

  @override
  String get stateConnecting => 'Connecting…';

  @override
  String get stateTransferring => 'Transferring…';

  @override
  String get stateComplete => 'Transfer complete';

  @override
  String get stateFailed => 'Transfer failed';

  @override
  String get stateCancelled => 'Cancelled';

  @override
  String get stateRejected => 'Rejected';

  @override
  String get incomingTitle => 'Incoming transfer';

  @override
  String incomingFrom(String device) {
    return 'From $device';
  }

  @override
  String get speedWifi => 'WiFi Direct · ~250 Mbps';

  @override
  String get speedBluetooth => 'Bluetooth · ~3 Mbps';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsDeviceName => 'Device name';

  @override
  String get settingsAbout => 'About';

  @override
  String get permissionTitle => 'Permissions needed';

  @override
  String get permissionBody =>
      'Throw needs nearby device access to find and transfer to devices around you.';

  @override
  String get errorBluetoothOff =>
      'Bluetooth is off. Turn it on to discover devices.';

  @override
  String get errorLocationOff =>
      'Location services are off. Nearby discovery needs them on Android.';

  @override
  String get sendClipboardHint => 'Copy something first, then send it.';

  @override
  String statusConnectedCount(int count) {
    return '$count connected';
  }

  @override
  String get statusNoDevice => 'No device connected';

  @override
  String get transportBoth => 'WiFi Direct / Bluetooth';

  @override
  String get featureDirectSharing => 'Direct local sharing';

  @override
  String shareInboxTitle(int count) {
    return 'Shared to Throw ($count)';
  }

  @override
  String shareInboxMore(int count) {
    return '+$count more';
  }

  @override
  String get shareInboxSend => 'Send shared items';

  @override
  String get sendTextTitle => 'Send text';

  @override
  String get sendFilesTitle => 'Send files';

  @override
  String get sendFilesHint =>
      'Pick multiple files and send directly to the selected device.';

  @override
  String get actionPick => 'Pick';

  @override
  String visibleAs(String name) {
    return 'Visible as $name';
  }

  @override
  String get makeVisible => 'Make visible';

  @override
  String devicesFoundCount(int count) {
    return '$count found';
  }

  @override
  String get openSystemSettings => 'Open system settings';

  @override
  String get updateChecking => 'Checking for updates...';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableBody(String current, String latest) {
    return 'Current: v$current\nLatest: v$latest\n\nA newer version of Throw is available.';
  }

  @override
  String get actionLater => 'Later';

  @override
  String get actionOpenRelease => 'Open release';

  @override
  String updateUpToDate(String current) {
    return 'You are up to date (v$current).';
  }

  @override
  String updateFailed(String error) {
    return 'Could not check updates: $error';
  }

  @override
  String get settingsCheckUpdates => 'Check for updates';

  @override
  String settingsCurrentVersion(String version) {
    return 'Current version: v$version';
  }

  @override
  String settingsAboutBody(String version) {
    return 'Throw v$version • Offline file sharing';
  }
}
