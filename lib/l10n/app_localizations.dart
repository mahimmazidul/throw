import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Throw'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Send files and text to nearby devices.'**
  String get tagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get navTransfers;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get actionAccept;

  /// No description provided for @actionReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get actionReject;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get actionPaste;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @stateSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices…'**
  String get stateSearching;

  /// No description provided for @stateNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices nearby yet.'**
  String get stateNoDevices;

  /// No description provided for @stateConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get stateConnected;

  /// No description provided for @stateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get stateConnecting;

  /// No description provided for @stateTransferring.
  ///
  /// In en, this message translates to:
  /// **'Transferring…'**
  String get stateTransferring;

  /// No description provided for @stateComplete.
  ///
  /// In en, this message translates to:
  /// **'Transfer complete'**
  String get stateComplete;

  /// No description provided for @stateFailed.
  ///
  /// In en, this message translates to:
  /// **'Transfer failed'**
  String get stateFailed;

  /// No description provided for @stateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get stateCancelled;

  /// No description provided for @stateRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get stateRejected;

  /// No description provided for @incomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Incoming transfer'**
  String get incomingTitle;

  /// Incoming transfer request, name of the sending device
  ///
  /// In en, this message translates to:
  /// **'From {device}'**
  String incomingFrom(String device);

  /// No description provided for @speedWifi.
  ///
  /// In en, this message translates to:
  /// **'WiFi Direct · ~250 Mbps'**
  String get speedWifi;

  /// No description provided for @speedBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth · ~3 Mbps'**
  String get speedBluetooth;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get settingsDeviceName;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @permissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions needed'**
  String get permissionTitle;

  /// No description provided for @permissionBody.
  ///
  /// In en, this message translates to:
  /// **'Throw needs nearby device access to find and transfer to devices around you.'**
  String get permissionBody;

  /// No description provided for @errorBluetoothOff.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth is off. Turn it on to discover devices.'**
  String get errorBluetoothOff;

  /// No description provided for @errorLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are off. Nearby discovery needs them on Android.'**
  String get errorLocationOff;

  /// No description provided for @sendClipboardHint.
  ///
  /// In en, this message translates to:
  /// **'Write a note to send…'**
  String get sendClipboardHint;

  /// No description provided for @statusConnectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} connected'**
  String statusConnectedCount(int count);

  /// No description provided for @statusNoDevice.
  ///
  /// In en, this message translates to:
  /// **'No device connected'**
  String get statusNoDevice;

  /// No description provided for @transportBoth.
  ///
  /// In en, this message translates to:
  /// **'WiFi Direct / Bluetooth'**
  String get transportBoth;

  /// No description provided for @featureDirectSharing.
  ///
  /// In en, this message translates to:
  /// **'Direct local sharing'**
  String get featureDirectSharing;

  /// No description provided for @shareInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Shared to Throw ({count})'**
  String shareInboxTitle(int count);

  /// No description provided for @shareInboxMore.
  ///
  /// In en, this message translates to:
  /// **'+{count} more'**
  String shareInboxMore(int count);

  /// No description provided for @shareInboxSend.
  ///
  /// In en, this message translates to:
  /// **'Send shared items'**
  String get shareInboxSend;

  /// No description provided for @sendTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Send text'**
  String get sendTextTitle;

  /// No description provided for @sendFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Send files'**
  String get sendFilesTitle;

  /// No description provided for @sendFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Pick one or more files and send them.'**
  String get sendFilesHint;

  /// No description provided for @actionPick.
  ///
  /// In en, this message translates to:
  /// **'Pick'**
  String get actionPick;

  /// No description provided for @visibleAs.
  ///
  /// In en, this message translates to:
  /// **'Visible as {name}'**
  String visibleAs(String name);

  /// No description provided for @makeVisible.
  ///
  /// In en, this message translates to:
  /// **'Make visible'**
  String get makeVisible;

  /// No description provided for @devicesFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String devicesFoundCount(int count);

  /// No description provided for @openSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get openSystemSettings;

  /// No description provided for @updateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates...'**
  String get updateChecking;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Current: v{current}\nLatest: v{latest}\n\nA newer version of Throw is available.'**
  String updateAvailableBody(String current, String latest);

  /// No description provided for @actionLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get actionLater;

  /// No description provided for @actionOpenRelease.
  ///
  /// In en, this message translates to:
  /// **'Open release'**
  String get actionOpenRelease;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You are up to date (v{current}).'**
  String updateUpToDate(String current);

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check updates: {error}'**
  String updateFailed(String error);

  /// No description provided for @settingsCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckUpdates;

  /// No description provided for @settingsCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version: v{version}'**
  String settingsCurrentVersion(String version);

  /// No description provided for @settingsAboutBody.
  ///
  /// In en, this message translates to:
  /// **'Throw v{version} • Offline file sharing'**
  String settingsAboutBody(String version);

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Throw needs nearby device access to find and send to the devices around you.'**
  String get errorPermissionDenied;

  /// No description provided for @errorPermissionBlocked.
  ///
  /// In en, this message translates to:
  /// **'Nearby access is turned off for Throw. Allow it in system settings to continue.'**
  String get errorPermissionBlocked;

  /// No description provided for @errorDiscoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'Scanning for devices failed. Try again.'**
  String get errorDiscoveryFailed;

  /// No description provided for @errorTransferFailed.
  ///
  /// In en, this message translates to:
  /// **'That transfer didn\'t finish. Check the other device is nearby, then try again.'**
  String get errorTransferFailed;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {detail}'**
  String errorUnknown(String detail);

  /// No description provided for @transfersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track active and recent transfers.'**
  String get transfersSubtitle;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Send files and text directly to nearby devices.'**
  String get homeTagline;

  /// No description provided for @homeChooseDevice.
  ///
  /// In en, this message translates to:
  /// **'Choose a device'**
  String get homeChooseDevice;

  /// No description provided for @homePickDeviceFirst.
  ///
  /// In en, this message translates to:
  /// **'Pick a device above to send something.'**
  String get homePickDeviceFirst;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @discoverScanningHint.
  ///
  /// In en, this message translates to:
  /// **'Scanning… keep Throw open on both devices.'**
  String get discoverScanningHint;

  /// No description provided for @discoverIdleHint.
  ///
  /// In en, this message translates to:
  /// **'Find devices, or make this one visible.'**
  String get discoverIdleHint;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your device, language, and appearance.'**
  String get settingsSubtitle;

  /// No description provided for @settingsEditName.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get settingsEditName;

  /// No description provided for @transfersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing transferred yet'**
  String get transfersEmptyTitle;

  /// No description provided for @transfersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Files and text you send or receive will appear here.'**
  String get transfersEmptyBody;

  /// No description provided for @transfersOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get transfersOpen;

  /// No description provided for @receivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get receivedTitle;

  /// No description provided for @receivedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing received yet'**
  String get receivedEmptyTitle;

  /// No description provided for @receivedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Text and files that arrive will be saved here with the newest first.'**
  String get receivedEmptyBody;

  /// No description provided for @receivedActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get receivedActionCopy;

  /// No description provided for @receivedActionCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get receivedActionCopied;

  /// No description provided for @receivedActionSave.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get receivedActionSave;

  /// No description provided for @receivedActionOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get receivedActionOpenFile;

  /// No description provided for @receivedOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that item.'**
  String get receivedOpenFailed;

  /// No description provided for @receivedShareMissing.
  ///
  /// In en, this message translates to:
  /// **'That file has no saved path, so it cannot be opened.'**
  String get receivedShareMissing;

  /// No description provided for @receivedTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get receivedTypeText;

  /// No description provided for @receivedTypeFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get receivedTypeFile;

  /// No description provided for @settingsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsThisDevice;

  /// No description provided for @homeSectionThrow.
  ///
  /// In en, this message translates to:
  /// **'Throw something'**
  String get homeSectionThrow;

  /// No description provided for @homeSectionRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently received'**
  String get homeSectionRecent;

  /// No description provided for @homeNoPeersTitle.
  ///
  /// In en, this message translates to:
  /// **'No device connected yet'**
  String get homeNoPeersTitle;

  /// No description provided for @homeNoPeersBody.
  ///
  /// In en, this message translates to:
  /// **'Open Discover, make this device visible, then connect to the other one.'**
  String get homeNoPeersBody;

  /// No description provided for @receivedCaption.
  ///
  /// In en, this message translates to:
  /// **'Everything that arrives stays here.'**
  String get receivedCaption;

  /// No description provided for @stateSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get stateSending;

  /// No description provided for @stateReceiving.
  ///
  /// In en, this message translates to:
  /// **'Receiving…'**
  String get stateReceiving;

  /// No description provided for @transferTo.
  ///
  /// In en, this message translates to:
  /// **'to {device}'**
  String transferTo(String device);

  /// No description provided for @transferFrom.
  ///
  /// In en, this message translates to:
  /// **'from {device}'**
  String transferFrom(String device);

  /// No description provided for @timeLeft.
  ///
  /// In en, this message translates to:
  /// **'{seconds} s left'**
  String timeLeft(int seconds);

  /// No description provided for @speedMeasuring.
  ///
  /// In en, this message translates to:
  /// **'measuring speed…'**
  String get speedMeasuring;

  /// No description provided for @speedOf.
  ///
  /// In en, this message translates to:
  /// **'{speed}'**
  String speedOf(String speed);

  /// No description provided for @savedToFolder.
  ///
  /// In en, this message translates to:
  /// **'Saved in {folder}'**
  String savedToFolder(String folder);

  /// No description provided for @fromDevice.
  ///
  /// In en, this message translates to:
  /// **'from {device}'**
  String fromDevice(String device);

  /// No description provided for @receivedSavedIn.
  ///
  /// In en, this message translates to:
  /// **'Files are saved in {folder}'**
  String receivedSavedIn(String folder);

  /// No description provided for @receivedEmptyWhere.
  ///
  /// In en, this message translates to:
  /// **'Files that arrive are saved in {folder}, newest first. You can open them from here or from your file manager.'**
  String receivedEmptyWhere(String folder);

  /// No description provided for @receivedActionCopyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy location'**
  String get receivedActionCopyPath;

  /// No description provided for @receivedPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Location copied'**
  String get receivedPathCopied;

  /// No description provided for @actionOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get actionOpenFolder;

  /// No description provided for @folderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Folder unavailable'**
  String get folderUnavailable;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get sendTo;

  /// No description provided for @selectPeersHint.
  ///
  /// In en, this message translates to:
  /// **'Pick one or more devices, then send.'**
  String get selectPeersHint;

  /// No description provided for @sendToCount.
  ///
  /// In en, this message translates to:
  /// **'Send to {count}'**
  String sendToCount(int count);

  /// No description provided for @sentToCount.
  ///
  /// In en, this message translates to:
  /// **'Sent to {sent} of {total}'**
  String sentToCount(int sent, int total);

  /// No description provided for @sendPartlyFailed.
  ///
  /// In en, this message translates to:
  /// **'Some devices did not receive it. Check that they are still connected.'**
  String get sendPartlyFailed;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @nearbyDevice.
  ///
  /// In en, this message translates to:
  /// **'Nearby device'**
  String get nearbyDevice;

  /// No description provided for @nearbyDeviceToken.
  ///
  /// In en, this message translates to:
  /// **'Nearby device · {token}'**
  String nearbyDeviceToken(String token);

  /// No description provided for @unknownPlatform.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get unknownPlatform;

  /// No description provided for @discoverVisibleSwitch.
  ///
  /// In en, this message translates to:
  /// **'Visible to nearby devices'**
  String get discoverVisibleSwitch;

  /// No description provided for @discoverFindingSwitch.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices'**
  String get discoverFindingSwitch;

  /// No description provided for @connectTo.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectTo;

  /// No description provided for @disconnectFrom.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectFrom;

  /// No description provided for @connectingTo.
  ///
  /// In en, this message translates to:
  /// **'Connecting to {device}…'**
  String connectingTo(String device);

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Throw'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutWhatItIs.
  ///
  /// In en, this message translates to:
  /// **'Throw sends files and text between devices on the same network, with no account, no server and no internet. Everything moves directly from one device to the other.'**
  String get aboutWhatItIs;

  /// No description provided for @developerSection.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developerSection;

  /// No description provided for @developerName.
  ///
  /// In en, this message translates to:
  /// **'Md. Mazidul Islam Mahim'**
  String get developerName;

  /// No description provided for @developerRole.
  ///
  /// In en, this message translates to:
  /// **'Designer and developer of Throw'**
  String get developerRole;

  /// No description provided for @developerLocation.
  ///
  /// In en, this message translates to:
  /// **'Khulna, Bangladesh'**
  String get developerLocation;

  /// No description provided for @linksSection.
  ///
  /// In en, this message translates to:
  /// **'Links'**
  String get linksSection;

  /// No description provided for @linkGithub.
  ///
  /// In en, this message translates to:
  /// **'GitHub'**
  String get linkGithub;

  /// No description provided for @linkWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get linkWebsite;

  /// No description provided for @linkRepository.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get linkRepository;

  /// No description provided for @linkReleases.
  ///
  /// In en, this message translates to:
  /// **'Releases'**
  String get linkReleases;

  /// No description provided for @linkIssues.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get linkIssues;

  /// No description provided for @linkLicense.
  ///
  /// In en, this message translates to:
  /// **'Licence'**
  String get linkLicense;

  /// No description provided for @licenseName.
  ///
  /// In en, this message translates to:
  /// **'MIT Licence'**
  String get licenseName;

  /// No description provided for @legalSection.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legalSection;

  /// No description provided for @openLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that link.'**
  String get openLinkFailed;

  /// No description provided for @aboutCredits.
  ///
  /// In en, this message translates to:
  /// **'Built with Flutter. Fonts: Plus Jakarta Sans and Hind Siliguri (SIL Open Font License).'**
  String get aboutCredits;

  /// No description provided for @settingsAboutOpen.
  ///
  /// In en, this message translates to:
  /// **'About Throw'**
  String get settingsAboutOpen;

  /// No description provided for @settingsAboutSummary.
  ///
  /// In en, this message translates to:
  /// **'Version, developer and links'**
  String get settingsAboutSummary;

  /// No description provided for @actionAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach a file'**
  String get actionAttach;

  /// No description provided for @actionSendText.
  ///
  /// In en, this message translates to:
  /// **'Send text'**
  String get actionSendText;

  /// No description provided for @composerLabel.
  ///
  /// In en, this message translates to:
  /// **'Message or note'**
  String get composerLabel;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Type something to send…'**
  String get composerHint;

  /// No description provided for @pickFilesFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose files to send'**
  String get pickFilesFirst;

  /// No description provided for @noAppForFile.
  ///
  /// In en, this message translates to:
  /// **'No app on this device can open this file type.'**
  String get noAppForFile;

  /// No description provided for @transfersActiveSection.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get transfersActiveSection;

  /// No description provided for @transfersRecentSection.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get transfersRecentSection;

  /// No description provided for @transfersClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get transfersClearHistory;

  /// No description provided for @transfersCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get transfersCleared;

  /// No description provided for @settingsNameHint.
  ///
  /// In en, this message translates to:
  /// **'Shown to other devices'**
  String get settingsNameHint;

  /// No description provided for @settingsDeviceNameHelp.
  ///
  /// In en, this message translates to:
  /// **'This is the name other devices see when they look for you.'**
  String get settingsDeviceNameHelp;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsGeneralSection.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneralSection;

  /// No description provided for @settingsAboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutSection;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageBangla.
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get languageBangla;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @receivedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything that arrived, newest first.'**
  String get receivedSubtitle;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;

  /// No description provided for @errorGenericWithDetail.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again — if it keeps happening, the details have been logged.'**
  String get errorGenericWithDetail;

  /// No description provided for @errorShowDetail.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get errorShowDetail;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Temporary files'**
  String get settingsStorage;

  /// No description provided for @settingsStorageSection.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorageSection;

  /// No description provided for @settingsStorageEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing held'**
  String get settingsStorageEmpty;

  /// No description provided for @settingsStorageInUse.
  ///
  /// In en, this message translates to:
  /// **'{size} in temporary copies'**
  String settingsStorageInUse(String size);

  /// No description provided for @settingsStorageClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsStorageClear;

  /// No description provided for @settingsStorageCleared.
  ///
  /// In en, this message translates to:
  /// **'Temporary copies deleted'**
  String get settingsStorageCleared;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
