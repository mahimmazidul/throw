import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/atmosphere.dart';
import 'package:throw_app/core/motion.dart';
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
}
