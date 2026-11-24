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
}
