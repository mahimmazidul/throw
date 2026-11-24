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
  String get sendClipboardHint => 'আগে কিছু কপি করুন, তারপর পাঠান।';
}
