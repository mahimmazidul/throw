// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bengali Bangla (`bn`).
class AppLocalizationsBn extends AppLocalizations {
  AppLocalizationsBn([String locale = 'bn']) : super(locale);

  @override
  String get appTitle => 'Throw';

  @override
  String get tagline => 'কাছাকাছি ডিভিসে ফাইল ও টেক্সট পাঠান।';

  @override
  String get navHome => 'হোম';

  @override
  String get navDiscover => 'খুঁজুন';

  @override
  String get navTransfers => 'ট্রান্সফার';

  @override
  String get navSettings => 'সেটিংস';

  @override
  String get actionSend => 'পাঠান';

  @override
  String get actionCancel => 'বাতিল';

  @override
  String get actionAccept => 'গ্রহণ করুন';

  @override
  String get actionReject => 'নাকচ করুন';

  @override
  String get actionRetry => 'আবার চেষ্টা করুন';

  @override
  String get actionCopy => 'কপি';

  @override
  String get actionPaste => 'পেস্ট';

  @override
  String get actionClose => 'বন্ধ';

  @override
  String get stateSearching => 'ডিভিস খোঁজা হচ্ছে…';

  @override
  String get stateNoDevices => 'এখনো কোনো ডিভিস পাওয়া যায়নি।';

  @override
  String get stateConnected => 'সংযুক্ত';

  @override
  String get stateConnecting => 'সংযোগ হচ্ছে…';

  @override
  String get stateTransferring => 'পাঠানো হচ্ছে…';

  @override
  String get stateComplete => 'ট্রান্সফার সম্পন্ন';

  @override
  String get stateFailed => 'ট্রান্সফার ব্যর্থ হয়েছে';

  @override
  String get stateCancelled => 'বাতিল হয়েছে';

  @override
  String get stateRejected => 'প্রত্যাখ্যাত';

  @override
  String get incomingTitle => 'নতুন ট্রান্সফার';

  @override
  String incomingFrom(String device) {
    return '$device থেকে';
  }

  @override
  String get speedWifi => 'ওয়াইফাই ডাইরেক্ট · ~২৫০ মেগাবিট';

  @override
  String get speedBluetooth => 'ব্লুটুথ · ~৩ মেগাবিট';

  @override
  String get settingsLanguage => 'ভাষা';

  @override
  String get settingsTheme => 'থিম';

  @override
  String get settingsDeviceName => 'ডিভিসের নাম';

  @override
  String get settingsAbout => 'সম্পর্কে';

  @override
  String get permissionTitle => 'অনুমতি দরকার';

  @override
  String get permissionBody =>
      'কাছাকাছি ডিভিস খুঁজে পেতে থ্রো-র ডিভিস অ্যাক্সেস দরকার।';

  @override
  String get errorBluetoothOff =>
      'ব্লুটুথ বন্ধ আছে। ডিভিস খুঁজতে এটি চালু করুন।';

  @override
  String get errorLocationOff =>
      'লোকেশন সার্ভিস বন্ধ। অ্যান্ড্রয়েডে ডিভিস খুঁজতে এটি দরকার।';

  @override
  String get sendClipboardHint => 'পাঠানোর জন্য কিছু লিখুন…';

  @override
  String statusConnectedCount(int count) {
    return '$count টি সংযুক্ত';
  }

  @override
  String get statusNoDevice => 'কোনো ডিভাইস সংযুক্ত নেই';

  @override
  String get transportBoth => 'WiFi Direct / Bluetooth';

  @override
  String get featureDirectSharing => 'সরাসরি লোকাল শেয়ারিং';

  @override
  String shareInboxTitle(int count) {
    return 'থ্রোতে পাওয়া ফাইল ($count)';
  }

  @override
  String shareInboxMore(int count) {
    return '+$count টি আরও';
  }

  @override
  String get shareInboxSend => 'পাওয়া ফাইল পাঠান';

  @override
  String get sendTextTitle => 'লেখা পাঠান';

  @override
  String get sendFilesTitle => 'ফাইল পাঠান';

  @override
  String get sendFilesHint => 'এক বা একাধিক ফাইল বেছে পাঠান।';

  @override
  String get actionPick => 'বেছে নিন';

  @override
  String visibleAs(String name) {
    return '$name নামে দৃশ্যমান';
  }

  @override
  String get makeVisible => 'দৃশ্যমান করুন';

  @override
  String devicesFoundCount(int count) {
    return '$count টি পাওয়া গেছে';
  }

  @override
  String get openSystemSettings => 'সিস্টেম সেটিংস খুলুন';

  @override
  String get updateChecking => 'আপডেট পরীক্ষা করা হচ্ছে...';

  @override
  String get updateAvailableTitle => 'আপডেট পাওয়া গেছে';

  @override
  String updateAvailableBody(String current, String latest) {
    return 'বর্তমান: v$current\nসর্বশেষ: v$latest\n\nথ্রোর নতুন সংস্করণ এসেছে।';
  }

  @override
  String get actionLater => 'পরে';

  @override
  String get actionOpenRelease => 'রিলিজ খুলুন';

  @override
  String updateUpToDate(String current) {
    return 'আপনি হালনাগাদ আছেন (v$current)।';
  }

  @override
  String updateFailed(String error) {
    return 'আপডেট পরীক্ষা করা যায়নি: $error';
  }

  @override
  String get settingsCheckUpdates => 'আপডেট পরীক্ষা করুন';

  @override
  String settingsCurrentVersion(String version) {
    return 'বর্তমান সংস্করণ: v$version';
  }

  @override
  String settingsAboutBody(String version) {
    return 'থ্রো v$version • অফলাইন ফাইল শেয়ারিং';
  }

  @override
  String get errorPermissionDenied =>
      'কাছাকাছি ডিভিস খুঁজে বা পাঠানোর জন্য থ্রো-র নিকটবর্তী ডিভিস অ্যাক্সেস দরকার।';

  @override
  String get errorPermissionBlocked =>
      'থ্রোর জন্য নিকটবর্তী অ্যাক্সেস বন্ধ আছে। চালিয়ে যেতে সিস্টেম সেটিংসে অনুমতি দিন।';

  @override
  String get errorDiscoveryFailed =>
      'ডিভিস খুঁজা ব্যর্থ হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get errorTransferFailed =>
      'ট্রান্সফার সম্পূর্ণ হয়নি। অন্য ডিভাইসটি কাছে আছে কিনা দেখে আবার চেষ্টা করুন।';

  @override
  String errorUnknown(String detail) {
    return 'কিছু একটা সমস্যা হয়েছে: $detail';
  }

  @override
  String get transfersSubtitle => 'চলমান ও সাম্প্রতিক ট্রান্সফার দেখুন।';

  @override
  String get homeTagline => 'কাছাকাছি ডিভাইসে সরাসরি ফাইল ও টেক্সট পাঠান।';

  @override
  String get homeChooseDevice => 'ডিভাইস বেছে নিন';

  @override
  String get homePickDeviceFirst =>
      'কিছু পাঠাতে আগে উপরে একটি ডিভাইস বেছে নিন।';

  @override
  String get actionClear => 'মুছুন';

  @override
  String get actionRefresh => 'রিফ্রেশ';

  @override
  String get discoverScanningHint =>
      'খোঁজা হচ্ছে… দুই ডিভাইসেই Throw খোলা রাখুন।';

  @override
  String get discoverIdleHint => 'ডিভাইস খুঁজুন, বা এই ডিভাইসটি দৃশ্যমান করুন।';

  @override
  String get settingsSubtitle => 'আপনার ডিভাইস, ভাষা ও চেহারা নিয়ন্ত্রণ করুন।';

  @override
  String get settingsEditName => 'নাম বদলান';

  @override
  String get transfersEmptyTitle => 'এখনও কিছু পাঠানো হয়নি';

  @override
  String get transfersEmptyBody =>
      'আপনার পাঠানো বা গ্রহণ করা ফাইল ও টেক্সট এখানে দেখা যাবে।';

  @override
  String get transfersOpen => 'খুলুন';

  @override
  String get receivedTitle => 'গৃহীত';

  @override
  String get receivedEmptyTitle => 'এখনও কিছু পাওয়া যায়নি';

  @override
  String get receivedEmptyBody =>
      'আসা টেক্সট ও ফাইল নতুন থেকে পুরোনো ক্রমে এখানে জমা থাকবে।';

  @override
  String get receivedActionCopy => 'কপি করুন';

  @override
  String get receivedActionCopied => 'ক্লিপবোর্ডে কপি হয়েছে';

  @override
  String get receivedActionSave => 'সেভ করুন';

  @override
  String get receivedActionOpenFile => 'ফাইল খুলুন';

  @override
  String get receivedOpenFailed => 'সেই আইটেমটি খোলা যায়নি।';

  @override
  String get receivedShareMissing =>
      'ফাইলটির কোনো সেভ করা ঠিকানা নেই, তাই খোলা যাবে না।';

  @override
  String get receivedTypeText => 'টেক্সট';

  @override
  String get receivedTypeFile => 'ফাইল';

  @override
  String get settingsThisDevice => 'এই ডিভাইস';

  @override
  String get homeSectionThrow => 'কিছু পাঠান';

  @override
  String get homeSectionRecent => 'সাম্প্রতিক গৃহীত';

  @override
  String get homeNoPeersTitle => 'এখনও কোনো ডিভাইস সংযুক্ত নয়';

  @override
  String get homeNoPeersBody =>
      'খুঁজুন ট্যাব খুলুন, এই ডিভাইসটি দৃশ্যমান করুন, তারপর অন্যটির সাথে সংযোগ করুন।';

  @override
  String get receivedCaption => 'যা আসে সব এখানেই থাকে।';

  @override
  String get stateSending => 'পাঠানো হচ্ছে…';

  @override
  String get stateReceiving => 'গ্রহণ করা হচ্ছে…';

  @override
  String transferTo(String device) {
    return '$device-এর কাছে';
  }

  @override
  String transferFrom(String device) {
    return '$device থেকে';
  }

  @override
  String timeLeft(int seconds) {
    return '$seconds সেকেন্ড বাকি';
  }

  @override
  String get speedMeasuring => 'গতি মাপা হচ্ছে…';

  @override
  String speedOf(String speed) {
    return '$speed';
  }

  @override
  String savedToFolder(String folder) {
    return '$folder-এ সংরক্ষিত';
  }

  @override
  String fromDevice(String device) {
    return '$device থেকে';
  }

  @override
  String receivedSavedIn(String folder) {
    return 'ফাইলগুলো $folder-এ সংরক্ষিত হচ্ছে';
  }

  @override
  String receivedEmptyWhere(String folder) {
    return 'যে ফাইলগুলো আসবে সেগুলো $folder-এ সংরক্ষিত হবে, সবচেয়ে নতুনটি আগে। এখান থেকেই খুলতে পারবেন।';
  }

  @override
  String get receivedActionCopyPath => 'অবস্থান কপি';

  @override
  String get receivedPathCopied => 'অবস্থান কপি হয়েছে';

  @override
  String get actionOpenFolder => 'ফোল্ডার খুলুন';

  @override
  String get folderUnavailable => 'ফোল্ডার পাওয়া যাচ্ছে না';

  @override
  String get sendTo => 'পাঠান';

  @override
  String get selectPeersHint => 'এক বা একাধিক ডিভাইস বেছে নিন, তারপর পাঠান।';

  @override
  String sendToCount(int count) {
    return '$countটি ডিভাইসে পাঠান';
  }

  @override
  String sentToCount(int sent, int total) {
    return '$totalটির মধ্যে $sentটিতে পাঠানো হয়েছে';
  }

  @override
  String get sendPartlyFailed =>
      'কিছু ডিভাইস পায়নি। দেখুন সেগুলো এখনও কানেক্টেড আছে কি না।';

  @override
  String selectedCount(int count) {
    return '$countটি বাছাই করা হয়েছে';
  }

  @override
  String get nearbyDevice => 'কাছের ডিভাইস';

  @override
  String nearbyDeviceToken(String token) {
    return 'কাছের ডিভাইস · $token';
  }

  @override
  String get unknownPlatform => 'অজানা ডিভাইস';

  @override
  String get discoverVisibleSwitch => 'কাছের ডিভাইসদের কাছে দৃশ্যমান';

  @override
  String get discoverFindingSwitch => 'ডিভাইস খোঁজা হচ্ছে';

  @override
  String get connectTo => 'কানেক্ট';

  @override
  String get disconnectFrom => 'কানেকশন কাটুন';

  @override
  String connectingTo(String device) {
    return '$device-এর সাথে কানেক্ট হচ্ছে…';
  }

  @override
  String get aboutTitle => 'Throw সম্পর্কে';

  @override
  String aboutVersion(String version, String build) {
    return 'সংস্করণ $version (বিল্ড $build)';
  }

  @override
  String get aboutWhatItIs =>
      'Throw একই নেটওয়ার্কে থাকা ডিভাইসগুলোর মধ্যে ফাইল ও লেখা পাঠায় — কোনো অ্যাকাউন্ট, সার্ভার বা ইন্টারনেট লাগে না। সবকিছু সরাসরি এক ডিভাইস থেকে আরেকটিতে যায়।';

  @override
  String get developerSection => 'নির্মাতা';

  @override
  String get developerName => 'মো. মাজিদুল ইসলাম মহিম';

  @override
  String get developerRole => 'Throw-এর ডিজাইনার ও ডেভেলপার';

  @override
  String get developerLocation => 'খুলনা, বাংলাদেশ';

  @override
  String get linksSection => 'লিংক';

  @override
  String get linkGithub => 'গিটহাব';

  @override
  String get linkWebsite => 'ওয়েবসাইট';

  @override
  String get linkRepository => 'সোর্স কোড';

  @override
  String get linkReleases => 'রিলিজ';

  @override
  String get linkIssues => 'সমস্যা জানান';

  @override
  String get linkLicense => 'লাইসেন্স';

  @override
  String get licenseName => 'এমআইটি লাইসেন্স';

  @override
  String get legalSection => 'আইনি';

  @override
  String get openLinkFailed => 'লিংকটি খোলা গেল না।';

  @override
  String get aboutCredits =>
      'ফ্লাটার দিয়ে তৈরি। ফন্ট: Plus Jakarta Sans ও Hind Siliguri (SIL ওপেন ফন্ট লাইসেন্স)।';

  @override
  String get settingsAboutOpen => 'Throw সম্পর্কে';

  @override
  String get settingsAboutSummary => 'সংস্করণ, নির্মাতা ও লিংক';

  @override
  String get actionAttach => 'ফাইল সংযুক্ত করুন';

  @override
  String get actionSendText => 'লেখা পাঠান';

  @override
  String get composerLabel => 'বার্তা বা নোট';

  @override
  String get composerHint => 'পাঠানোর জন্য কিছু লিখুন…';

  @override
  String get pickFilesFirst => 'পাঠানোর ফাইল বেছে নিন';

  @override
  String get noAppForFile => 'এই ধরনের ফাইল খোলার কোনো অ্যাপ এই ডিভাইসে নেই।';

  @override
  String get transfersActiveSection => 'চলমান';

  @override
  String get transfersRecentSection => 'সাম্প্রতিক';

  @override
  String get transfersClearHistory => 'তালিকা মুছুন';

  @override
  String get transfersCleared => 'ইতিহাস মুছে ফেলা হয়েছে';

  @override
  String get settingsNameHint => 'অন্য ডিভাইস যেভাবে দেখবে';

  @override
  String get settingsDeviceNameHelp =>
      'অন্য ডিভাইস আপনাকে খোঁজার সময় এই নামটিই দেখবে।';

  @override
  String get settingsAppearanceSection => 'অবয়ব';

  @override
  String get settingsGeneralSection => 'সাধারণ';

  @override
  String get settingsAboutSection => 'সম্পর্কে';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageBangla => 'বাংলা';

  @override
  String get themeDark => 'ডার্ক';

  @override
  String get themeLight => 'লাইট';

  @override
  String get receivedSubtitle => 'যা কিছু এসেছে, নতুনটি আগে।';

  @override
  String get errorGeneric => 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';

  @override
  String get errorGenericWithDetail =>
      'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন — বারবার হলে বিস্তারিত লগে রাখা হয়েছে।';

  @override
  String get errorShowDetail => 'বিস্তারিত দেখুন';
}
