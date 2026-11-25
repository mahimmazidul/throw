import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:throw_app/core/atmosphere.dart';
import 'package:throw_app/core/preferences.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/providers/device_provider.dart';
import 'package:throw_app/providers/share_inbox_provider.dart';
import 'package:throw_app/providers/transfer_provider.dart';
import 'package:throw_app/screens/discover_screen.dart';
import 'package:throw_app/screens/home_screen.dart';
import 'package:throw_app/screens/transfer_screen.dart';
import 'device_provider_test.dart' show RecordingService;

class _Svc extends RecordingService {
  @override
  Stream<TransferModel> get transfers => const Stream.empty();
  @override
  Stream<PayloadModel> get receivedPayloads => const Stream.empty();
}

Future<void> _check(WidgetTester t, String label, Widget screen,
    {double width = 360, List<ConnectionRequest> reqs = const [],
     List<DeviceModel> devs = const []}) async {
  t.view.physicalSize = Size(width, 800);
  t.view.devicePixelRatio = 1.0;
  final service = _Svc();
  final prefs = AppPreferences.inMemory();
  await prefs.setDeviceName('Test Phone');
  final provider = DeviceProvider(service: service, preferences: prefs, observeLifecycle: false);
  for (final r in reqs) { service.requestsController.add(r); }
  for (final d in devs) { service.devicesController.add(d); }
  await t.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: provider),
      ChangeNotifierProvider(create: (_) => TransferProvider(service: service)),
      ChangeNotifierProvider(create: (_) => ShareInboxProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThrowTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: screen),
    ),
  ));
  await t.pump(const Duration(milliseconds: 500));
  final e = t.takeException();
  provider.dispose();
  expect(e, isNull, reason: '$label overflows at ${width.toInt()}dp: $e');
}

void main() {
  setUp(() => Atmosphere.enabled = false);

  // Every screen, at the widths Android phones actually use. 360dp is the
  // narrowest common one and is where the incoming-request row used to
  // overflow; 392dp is a Pixel-class width. A layout bug on this scale is
  // invisible on a desktop window and obvious on a phone, so it is checked
  // here rather than left to whoever installs the APK.
  for (final w in [360.0, 392.0]) {
    testWidgets('no screen overflows at ${w.toInt()}dp', (t) async {
      await _check(t, 'Home empty', const HomeScreen(), width: w);
      await _check(t, 'Discover idle', const DiscoverScreen(), width: w);
      await _check(t, 'Discover 2 requests', const DiscoverScreen(), width: w,
        reqs: [
          ConnectionRequest(endpointId: 'a', deviceName: 'Redmi 25080RABDC', receivedAt: DateTime(2026)),
          ConnectionRequest(endpointId: 'b', deviceName: '', receivedAt: DateTime(2026)),
        ]);
      await _check(t, 'Discover with peers', const DiscoverScreen(), width: w,
        devs: [
          DeviceModel(id: 'p1', name: 'Redmi 25080RABDC', platform: DevicePlatform.android,
              channel: TransferChannel.wifiDirect, isConnected: false, lastSeen: DateTime(2026)),
          DeviceModel(id: 'p2', name: '', platform: DevicePlatform.android,
              channel: TransferChannel.wifiDirect, isConnected: true, lastSeen: DateTime(2026)),
        ]);
      await _check(t, 'Transfers', const TransferScreen(), width: w);
    });
  }
}
