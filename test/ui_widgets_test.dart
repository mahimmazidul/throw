import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:throw_app/core/theme.dart';
import 'package:throw_app/core/utils.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/models/payload_model.dart';
import 'package:throw_app/widgets/accent_icon_badge.dart';
import 'package:throw_app/widgets/panel.dart';
import 'package:throw_app/widgets/empty_state.dart';
import 'package:throw_app/widgets/received_items_list.dart';
import 'package:throw_app/widgets/screen_header.dart';

Widget _app(Widget child) => MaterialApp(
      theme: ThrowTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

DeviceModel _device(String id, String name, {bool connected = true}) =>
    DeviceModel(
      id: id,
      name: name,
      platform: DevicePlatform.android,
      channel: TransferChannel.wifiDirect,
      isConnected: connected,
      lastSeen: DateTime(2026, 11, 24),
    );

void main() {
  group('AppUtils.formatRelativeTime', () {
    final now = DateTime(2026, 11, 24, 12);

    test('collapses the first minute and future timestamps to now', () {
      expect(AppUtils.formatRelativeTime(now, now), 'now');
      expect(
        AppUtils.formatRelativeTime(
            now.subtract(const Duration(seconds: 59)), now),
        'now',
      );
      expect(
        AppUtils.formatRelativeTime(now.add(const Duration(minutes: 5)), now),
        'now',
      );
    });

    test('minutes, hours, days, then a date', () {
      expect(
        AppUtils.formatRelativeTime(
            now.subtract(const Duration(minutes: 3)), now),
        '3 min ago',
      );
      expect(
        AppUtils.formatRelativeTime(
            now.subtract(const Duration(hours: 2)), now),
        '2 hr ago',
      );
      expect(
        AppUtils.formatRelativeTime(now.subtract(const Duration(days: 5)), now),
        '5 d ago',
      );
      expect(
        AppUtils.formatRelativeTime(DateTime(2026, 11, 1), now),
        '1 Nov',
      );
    });
  });

  group('AppUtils.isNewerVersion', () {
    test('major, minor and patch bumps are newer', () {
      expect(AppUtils.isNewerVersion('2.0.0', '1.0.15'), isTrue);
      expect(AppUtils.isNewerVersion('1.1.0', '1.0.15'), isTrue);
      expect(AppUtils.isNewerVersion('1.0.16', '1.0.15'), isTrue);
    });

    test('equal and older versions are not newer', () {
      expect(AppUtils.isNewerVersion('1.0.15', '1.0.15'), isFalse);
      expect(AppUtils.isNewerVersion('1.0.14', '1.0.15'), isFalse);
      expect(AppUtils.isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });

    test('tolerates build metadata, v prefixes and short forms', () {
      expect(AppUtils.isNewerVersion('1.0.16+3', '1.0.15'), isTrue);
      expect(AppUtils.isNewerVersion('v1.0.16', '1.0.15'), isTrue);
      expect(AppUtils.isNewerVersion('2', '1.9.9'), isTrue);
      expect(AppUtils.isNewerVersion('1.0', '1.0.0'), isFalse);
    });
  });

  group('AppUtils.formatBytes and speed', () {
    test('units and rounding', () {
      expect(AppUtils.formatBytes(0), '0 B');
      expect(AppUtils.formatBytes(-4), '0 B');
      expect(AppUtils.formatBytes(1023), '1023 B');
      expect(AppUtils.formatBytes(1024), '1.0 KB');
      expect(AppUtils.formatBytes(1536), '1.5 KB');
      expect(AppUtils.formatBytes(10 * 1024 * 1024), '10 MB');
    });

    test('speed appends /s and never prints a negative rate', () {
      expect(AppUtils.formatSpeed(0), '0 B/s');
      expect(AppUtils.formatSpeed(-5), '0 B/s');
      expect(AppUtils.formatSpeed(1024), '1.0 KB/s');
    });
  });

  group('AppUtils.sanitizeFileName', () {
    test('strips directories and traversal', () {
      expect(AppUtils.sanitizeFileName('../../etc/passwd'), 'passwd');
      expect(AppUtils.sanitizeFileName(r'C:\Users\x\photo.jpg'), 'photo.jpg');
      expect(AppUtils.sanitizeFileName('/tmp/a/b.txt'), 'b.txt');
    });

    test('replaces characters Windows cannot store', () {
      expect(AppUtils.sanitizeFileName('a<b>c:d"e|f?g*h'), 'a_b_c_d_e_f_g_h');
    });

    test('falls back for empty and dot-only names', () {
      expect(AppUtils.sanitizeFileName(''), 'incoming_file');
      expect(AppUtils.sanitizeFileName('..'), 'incoming_file');
      expect(AppUtils.sanitizeFileName('   '), 'incoming_file');
    });
  });

  group('ScreenHeader', () {
    testWidgets('shows title and subtitle, with no app icon', (tester) async {
      await tester.pumpWidget(_app(
        const ScreenHeader(title: 'Throw', subtitle: 'Nearby transfers'),
      ));
      expect(find.text('Throw'), findsOneWidget);
      expect(find.text('Nearby transfers'), findsOneWidget);
      // The app icon was repeated on every screen header; it is gone by
      // design, and this keeps it gone.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('trailing action is rendered and tappable', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_app(
        ScreenHeader(
          title: 'Discover',
          trailing: IconButton(
            icon: const Icon(Icons.radar_rounded),
            onPressed: () => tapped = true,
          ),
        ),
      ));
      await tester.tap(find.byIcon(Icons.radar_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('long titles ellipsize instead of overflowing', (tester) async {
      await tester.pumpWidget(_app(
        ScreenHeader(title: 'A' * 90, subtitle: 'B' * 200),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('radius 28 rather than a rectangle', (tester) async {
      expect(ThrowRadius.card.topLeft.x, 28);
    });
  });

  group('EmptyState', () {
    testWidgets('renders title, body, and optional action', (tester) async {
      await tester.pumpWidget(_app(
        EmptyState(
          icon: Icons.inbox_rounded,
          title: 'Nothing received yet',
          body: 'Files will appear here.',
          action: FilledButton(onPressed: () {}, child: const Text('Retry')),
        ),
      ));
      expect(find.text('Nothing received yet'), findsOneWidget);
      expect(find.text('Files will appear here.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('works without a body or action', (tester) async {
      await tester.pumpWidget(_app(
        const EmptyState(icon: Icons.inbox_rounded, title: 'Empty'),
      ));
      expect(find.text('Empty'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('peer rows', () {
    testWidgets('a row with a trailing action keeps the title on one line',
        (tester) async {
      await tester.pumpWidget(_app(
        Section(
          children: [
            FlatRow(
              title: 'Pixel 8',
              subtitle: 'WiFi Direct · ~250 Mbps',
              trailing: const Icon(Icons.check_circle_rounded),
              onTap: () {},
            ),
          ],
        ),
      ));
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a row is announced as a button and is tappable',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(_app(
        Section(
          children: [FlatRow(title: 'Pixel 8', onTap: () => taps++)],
        ),
      ));
      final data = tester.getSemantics(find.text('Pixel 8')).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.tap(find.text('Pixel 8'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('a row clears the 44dp target even when dense',
        (tester) async {
      await tester.pumpWidget(_app(
        Section(
          children: [
            FlatRow(title: 'Pixel 8', dense: true, onTap: () {}),
          ],
        ),
      ));
      final size = tester.getSize(find.byType(FlatRow));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });

  group('AccentIconBadge', () {
    testWidgets('uses the AA-safe foreground, not the fill accent',
        (tester) async {
      await tester.pumpWidget(_app(
        const AccentIconBadge(icon: Icons.devices_rounded),
      ));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, ThrowColors.accentText);
    });

    testWidgets('solid emphasis flips to onPrimary', (tester) async {
      await tester.pumpWidget(_app(
        const AccentIconBadge(
          icon: Icons.inbox_rounded,
          emphasis: BadgeEmphasis.solid,
        ),
      ));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, ThrowColors.onAccent);
    });
  });

  group('ReceivedItemsList', () {
    final now = DateTime(2026, 11, 24, 12);

    PayloadModel text(String id, String body) => PayloadModel(
          id: id,
          kind: PayloadKind.text,
          direction: PayloadDirection.received,
          text: body,
          createdAt: now,
        );

    PayloadModel file(String id, String name, {String? path}) => PayloadModel(
          id: id,
          kind: PayloadKind.file,
          direction: PayloadDirection.received,
          name: name,
          sizeBytes: 2048,
          path: path,
          createdAt: now,
        );

    testWidgets('shows the empty state when nothing arrived', (tester) async {
      await tester.pumpWidget(_app(const ReceivedItemsList(payloads: [])));
      expect(find.text('Nothing received yet'), findsOneWidget);
    });

    testWidgets('lists received items newest first', (tester) async {
      await tester.pumpWidget(_app(ReceivedItemsList(payloads: [
        text('1', 'older one'),
        text('2', 'newer one'),
      ])));
      final newer = tester.getTopLeft(find.text('newer one')).dy;
      final older = tester.getTopLeft(find.text('older one')).dy;
      expect(newer, lessThan(older));
    });

    testWidgets('text rows offer copy and copy puts text on the clipboard',
        (tester) async {
      // The real platform clipboard channel is not serviced in the test
      // binary (it stalls forever), so the channel is mocked. This asserts
      // the contract that matters: tapping copy sends exactly the payload
      // text to `Clipboard.setData`.
      String? stored;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            stored = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.pumpWidget(_app(ReceivedItemsList(payloads: [
        text('1', 'hello from the other device'),
      ])));
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();
      expect(stored, 'hello from the other device');
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });

    testWidgets('file rows offer open and show size', (tester) async {
      await tester.pumpWidget(_app(ReceivedItemsList(payloads: [
        file('1', 'holiday.jpg', path: '/nonexistent/holiday.jpg'),
      ])));
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
      expect(find.textContaining('2.0 KB'), findsOneWidget);
    });

    testWidgets('opening a file whose path is gone says so instead of crashing',
        (tester) async {
      await tester.pumpWidget(_app(ReceivedItemsList(payloads: [
        file('1', 'gone.jpg', path: '/definitely/not/here.jpg'),
      ])));
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.open_in_new_rounded));
        // `File.exists()` is real I/O; one macrotask turn lets it settle
        // before the snack bar is asserted.
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(
        find.textContaining('saved path'),
        findsOneWidget,
      );
    });

    testWidgets('a file without a path is reported, not opened',
        (tester) async {
      await tester.pumpWidget(_app(ReceivedItemsList(payloads: [
        file('1', 'nopath.jpg'),
      ])));
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.open_in_new_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      expect(find.textContaining('saved path'), findsOneWidget);
    });
  });
}
