import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/atmosphere.dart';
import 'package:throw_app/core/motion.dart';
import 'package:throw_app/core/theme.dart';
import 'package:throw_app/widgets/swipeable_tabs.dart';

/// Swiping between tabs, and the ambient layer's safety properties.
///
/// These are behaviour tests, not pixel tests: a swipe either changes the tab
/// or it does not, and ambient motion either stops when it is told to or it
/// does not. Both were previously untestable because neither existed.
void main() {
  /// Drives a real widget so the gesture goes through the same code path a
  /// finger does, rather than calling the callback directly.
  Widget harness({
    required int index,
    required ValueChanged<int> onChanged,
    bool enabled = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SwipeableTabs(
          index: index,
          enabled: enabled,
          onChanged: onChanged,
          children: const [
            Center(child: Text('HOME')),
            Center(child: Text('DISCOVER')),
            Center(child: Text('TRANSFERS')),
            Center(child: Text('SETTINGS')),
          ],
        ),
      ),
    );
  }

  group('swipe navigation', () {
    testWidgets('a decisive left swipe asks for the next tab', (tester) async {
      int? asked;
      await tester.pumpWidget(harness(index: 0, onChanged: (i) => asked = i));
      await tester.pump();

      // A flick: quick, and covering a good part of the width.
      await tester.fling(find.text('HOME'), const Offset(-320, 0), 900);
      await tester.pumpAndSettle();

      expect(asked, 1, reason: 'swiping left from Home goes to Discover');
    });

    testWidgets('a decisive right swipe asks for the previous tab',
        (tester) async {
      int? asked;
      await tester.pumpWidget(harness(index: 1, onChanged: (i) => asked = i));
      await tester.pump();

      await tester.fling(find.text('DISCOVER'), const Offset(320, 0), 900);
      await tester.pumpAndSettle();

      expect(asked, 0);
    });

    testWidgets('a small drag springs back and changes nothing', (tester) async {
      int? asked;
      await tester.pumpWidget(harness(index: 1, onChanged: (i) => asked = i));
      await tester.pump();

      // Deliberately under the commit threshold, and slow.
      await tester.drag(find.text('DISCOVER'), const Offset(-40, 0));
      await tester.pumpAndSettle();

      expect(asked, isNull,
          reason: 'a nudge must not navigate; that is how mis-taps happen');
      expect(find.text('DISCOVER'), findsOneWidget);
    });

    testWidgets('the first tab cannot be swiped further right', (tester) async {
      int? asked;
      await tester.pumpWidget(harness(index: 0, onChanged: (i) => asked = i));
      await tester.pump();

      await tester.fling(find.text('HOME'), const Offset(400, 0), 900);
      await tester.pumpAndSettle();

      expect(asked, isNull, reason: 'there is nothing before Home');
    });

    testWidgets('the last tab cannot be swiped further left', (tester) async {
      int? asked;
      await tester.pumpWidget(harness(index: 3, onChanged: (i) => asked = i));
      await tester.pump();

      await tester.fling(find.text('SETTINGS'), const Offset(-400, 0), 900);
      await tester.pumpAndSettle();

      expect(asked, isNull);
    });

    testWidgets('swiping is inert when the shell disables it', (tester) async {
      int? asked;
      await tester.pumpWidget(
        harness(index: 0, onChanged: (i) => asked = i, enabled: false),
      );
      await tester.pump();

      await tester.fling(find.text('HOME'), const Offset(-400, 0), 900);
      await tester.pumpAndSettle();

      expect(asked, isNull,
          reason: 'wide layouts turn swiping off so drags stay scrolls');
    });

    testWidgets('a tap on a tab animates to that tab', (tester) async {
      // The buttons and the gesture must reach the same place: this asserts the
      // animation path exists when the index changes without a drag.
      await tester.pumpWidget(harness(index: 0, onChanged: (_) {}));
      await tester.pump();
      await tester.pumpWidget(harness(index: 2, onChanged: (_) {}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('TRANSFERS'), findsWidgets);
    });

    testWidgets('vertical drags are not swallowed', (tester) async {
      // A horizontal-only recogniser must leave vertical drags to the list
      // inside the tab; otherwise long screens cannot be scrolled.
      int? asked;
      await tester.pumpWidget(harness(index: 0, onChanged: (i) => asked = i));
      await tester.pump();

      await tester.drag(find.text('HOME'), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(asked, isNull);
    });
  });

  group('ambient motion', () {
    tearDown(() => Atmosphere.enabled = true);

    testWidgets('disabled ambient renders the child and schedules no frames',
        (tester) async {
      Atmosphere.enabled = false;
      await tester.pumpWidget(const MaterialApp(
        home: AmbientBackdrop(child: Text('content')),
      ));
      await tester.pump();

      expect(find.text('content'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'a still canvas must cost nothing');
    });

    testWidgets('radar pulse draws nothing when inactive', (tester) async {
      Atmosphere.enabled = true;
      await tester.pumpWidget(const MaterialApp(
        home: RadarPulse(active: false, child: Icon(Icons.radar)),
      ));
      await tester.pump();

      expect(find.byType(Icon), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'no scan means no pulse, and no frames');
    });

    testWidgets('shimmer adds no overlay when inactive', (tester) async {
      Atmosphere.enabled = true;
      await tester.pumpWidget(const MaterialApp(
        home: Shimmer(active: false, child: Text('row')),
      ));
      await tester.pump();

      expect(find.text('row'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('reduce-motion turns every ambient layer off', (tester) async {
      Atmosphere.enabled = true;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: AmbientBackdrop(child: Text('still')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('still'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse,
          reason: 'the OS setting is an override, not a hint');
    });
  });

  group('press feedback', () {
    testWidgets('every Pressable scales down on touch', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Pressable(child: FilledButton(onPressed: () {}, child: const Text('go'))),
            ),
          ),
        ),
      );
      await tester.pump();

      final before = tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(before, 1.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('go')),
      );
      await tester.pump(const Duration(milliseconds: 60));
      final during = tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(during, lessThan(1.0), reason: 'the press must be visible');

      await gesture.up();
      await tester.pumpAndSettle();
      final after = tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(after, 1.0);
    });
  });

  group('reported defects', () {
    testWidgets('the radar halo does not widen the row it sits in',
        (tester) async {
      // Reported: "when discovering the location of text gone side ways with
      // the animation making the text invisible". The halo was a 220dp
      // CustomPaint inside the row's 22dp leading slot, so it pushed the title
      // out of view. Whatever the halo paints, its layout footprint must stay
      // the size of the icon.
      Atmosphere.enabled = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThrowTheme.dark(),
          home: Scaffold(
            body: Row(
              children: [
                RadarPulse(active: true, child: const Icon(Icons.radar)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Looking for devices')),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      final haloSize = tester.getSize(find.byType(RadarPulse));
      expect(haloSize.width, lessThanOrEqualTo(24),
          reason: 'the halo must not reserve more width than the icon');

      // The title is present and fully on screen, not pushed sideways.
      final titleRect = tester.getRect(find.text('Looking for devices'));
      expect(titleRect.right, lessThanOrEqualTo(800),
          reason: 'the title must not be shoved off the edge');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a swipe never leaves a transparent screen behind',
        (tester) async {
      // Reported: "swipe made app transparent, overlaps when move right or
      // left". Screens paint onto a clear canvas, so unless each one is backed
      // by the canvas colour, two of them stacked are see-through and the
      // window shows through both.
      Atmosphere.enabled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThrowTheme.dark(),
          home: Scaffold(
            body: SwipeableTabs(
              index: 0,
              onChanged: (_) {},
              children: const [
                Center(child: Text('HOME')),
                Center(child: Text('DISCOVER')),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Every screen in the stack is painted over an opaque canvas colour.
      // Scoped to the tabs subtree: Material's own internals include
      // transparent ColoredBoxes that have nothing to do with this.
      final boxes = tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(SwipeableTabs),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(boxes, isNotEmpty,
          reason: 'each tab needs a canvas behind it, not a bare Stack');
      for (final box in boxes) {
        expect(box.color.a, 1.0,
            reason: 'a translucent backing is the bug being fixed');
      }
    });

    testWidgets('dragging shows the next screen before the finger lifts',
        (tester) async {
      // The preview branch: during a live drag the owner has not changed
      // `index` yet, so the incoming screen has to be inferred from the gesture.
      // Without that, nothing moved while a finger was down.
      Atmosphere.enabled = false;
      int? committed;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeableTabs(
              index: 0,
              onChanged: (i) => committed = i,
              children: const [
                Center(child: Text('HOME')),
                Center(child: Text('DISCOVER')),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('DISCOVER'), findsNothing,
          reason: 'at rest only the current tab is built');

      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();

      expect(find.text('DISCOVER'), findsOneWidget,
          reason: 'the incoming tab must be visible mid-drag');
      expect(committed, isNull,
          reason: 'but the move is not committed until release');

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

    testWidgets('after a move settles, a drag previews the adjacent screen',
        (tester) async {
      // Reported as "overlaps when move right or left" / wrong screen on screen.
      // `_from` used to be latched at the last origin forever, so once a move
      // had completed, every later drag showed the *previous* screen sliding in
      // from the wrong side instead of the neighbour of the current one.
      Atmosphere.enabled = false;

      Widget harness(int index) => MaterialApp(
            home: Scaffold(
              body: SwipeableTabs(
                index: index,
                onChanged: (_) {},
                children: const [
                  Center(child: Text('ONE')),
                  Center(child: Text('TWO')),
                  Center(child: Text('THREE')),
                ],
              ),
            ),
          );

      // Move 0 -> 1 the way the app does it, and let it finish.
      await tester.pumpWidget(harness(0));
      await tester.pump();
      await tester.pumpWidget(harness(1));
      await tester.pumpAndSettle();
      expect(find.text('TWO'), findsOneWidget);

      // Now drag left, i.e. toward THREE. The screen that comes in must be
      // THREE, and it must come in from the right — not ONE from anywhere.
      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();

      expect(find.text('THREE'), findsOneWidget,
          reason: 'the adjacent screen, not a stale origin');
      expect(find.text('ONE'), findsNothing,
          reason: 'the screen two moves back must not reappear');

      // Swiping the other way must offer ONE again.
      await gesture.up();
      await tester.pumpAndSettle();
      final back = await tester.startGesture(const Offset(400, 300));
      await back.moveBy(const Offset(90, 0));
      await tester.pump();
      expect(find.text('ONE'), findsOneWidget,
          reason: 'the previous neighbour, travelling the other way');
      await back.up();
      await tester.pumpAndSettle();
    });
}
