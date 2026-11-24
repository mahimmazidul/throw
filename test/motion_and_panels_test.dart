import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:throw_app/core/motion.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/l10n/app_localizations.dart';
import 'package:throw_app/models/device_model.dart';
import 'package:throw_app/widgets/device_picker.dart';
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

  group('PanelGroup / FlatRow', () {
    testWidgets('draws separators between rows but not after the last one',
        (tester) async {
      await tester.pumpWidget(_app(
        const PanelGroup(
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
        const PanelGroup(
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
        PanelGroup(
          children: [FlatRow(title: 'Rename', onTap: () => taps++)],
        ),
      ));
      await tester.tap(find.text('Rename'));
      expect(taps, 1);
    });

    testWidgets('rows without onTap are not tappable and have no ink well',
        (tester) async {
      await tester.pumpWidget(_app(
        const PanelGroup(children: [FlatRow(title: 'Static')]),
      ));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('rows meet the 60dp minimum height', (tester) async {
      await tester.pumpWidget(_app(
        const PanelGroup(children: [FlatRow(title: 'Row')]),
      ));
      expect(tester.getSize(find.byType(FlatRow)).height,
          greaterThanOrEqualTo(60));
    });

    testWidgets('long titles do not overflow', (tester) async {
      await tester.pumpWidget(_app(
        PanelGroup(
          children: [
            FlatRow(title: 'T' * 200, subtitle: 'S' * 400),
          ],
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the group surface is the panel tone, not the canvas',
        (tester) async {
      await tester.pumpWidget(_app(
        const PanelGroup(children: [FlatRow(title: 'One')]),
      ));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(PanelGroup),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, ThrowColors.containerLow);
      expect(material.color, isNot(ThrowColors.bg));
    });
  });

  group('DevicePicker sizing and accessibility', () {
    testWidgets('a lone peer pill is not stretched full width', (tester) async {
      // Regression: `alignment` on the animated container made the pill fill
      // the row, so one device became a full-width button.
      await tester.pumpWidget(_app(
        DevicePicker(
          devices: [_device('a', 'Pixel 8')],
          selected: null,
          onSelected: (_) {},
        ),
      ));
      // Measure against the Wrap the pills live in: the picker itself is
      // stretched to the page width by its parent, so comparing to it says
      // nothing about whether a pill grew.
      final wrapWidth = tester.getSize(find.byType(Wrap)).width;
      final pillWidth = tester.getSize(find.byType(IntrinsicWidth)).width;
      expect(pillWidth, lessThanOrEqualTo(wrapWidth + 0.5),
          reason: 'pill ($pillWidth) should not exceed its wrap ($wrapWidth)');
      expect(pillWidth, lessThan(390 * 0.9),
          reason: 'a lone pill must stay intrinsic, not full-bleed');
    });

    testWidgets('two peers stay side by side, not stacked', (tester) async {
      await tester.pumpWidget(_app(
        DevicePicker(
          devices: [_device('a', 'Pixel 8'), _device('b', 'ThinkPad')],
          selected: null,
          onSelected: (_) {},
        ),
      ));
      final a = tester.getTopLeft(find.text('Pixel 8')).dy;
      final b = tester.getTopLeft(find.text('ThinkPad')).dy;
      expect(a, b, reason: 'peers should share a row when they fit');
    });

    testWidgets('the pill still clears the 48dp touch target', (tester) async {
      await tester.pumpWidget(_app(
        DevicePicker(
          devices: [_device('a', 'Pixel 8')],
          selected: null,
          onSelected: (_) {},
        ),
      ));
      final height = tester
          .getSize(
            find.ancestor(
              of: find.text('Pixel 8'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .height;
      expect(height, greaterThanOrEqualTo(48));
    });

    testWidgets('selection swaps the fill colour', (tester) async {
      await tester.pumpWidget(_app(
        DevicePicker(
          devices: [_device('a', 'Pixel 8')],
          selected: null,
          onSelected: (_) {},
        ),
      ));
      final before = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration as BoxDecoration;
      expect(before.color, ThrowColors.containerHigh);

      await tester.pumpWidget(_app(
        DevicePicker(
          devices: [_device('a', 'Pixel 8')],
          selected: _device('a', 'Pixel 8'),
          onSelected: (_) {},
        ),
      ));
      await tester.pumpAndSettle();
      final after = tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration as BoxDecoration;
      expect(after.color, ThrowColors.accent);
    });
  });
}
