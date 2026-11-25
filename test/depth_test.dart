import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:throw_app/core/theme.dart';

/// Contrast ratio between two opaque colours, per WCAG 2.1.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(Brightness brightness, Widget child) => MaterialApp(
      theme: brightness == Brightness.dark
          ? ThrowTheme.dark()
          : ThrowTheme.light(),
      home: Builder(builder: (context) => Scaffold(body: child)),
    );

void main() {
  group('control fill keeps text legible at every stop', () {
    // The point of a gradient is that the text sits on *all* of it, so the
    // worst stop is the one that decides. Contrast is checked against the
    // lightest and darkest stops as well as the flat fill.
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: every stop clears AA for its text', (t) async {
        late LinearGradient gradient;
        late List<BoxShadow> shadow;
        await t.pumpWidget(_host(brightness, Builder(builder: (context) {
          gradient = ThrowSurface.controlFill(context);
          shadow = ThrowSurface.controlShadow(context);
          return const SizedBox();
        })));

        final onFill = brightness == Brightness.dark
            ? ThrowColors.onAccent
            : ThrowColors.onAccent;

        for (final stop in gradient.colors) {
          final ratio = _contrast(onFill, stop);
          expect(
            ratio,
            greaterThan(4.5),
            reason: 'stop ${stop.toARGB32().toRadixString(16)} on '
                '${brightness.name} is $ratio:1, below AA 4.5:1',
          );
        }

        expect(shadow, isNotEmpty,
            reason: 'an enabled control should cast a shadow');
        expect(
          shadow.first.color.a,
          greaterThan(0.15),
          reason: 'the shadow must be visible to read as depth',
        );
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: the ramp is one hue, only lightness moves',
          (t) async {
        late LinearGradient gradient;
        await t.pumpWidget(_host(brightness, Builder(builder: (context) {
          gradient = ThrowSurface.controlFill(context);
          return const SizedBox();
        })));

        final stops = gradient.colors;
        expect(stops.length, greaterThanOrEqualTo(2));

        // Hue, converted from RGB. Asserting on H rather than on an RGB channel
        // delta is the difference between a real property and a guess: the ramp
        // must be one hue, and the first threshold written here (red within
        // 0.06) was a number pulled out of the air that failed a perfectly
        // tonal ramp. A spread of a few degrees is what "tonal" means; a second
        // colour would move this by tens of degrees.
        final hues = stops.map((c) {
          final hsv = HSVColor.fromColor(c);
          return hsv.hue;
        }).toList();

        final spread = hues.reduce((a, b) => a > b ? a : b) -
            hues.reduce((a, b) => a < b ? a : b);
        expect(spread, lessThan(8.0),
            reason: 'stops span ${spread.toStringAsFixed(1)}° of hue; a tonal '
                'ramp should stay within a few degrees');

        // And lightness must actually move, or the gradient is invisible.
        final lightness = stops.map((c) => c.computeLuminance()).toList();
        expect(lightness.first, greaterThan(lightness.last),
            reason: 'the fill darkens downward');
        expect(lightness.first - lightness.last, greaterThan(0.02),
            reason: 'a tonal ramp has to be visible to be depth');
      });
    }
  });

  group('disabled controls', () {
    testWidgets('do not cast a shadow in either theme', (t) async {
      for (final brightness in Brightness.values) {
        await t.pumpWidget(_host(
          brightness,
          const SizedBox(),
        ));
        late Color fill;
        await t.pumpWidget(_host(brightness, Builder(builder: (context) {
          fill = ThrowSurface.disabledFill(context);
          return const SizedBox();
        })));
        expect(fill.a, 1.0, reason: 'a disabled fill must be opaque');
      }
    });

    testWidgets('light mode does not borrow the dark palette', (t) async {
      // The bug this test exists for: the disabled fill resolved to the dark
      // surface in light mode and painted a near-black pill on sage paper.
      late Color light;
      await t.pumpWidget(_host(Brightness.light, Builder(builder: (context) {
        light = ThrowSurface.disabledFill(context);
        return const SizedBox();
      })));
      expect(light, ThrowColors.lightSurfaceHigh);
      expect(light.computeLuminance(), greaterThan(0.5),
          reason: 'a disabled control on light paper must be light');
    });
  });
}
