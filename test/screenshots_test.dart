import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:throw_app/core/preferences.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/providers/device_provider.dart';
import 'package:throw_app/providers/locale_provider.dart';
import 'package:throw_app/providers/share_inbox_provider.dart';
import 'package:throw_app/providers/transfer_provider.dart';
import 'package:throw_app/screens/discover_screen.dart';
import 'package:throw_app/screens/home_screen.dart';
import 'package:throw_app/screens/about_screen.dart';
import 'package:throw_app/screens/settings_screen.dart';
import 'package:throw_app/screens/transfer_screen.dart';
import 'package:throw_app/services/transfer_service.dart';
import 'package:throw_app/widgets/adaptive_nav.dart';

/// Renders every screen at phone size and compares against the committed
/// PNGs in `assets/screenshots/` when `THROW_COMPARE_SCREENSHOTS` is defined.
///
/// Two things made the previous version of this file useless:
///
///  1. The bundled fonts were never registered with the test engine, so every
///     render fell back to Ahem-style boxes — the committed "screenshots" on
///     `main` are white canvases with tofu glyphs in them.
///  2. Without the define it only checked "no exception", which is exactly
///     what a transparent-white theme passes.
///
/// [loadAppFonts] fixes (1); the `compareScreenshots` block plus a
/// `--update-goldens` run in the screenshot workflow covers (2).
Future<void> loadAppFonts() async {
  final fonts = <String, List<String>>{
    'Plus Jakarta Sans': [
      'assets/fonts/PlusJakartaSans/PlusJakartaSans-wght.ttf',
    ],
    'HindSiliguri': [
      'assets/fonts/HindSiliguri-Light.ttf',
      'assets/fonts/HindSiliguri-Regular.ttf',
      'assets/fonts/HindSiliguri-Medium.ttf',
      'assets/fonts/HindSiliguri-SemiBold.ttf',
      'assets/fonts/HindSiliguri-Bold.ttf',
    ],
  };

  // MaterialIcons ships with the SDK cache, not with the app. Without it every
  // icon renders as a tofu box in goldens — which is exactly what the previous
  // committed screenshots show.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final iconFont = File(
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (iconFont.existsSync()) {
      fonts['MaterialIcons'] = [iconFont.path];
    }
  }

  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

class _FakeTransferService implements TransferService {
  _FakeTransferService({
    List<DeviceModel>? seedDevices,
    List<TransferModel>? seedTransfers,
  })  : _seedDevices = seedDevices ?? const [],
        _seedTransfers = seedTransfers ?? const [];

  // A broadcast stream drops events emitted before anyone listens, so seeds
  // are held here and flushed by [flushSeeds] once the providers are attached.
  final List<DeviceModel> _seedDevices;
  final List<TransferModel> _seedTransfers;

  void flushSeeds() {
    for (final d in _seedDevices) {
      _devicesController.add(d);
    }
    for (final t in _seedTransfers) {
      _transfersController.add(t);
    }
  }

  final _devicesController = StreamController<DeviceModel>.broadcast();
  final _transfersController = StreamController<TransferModel>.broadcast();
  final _requestsController = StreamController<ConnectionRequest>.broadcast();
  final _payloadsController = StreamController<PayloadModel>.broadcast();

  @override
  Stream<DeviceModel> get devices => _devicesController.stream;
  @override
  Stream<TransferModel> get transfers => _transfersController.stream;
  @override
  Stream<ConnectionRequest> get connectionRequests =>
      _requestsController.stream;
  @override
  Stream<PayloadModel> get receivedPayloads => _payloadsController.stream;
  @override
  String get localDeviceName => 'Test Device';

  @override
  Future<void> startAdvertising({required String deviceName}) async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  Future<void> connect(DeviceModel device) async {}
  @override
  Future<void> disconnect(String endpointId) async {}
  @override
  Future<void> acceptConnection(String endpointId) async {}
  @override
  Future<void> rejectConnection(String endpointId) async {}
  @override
  Future<void> sendText(
      {required String endpointId, required String text}) async {}
  @override
  Future<void> sendFile(
      {required String endpointId,
      required File file,
      String? displayName,
      int? sizeBytes}) async {}
  @override
  Future<void> cancelTransfer(String transferId) async {}
  @override
  Future<void> dispose() async {
    await _devicesController.close();
    await _transfersController.close();
    await _requestsController.close();
    await _payloadsController.close();
  }
}

/// Renders the screen inside the real adaptive shell (bottom bar on a phone),
/// so the committed PNG shows the app a user actually gets — including the
/// navigation — instead of a bare scaffold.
Widget _wrapScreen(
  Widget child,
  ThemeData theme,
  TransferService service, {
  int navIndex = 0,
  Locale locale = const Locale('en'),
}) {
  final prefs = AppPreferences.inMemory();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider(preferences: prefs)),
      ChangeNotifierProvider(
        create: (_) => DeviceProvider(service: service, preferences: prefs),
      ),
      ChangeNotifierProvider(
        create: (_) => TransferProvider(service: service),
      ),
      ChangeNotifierProvider(create: (_) => ShareInboxProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      // Pins the canvas to the product's dark default: the previous wrapper
      // omitted this, so goldens rendered on the default *light* scaffold —
      // which is how a transparent dark palette slipped through review.
      builder: (context, child) => ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: child!,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdaptiveNav(
        selectedIndex: navIndex,
        onDestinationSelected: (_) {},
        body: child,
      ),
    ),
  );
}

void main() {
  const compareScreenshots = bool.fromEnvironment('THROW_COMPARE_SCREENSHOTS');

  setUpAll(loadAppFonts);

  testWidgets('render app screenshots', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = _FakeTransferService();
    final theme = ThrowTheme.dark();

    final screens = <String, (Widget, int)>{
      'home': (const HomeScreen(), 0),
      'discover': (const DiscoverScreen(), 1),
      'transfers': (const TransferScreen(), 2),
      'settings': (const SettingsScreen(), 3),
      'about': (const AboutScreen(), 3),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(
        _wrapScreen(entry.value.$1, theme, service, navIndex: entry.value.$2),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 200),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
      final exception = tester.takeException();
      expect(exception, isNull, reason: '${entry.key}: $exception');
      if (compareScreenshots) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../assets/screenshots/${entry.key}.png'),
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();
  });

  testWidgets('render Bangla home screenshot', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = _FakeTransferService();
    await tester.pumpWidget(_wrapScreen(
      const HomeScreen(),
      ThrowTheme.dark(),
      service,
      locale: const Locale('bn'),
    ));
    service.flushSeeds();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 200),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(tester.takeException(), isNull);
    if (compareScreenshots) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../assets/screenshots/home_bn.png'),
      );
    }
  });

  testWidgets('render empty-state screenshots', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final device = DeviceModel(
      id: 'd1',
      name: 'Pixel 8',
      platform: DevicePlatform.android,
      channel: TransferChannel.wifiDirect,
      isConnected: true,
      lastSeen: DateTime(2026, 11, 24, 12),
    );
    final service = _FakeTransferService(seedDevices: [device]);
    final theme = ThrowTheme.dark();

    for (final entry in {
      'home': (const HomeScreen(), 0),
      'discover': (const DiscoverScreen(), 1),
    }.entries) {
      await tester.pumpWidget(
        _wrapScreen(entry.value.$1, theme, service, navIndex: entry.value.$2),
      );
      service.flushSeeds();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 200),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
      final exception = tester.takeException();
      expect(exception, isNull, reason: '${entry.key}: $exception');
      if (compareScreenshots) {
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../assets/screenshots/${entry.key}_with_device.png',
          ),
        );
      }
    }
  });
}
