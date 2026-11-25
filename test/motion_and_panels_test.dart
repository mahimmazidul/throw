import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/atmosphere.dart';

import 'package:throw_app/core/motion.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/widgets/entrance.dart';
import 'package:throw_app/widgets/panel.dart';

Widget _app(Widget child, {bool disableAnimations = false}) => MaterialApp(
      theme: ThrowTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(disableAnimations: disableAnimations),
        child: c!,
      ),
      home: Scaffold(body: child),
    );

DeviceModel _device(String id, String name) => DeviceModel(
      id: id,
      name: name,
      platform: DevicePlatform.android,
      channel: TransferChannel.wifiDirect,
      isConnected: true,
      lastSeen: DateTime(2026, 11, 24),
    );

void main() {
  // Ambient motion never settles, so `pumpAndSettle` would wait for its
  // timeout on every screen. The widgets are exercised statically here.
  setUp(() => Atmosphere.enabled = false);
  tearDown(() => Atmosphere.enabled = true);

  group('Pressable', () {
    testWidgets('scales down while the pointer is held, back up on release',
        (tester) async {
      await tester.pumpWidget(_app(
        const Pressable(child: SizedBox(width: 100, height: 50)),
      ));

      AnimatedScale scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale));

      expect(scale().scale, 1.0);

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump();
      expect(scale().scale, Motion.pressScale);

      await gesture.up();
      await tester.pump();
      expect(scale().scale, 1.0);
    });

    testWidgets('a disabled Pressable ignores the pointer', (tester) async {
      await tester.pumpWidget(_app(
        const Pressable(
          enabled: false,
          child: SizedBox(width: 100, height: 50),
        ),
      ));
      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump();
      expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
      await gesture.up();
    });

    testWidgets('never swallows the child button tap', (tester) async {
      // The whole point of using a Listener rather than a GestureDetector:
      // wrapping a real button must change nothing about its behaviour.
      var taps = 0;
      await tester.pumpWidget(_app(
        Pressable(
          child: FilledButton(onPressed: () => taps++, child: const Text('Go')),
        ),
      ));
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('reduce-motion collapses the animation duration to zero',
        (tester) async {
      await tester.pumpWidget(_app(
        const Pressable(child: SizedBox(width: 100, height: 50)),
        disableAnimations: true,
      ));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).duration,
        Duration.zero,
      );
    });
  });

  group('Entrance', () {
    testWidgets('settles at full opacity and zero offset', (tester) async {
      await tester.pumpWidget(_app(
        const Entrance(child: SizedBox(width: 40, height: 40)),
      ));
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(Entrance),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('starts transparent so there is something to animate',
        (tester) async {
      await tester.pumpWidget(_app(
        const Entrance(child: SizedBox(width: 40, height: 40)),
      ));
      // First frame, before the post-frame kick.
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(Entrance),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, lessThan(1.0));
      await tester.pumpAndSettle();
    });

    testWidgets('renders immediately when the OS asks for reduced motion',
        (tester) async {
      await tester.pumpWidget(_app(
        const Entrance(child: Text('content')),
        disableAnimations: true,
      ));
      await tester.pump();
      expect(find.text('content'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StaggeredEntrance renders every child', (tester) async {
      await tester.pumpWidget(_app(
        const StaggeredEntrance(
          children: [Text('one'), Text('two'), Text('three')],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
      expect(find.text('three'), findsOneWidget);
    });
  });

  group('Section / FlatRow', () {
    testWidgets('draws separators between rows but not after the last one',
        (tester) async {
      await tester.pumpWidget(_app(
        const Section(
          children: [
            FlatRow(title: 'One'),
            FlatRow(title: 'Two'),
            FlatRow(title: 'Three'),
          ],
        ),
      ));
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('header is uppercased and footer rendered', (tester) async {
      await tester.pumpWidget(_app(
        const Section(
          header: 'This device',
          footer: 'Explained below.',
          children: [FlatRow(title: 'Only')],
        ),
      ));
      expect(find.text('THIS DEVICE'), findsOneWidget);
      expect(find.text('Explained below.'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('a row is tappable and reports the tap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(
        Section(
          children: [FlatRow(title: 'Rename', onTap: () => taps++)],
        ),
      ));
      await tester.tap(find.text('Rename'));
      expect(taps, 1);
    });

    testWidgets('rows without onTap are not tappable and have no ink well',
        (tester) async {
      await tester.pumpWidget(_app(
        const Section(children: [FlatRow(title: 'Static')]),
      ));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('rows meet the 60dp minimum height', (tester) async {
      await tester.pumpWidget(_app(
        const Section(children: [FlatRow(title: 'Row')]),
      ));
      expect(tester.getSize(find.byType(FlatRow)).height,
          greaterThanOrEqualTo(60));
    });

    testWidgets('long titles do not overflow', (tester) async {
      await tester.pumpWidget(_app(
        Section(
          children: [
            FlatRow(title: 'T' * 200, subtitle: 'S' * 400),
          ],
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a section draws no surface of its own', (tester) async {
      // The 1.1 build wrapped every group in a filled 28dp rectangle, which is
      // the "still boxes" complaint. A section must not introduce any Material
      // with the panel tone; the rows sit on the canvas.
      await tester.pumpWidget(_app(
        const Section(children: [FlatRow(title: 'One')]),
      ));
      final panelToned = find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            (widget.color == ThrowColors.containerLow ||
                widget.color == ThrowColors.containerHigh ||
                widget.color == ThrowColors.raised),
      );
      expect(panelToned, findsNothing);
    });

    testWidgets('the section header sits above the rows, not inside a box',
        (tester) async {
      await tester.pumpWidget(_app(
        const Section(header: 'Peers', children: [FlatRow(title: 'One')]),
      ));
      final headerY = tester.getTopLeft(find.text('PEERS')).dy;
      final rowY = tester.getTopLeft(find.text('One')).dy;
      expect(headerY, lessThan(rowY));
    });
  });

  group('peer selection and peer naming', () {
    DeviceModel peer(String id, String name) => DeviceModel(
          id: id,
          name: name,
          platform: DevicePlatform.android,
          channel: TransferChannel.wifiDirect,
          isConnected: true,
          lastSeen: DateTime(2026, 11, 24),
        );

    test('a real name is shown as-is', () {
      expect(peer('a', 'Pixel 8').displayName, 'Pixel 8');
      expect(peer('a', 'Pixel 8').hasRealName, isTrue);
    });

    test('a UUID is never shown to the user', () {
      const uuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';
      final device = peer(uuid, uuid);
      expect(device.hasRealName, isFalse);
      expect(device.displayName, isNot(contains('a1b2c3d4-e5f6')));
      expect(device.displayName, 'Nearby device · 7890');
    });

    test('an empty name falls back to the address token', () {
      // The token is the tail of the address, so two unnamed devices in
      // one list are still distinguishable.
      expect(peer('0000FE2C-1111', '').displayName, 'Nearby device · 1111');
      expect(peer('0000FE2C-1111', '').displayName,
          isNot(peer('0000FE2C-2222', '').displayName));
    });

    test('a learned name survives a later nameless update', () {
      final named = peer('a', 'Mahim phone');
      final blanked = named.withLearnedName('');
      expect(blanked.name, 'Mahim phone');
      expect(named.withLearnedName(null).name, 'Mahim phone');
    });

    testWidgets('every connected peer is listed and selectable',
        (tester) async {
      final taps = <String>[];
      await tester.pumpWidget(_app(
        Material(
          child: Section(
            header: 'Peers',
            children: [
              for (final device in [peer('a', 'Pixel 8'), peer('b', 'ThinkPad')])
                FlatRow(
                  title: device.displayName,
                  onTap: () => taps.add(device.id),
                ),
            ],
          ),
        ),
      ));
      expect(find.text('Pixel 8'), findsOneWidget);
      expect(find.text('ThinkPad'), findsOneWidget);
      await tester.tap(find.text('Pixel 8'));
      await tester.tap(find.text('ThinkPad'));
      expect(taps, ['a', 'b']);
    });

    testWidgets('a peer row with a very long name does not overflow',
        (tester) async {
      await tester.pumpWidget(_app(
        Material(
          child: Section(
            children: [FlatRow(title: 'Peers', subtitle: 'X' * 300)],
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
