import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../lib/core/theme.dart';
import '../lib/l10n/app_localizations.dart';
import '../lib/models/device_model.dart';
import '../lib/models/payload_model.dart';
import '../lib/models/transfer_model.dart';
import '../lib/providers/device_provider.dart';
import '../lib/providers/locale_provider.dart';
import '../lib/providers/transfer_provider.dart';
import '../lib/screens/discover_screen.dart';
import '../lib/screens/home_screen.dart';
import '../lib/screens/settings_screen.dart';
import '../lib/screens/transfer_screen.dart';
import '../lib/services/transfer_service.dart';

class _FakeTransferService implements TransferService {
  @override
  Stream<DeviceModel> get devices => const Stream.empty();
  @override
  Stream<TransferModel> get transfers => const Stream.empty();
  @override
  Stream<ConnectionRequest> get connectionRequests => const Stream.empty();
  @override
  Stream<PayloadModel> get receivedPayloads => const Stream.empty();
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
  Future<void> sendText({required String endpointId, required String text}) async {}
  @override
  Future<void> sendFile({required String endpointId, required dynamic file}) async {}
  @override
  Future<void> cancelTransfer(String transferId) async {}
  @override
  Future<void> dispose() async {}
}

Widget _wrapScreen(Widget child) {
  final fakeService = _FakeTransferService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider(
        create: (_) => DeviceProvider(service: fakeService),
      ),
      ChangeNotifierProvider(
        create: (_) => TransferProvider(service: fakeService),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThrowTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('render app screenshots', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final screens = {
      'home': const HomeScreen(),
      'discover': const DiscoverScreen(),
      'transfers': const TransferScreen(),
      'settings': const SettingsScreen(),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(_wrapScreen(entry.value));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../assets/screenshots/${entry.key}.png'),
      );
    }
  });
}
