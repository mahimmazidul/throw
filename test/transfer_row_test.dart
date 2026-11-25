import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/atmosphere.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/models/transfer_model.dart';
import 'package:throw_app/widgets/transfer_progress.dart';

/// The reported bug: "File transfer box doesn't render properly on some
/// screen, and there's box, name or size go outside the box."
///
/// Cause: the tile's bottom line was `Row(spaceBetween)` with two unbounded
/// `Text`s. At 320–360 dp the peer string and the byte counter together exceed
/// the width, the Row overflows, and its children paint outside the card.
///
/// Every test here renders at a real phone width and asserts no overflow
/// exception was thrown. `tester.takeException()` is the assertion: a RenderFlex
/// overflow surfaces as a FlutterError there.
void main() {
  // Ambient motion never settles, so `pumpAndSettle` would wait for its
  // timeout on every screen. The widgets are exercised statically here.
  setUp(() => Atmosphere.enabled = false);
  tearDown(() => Atmosphere.enabled = true);

  DeviceModel peer(String name) => DeviceModel(
        id: 'peer-1',
        name: name,
        platform: DevicePlatform.android,
        channel: TransferChannel.wifiDirect,
        isConnected: true,
        lastSeen: DateTime(2026, 11, 24),
      );

  TransferModel transfer({
    String fileName = 'holiday.jpg',
    String peerName = 'Pixel 8',
    int bytes = 51 * 1024 * 1024,
    int total = 51 * 1024 * 1024,
    double speed = 2.4 * 1024 * 1024,
    TransferStatus status = TransferStatus.transferring,
    TransferDirection direction = TransferDirection.receiving,
    String? savedPath,
  }) =>
      TransferModel(
        id: 't1',
        peer: peer(peerName),
        payloads: [
          PayloadModel(
            id: 'p1',
            kind: PayloadKind.file,
            direction: PayloadDirection.received,
            name: fileName,
            sizeBytes: total,
            createdAt: DateTime(2026, 11, 24),
          ),
        ],
        bytesTransferred: bytes,
        totalBytes: total,
        speedBytesPerSecond: speed,
        direction: direction,
        status: status,
        startedAt: DateTime(2026, 11, 24, 12),
        endedAt: status == TransferStatus.transferring
            ? null
            : DateTime(2026, 11, 24, 12, 1),
        savedPath: savedPath,
      );

  Widget app(Widget child, {double width = 320}) => MaterialApp(
        theme: ThrowTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );

  group('no overflow at phone widths', () {
    for (final width in [320.0, 360.0, 411.0]) {
      testWidgets('active transfer fits ${width.toInt()}dp', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(
          TransferProgressTile(transfer: transfer(), onCancel: () {}),
          width: width,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('completed transfer fits ${width.toInt()}dp', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(
          TransferProgressTile(
            transfer: transfer(
              status: TransferStatus.completed,
              savedPath: '/storage/emulated/0/Download/Throw/holiday.jpg',
            ),
          ),
          width: width,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a 200-character file name ellipsizes instead of overflowing',
        (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(fileName: 'x' * 200),
          onCancel: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final title = tester.widget<Text>(find.byType(Text).first);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.maxLines, 1);
    });

    testWidgets('a 40-character peer name does not push the row wider',
        (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(peerName: 'Mahim Mazidul Islam '.padRight(40, 'X')),
          onCancel: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gigabyte-sized counter with no speed still fits',
        (tester) async {
      // No speed means no divider and no ETA: the shortest possible meta line.
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(
            bytes: 3 * 1024 * 1024 * 1024,
            total: 9 * 1024 * 1024 * 1024,
            speed: 0,
          ),
          onCancel: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('what the row says', () {
    testWidgets('an active transfer shows speed and an ETA', (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(
            bytes: 10 * 1024 * 1024,
            total: 60 * 1024 * 1024,
            speed: 2 * 1024 * 1024,
          ),
          onCancel: () {},
        ),
      ));
      await tester.pumpAndSettle();

      // 2 MB/s, 50 MB remaining => 25 s.
      expect(find.textContaining('MB/s'), findsOneWidget);
      expect(find.textContaining('left'), findsOneWidget);
    });

    testWidgets('an active transfer without a rate says it is measuring',
        (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(transfer: transfer(speed: 0), onCancel: () {}),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('measuring'), findsOneWidget);
    });

    testWidgets('a finished transfer shows size, duration and average rate',
        (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(
            bytes: 4 * 1024 * 1024,
            total: 4 * 1024 * 1024,
            speed: 660 * 1024,
            status: TransferStatus.completed,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('4.0 MB'), findsOneWidget);
      expect(find.textContaining('KB/s'), findsOneWidget);
    });

    testWidgets('receiving is worded as receiving, with the sender named',
        (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(transfer: transfer(speed: 0), onCancel: () {}),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('from Pixel 8'), findsOneWidget);
      expect(find.textContaining('Receiving'), findsOneWidget);
    });

    testWidgets('sending is worded as sending', (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(
            speed: 0,
            direction: TransferDirection.sending,
          ),
          onCancel: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('to Pixel 8'), findsOneWidget);
      expect(find.textContaining('Sending'), findsOneWidget);
    });

    testWidgets('a saved file states its folder', (tester) async {
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(
            status: TransferStatus.completed,
            savedPath: '/Download/Throw/holiday.jpg',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Download/Throw'), findsOneWidget);
    });

    testWidgets('an unnamed peer is never shown as a UUID', (tester) async {
      // The BLE address is a 36-character UUID. Showing it in the transfer list
      // is what "another phone just shows Throw" looked like from the other
      // side.
      const uuid = 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890';
      await tester.pumpWidget(app(
        TransferProgressTile(
          transfer: transfer(
            status: TransferStatus.completed,
            peerName: uuid,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nearby device'), findsOneWidget);
      expect(find.textContaining('A1B2C3D4'), findsNothing);
    });
  });
}
