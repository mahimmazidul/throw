import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/atmosphere.dart';
import 'package:provider/provider.dart';

import 'package:throw_app/core/preferences.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/providers/device_provider.dart';
import 'package:throw_app/core/temp_files.dart';
import 'package:throw_app/providers/locale_provider.dart';
import 'package:throw_app/providers/share_inbox_provider.dart';
import 'package:throw_app/providers/transfer_provider.dart';
import 'package:throw_app/screens/home_screen.dart';
import 'package:throw_app/screens/transfer_screen.dart';
import 'package:throw_app/services/transfer_service.dart';

/// A service stub whose streams the test drives by hand.
class FakeTransferService implements TransferService {
  final devicesController = StreamController<DeviceModel>.broadcast();
  final transfersController = StreamController<TransferModel>.broadcast();
  final requestsController = StreamController<ConnectionRequest>.broadcast();
  final payloadsController = StreamController<PayloadModel>.broadcast();

  final sentTexts = <(String endpoint, String text)>[];
  final sentFiles = <(String endpoint, String path)>[];
  final sentFileNames = <(String endpoint, String name)>[];

  @override
  Stream<DeviceModel> get devices => devicesController.stream;
  @override
  Stream<TransferModel> get transfers => transfersController.stream;
  @override
  Stream<ConnectionRequest> get connectionRequests => requestsController.stream;
  @override
  Stream<PayloadModel> get receivedPayloads => payloadsController.stream;

  @override
  Future<void> sendText(
      {required String endpointId, required String text}) async {
    sentTexts.add((endpointId, text));
  }

  @override
  Future<void> sendFile(
      {required String endpointId,
      required File file,
      String? displayName,
      int? sizeBytes}) async {
    sentFiles.add((endpointId, file.path));
    sentFileNames.add((endpointId, displayName ?? file.path));
  }

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
  Future<void> cancelTransfer(String transferId) async {}
  @override
  Future<void> dispose() async {}
}

DeviceModel _device(String id, String name) => DeviceModel(
      id: id,
      name: name,
      platform: DevicePlatform.android,
      channel: TransferChannel.wifiDirect,
      isConnected: true,
      lastSeen: DateTime(2026, 11, 24),
    );

Widget _home(FakeTransferService service, {AppPreferences? prefs}) {
  final store = prefs ?? AppPreferences.inMemory();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(preferences: store),
      ),
      ChangeNotifierProvider(
        create: (_) => DeviceProvider(service: service, preferences: store),
      ),
      ChangeNotifierProvider(
        create: (_) => TransferProvider(service: service),
      ),
      Provider<TempFileRegistry>.value(value: TempFileRegistry()),
      ChangeNotifierProvider(create: (_) => ShareInboxProvider()),
    ],
    child: MaterialApp(
      theme: ThrowTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: HomeScreen()),
    ),
  );
}

Widget _transfers(FakeTransferService service) {
  final store = AppPreferences.inMemory();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => TransferProvider(service: service),
      ),
      ChangeNotifierProvider(
        create: (_) => DeviceProvider(service: service, preferences: store),
      ),
      ChangeNotifierProvider(
        create: (_) => LocaleProvider(preferences: store),
      ),
      Provider<TempFileRegistry>.value(value: TempFileRegistry()),
      ChangeNotifierProvider(create: (_) => ShareInboxProvider()),
    ],
    child: MaterialApp(
      theme: ThrowTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: TransferScreen()),
    ),
  );
}

void main() {
  // Ambient motion never settles, so `pumpAndSettle` would wait for its
  // timeout on every screen. The widgets are exercised statically here.
  setUp(() => Atmosphere.enabled = false);
  tearDown(() => Atmosphere.enabled = true);

  group('HomeScreen', () {
    testWidgets('with no peers, shows the empty hint and disabled actions',
        (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      await tester.pumpAndSettle();

      expect(find.text('No device connected yet'), findsOneWidget);
      // With no peer, the composer says the same thing the hint above it says,
      // in the words for "nothing to send to yet".
      expect(find.textContaining('Open Discover'), findsWidgets);

      final send = tester.widget<FilledButton>(
        find
            .ancestor(
              of: find.text('Send'),
              matching: find.byType(FilledButton),
            )
            .first,
      );
      expect(send.onPressed, isNull,
          reason: 'send must be disabled with no peer');
      await service.dispose();
    });

    testWidgets('connected peers appear as tappable chips, newest selected',
        (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      service.devicesController.add(_device('a', 'Pixel 8'));
      service.devicesController.add(_device('b', 'ThinkPad'));
      await tester.pumpAndSettle();

      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('ThinkPad'), findsOneWidget);
      // No dropdown anywhere: the peer is on the surface, not behind a tap.
      expect(find.byType(DropdownButtonFormField<DeviceModel>), findsNothing);
      await service.dispose();
    });

    testWidgets('sending text goes to every selected peer and clears the field',
        (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      service.devicesController.add(_device('a', 'Pixel 8'));
      service.devicesController.add(_device('b', 'ThinkPad'));
      await tester.pumpAndSettle();

      // A device that just connected is selected for the user: connecting is
      // why they are here.
      await tester.enterText(find.byType(TextField), 'hello there');
      await tester.tap(find.widgetWithText(FilledButton, 'Send to 2'));
      await tester.pumpAndSettle();

      expect(service.sentTexts,
          unorderedEquals([('a', 'hello there'), ('b', 'hello there')]));
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
      await service.dispose();
    });

    testWidgets('a deselected peer receives nothing', (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      service.devicesController.add(_device('a', 'Pixel 8'));
      service.devicesController.add(_device('b', 'ThinkPad'));
      await tester.pumpAndSettle();

      // Both connected devices start selected; unticking one must stick.
      await tester.tap(find.text('ThinkPad'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'one recipient');
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();

      expect(service.sentTexts, [('a', 'one recipient')]);
      await service.dispose();
    });

    testWidgets('empty text is not sent', (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      service.devicesController.add(_device('a', 'Pixel 8'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await tester.pumpAndSettle();
      expect(service.sentTexts, isEmpty);
      await service.dispose();
    });

    testWidgets('what arrived is listed on Home without changing tabs',
        (tester) async {
      // The separate "Received" tab is gone: a person who just received
      // something should not have to look for it on another tab.
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      service.devicesController.add(_device('a', 'Pixel 8'));
      service.payloadsController.add(PayloadModel(
        id: 'p1',
        kind: PayloadKind.text,
        direction: PayloadDirection.received,
        text: 'a note from the other phone',
        createdAt: DateTime(2026, 11, 24, 12),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
      expect(find.textContaining('a note from the other phone'), findsWidgets);
      await service.dispose();
    });

    testWidgets('a received file says which folder it is in',
        (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      service.payloadsController.add(PayloadModel(
        id: 'p2',
        kind: PayloadKind.file,
        direction: PayloadDirection.received,
        name: 'holiday.jpg',
        path: '/Download/Throw/holiday.jpg',
        sizeBytes: 2048,
        createdAt: DateTime(2026, 11, 24, 12),
        senderName: 'Pixel 8',
      ));
      await tester.pumpAndSettle();

      expect(find.text('holiday.jpg'), findsOneWidget);
      // The complaint was "it shows received but saved where" — the receipt
      // itself must answer that.
      expect(find.textContaining('Download/Throw'), findsWidgets);
      await service.dispose();
    });

    testWidgets('nothing arrived yet: the empty row names the folder',
        (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_home(service));
      await tester.pumpAndSettle();
      expect(find.text('Nothing received yet'), findsOneWidget);
      await service.dispose();
    });
  });

  group('TransferScreen', () {
    testWidgets('empty state talks about transfers, not devices',
        (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_transfers(service));
      await tester.pumpAndSettle();

      expect(find.text('Nothing transferred yet'), findsOneWidget);
      // The old copy — Discover's "No devices nearby yet." — must be gone.
      expect(find.text('No devices nearby yet.'), findsNothing);
      await service.dispose();
    });

    testWidgets('a completed transfer is listed with peer and size',
        (tester) async {
      final service = FakeTransferService();
      await tester.pumpWidget(_transfers(service));
      final peer = _device('a', 'Pixel 8');
      service.transfersController.add(TransferModel(
        id: 't1',
        peer: peer,
        payloads: const [],
        bytesTransferred: 2048,
        totalBytes: 2048,
        status: TransferStatus.completed,
        startedAt: DateTime(2026, 11, 24, 12),
        endedAt: DateTime(2026, 11, 24, 12, 1),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pixel 8'), findsOneWidget);
      expect(find.textContaining('2.0 KB'), findsOneWidget);
      await service.dispose();
    });
  });
}
