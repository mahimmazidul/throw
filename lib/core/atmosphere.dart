import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

/// Atmosphere primitives — the slow, ambient layer that makes the canvas feel
/// alive rather than painted.
///
/// These are translated from the app's own web page (`docs/index.html`), which
/// uses `drift`, `radar`, `shimmer` and `rise-in` keyframes. The app had none
/// of them: it moved only when the user touched something, so a screen at rest
/// was a still image. That is the difference between "the UI works" and the
/// thing that was reported missing.
///
/// ## Rules these obey
///
///  * **Transform and opacity only.** Nothing here animates a layout property,
///    so the cost is a compositor layer, not a relayout every frame. A drifting
///    background must not cost the transfer list its frame budget.
///  * **Reduced motion is a hard stop,** not a slower version. Every widget
///    checks [Motion.reduceMotion] and renders its static end state.
///  * **Nothing competes with content.** Ambient motion sits at low contrast
///    behind text; the moment something needs attention (a transfer, an error)
///    the ambient layer is what gives way.
///  * **A single controller per screen, not per widget.** [AmbientBackdrop]
///    owns one ticker and paints all of its blobs from it, so adding a second
///    blob costs no extra frames.

/// Global switch for ambient motion.
///
/// Ambient animation is *permanent* by design — it never settles — which is
/// exactly what `pumpAndSettle` waits for, so every widget test that pumps a
/// screen would hang for its full timeout. Tests set this to `false` in
/// `setUp` and get a deterministic, static canvas; production never touches
/// it.
///
/// This is deliberately not a "is this a test" check. It is the same knob as
/// the OS reduce-motion setting, exposed statically because a test driving 200
/// screens should not have to thread an `AccessibilityFeatures` override
/// through every pump.
abstract final class Atmosphere {
  /// When false, [AmbientBackdrop], [RadarPulse] and [Shimmer] render their
  /// static end state and start no tickers.
  static bool enabled = true;
}

/// A very slow, very low-contrast drift behind a screen.
///
/// Two soft radial fields in the accent family move on different periods, so
/// they never settle into a visible loop. The amplitude is a few percent of the
/// size and the colours stay within the palette's own moss/deep-water ramp —
/// this is the one place the app allows a soft gradient, and it is deliberately
/// far too faint to read as "a gradient".
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({
    super.key,
    required this.child,
    this.intensity = 1.0,
    this.blobs = 2,
  });

  final Widget child;

  /// Multiplier on opacity. Screens that need to shout (an error, a blocker)
  /// pass `0` and get a flat canvas.
  final double intensity;

  final int blobs;

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // A drift cycle is long on purpose: at this speed the eye reads movement
    // as depth, not as an animation playing.
    duration: const Duration(seconds: 44),
  );

  // No `initState` override on purpose: whether the drift may run depends on
  // MediaQuery (reduce-motion) and on the inherited atmosphere settings, and
  // neither is readable until dependencies resolve. `didChangeDependencies`
  // runs immediately after `initState` and again on every inherited change, so
  // it is the only hook needed — and using `initState` here crashed the build
  // with "dependOnInheritedWidgetOfExactType was called before initState
  // completed".
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  /// Starts or stops the drift to match the current gates.
  void _sync() {
    final shouldRun = Atmosphere.enabled &&
        widget.intensity > 0 &&
        !Motion.reduceMotion(context);
    if (shouldRun) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Atmosphere.enabled ||
        Motion.reduceMotion(context) ||
        widget.intensity <= 0) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _DriftPainter(
                t: _controller.value,
                intensity: widget.intensity,
                blobs: widget.blobs,
                dark: Theme.of(context).brightness == Brightness.dark,
                // The bright teal, not the dark moss fill. A glow needs a
                // colour lighter than the canvas it sits on; `accent` (#0E6A64)
                // against #0A1214 is almost the same value, which is why the
                // first renders showed nothing at all.
                accent: ThrowColors.accentText,
                accentAlt: ThrowColors.accentText,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _DriftPainter extends CustomPainter {
  _DriftPainter({
    required this.t,
    required this.intensity,
    required this.blobs,
    required this.dark,
    required this.accent,
    required this.accentAlt,
  });

  final double t;
  final double intensity;
  final int blobs;
  final bool dark;
  final Color accent;
  final Color accentAlt;

  @override
  void paint(Canvas canvas, Size size) {
    // Each blob gets its own period and phase so the composition keeps
    // rearranging instead of pulsing in unison.
    const periods = [1.0, 1.6, 2.3];
    const phases = [0.0, 0.4, 0.75];
    final radius = size.shortestSide * 0.62;

    for (var i = 0; i < blobs && i < periods.length; i++) {
      final phase = (t * periods[i] + phases[i]) % 1.0;
      final angle = phase * 2 * math.pi;
      // A Lissajous-ish path reads as organic drift; a circle would read as an
      // orbiting object.
      final dx = math.cos(angle) * size.width * 0.18;
      final dy = math.sin(angle * 0.75) * size.height * 0.14;
      final centre = Offset(
        size.width * (i.isEven ? 0.28 : 0.74) + dx,
        size.height * (i.isEven ? 0.22 : 0.78) + dy,
      );
      // Breathe between 0.9 and 1.1 of the base radius.
      final r = radius * (0.9 + 0.1 * math.sin(angle * 0.6));

      // Tuned against real renders rather than guessed: below ~0.07 on the
      // dark canvas the drift is invisible in a screenshot and reads as a flat
      // black field, which was the original complaint. Above ~0.12 it starts to
      // look like a gradient wash instead of depth. This sits between.
      final baseAlpha = (dark ? 0.13 : 0.10) * intensity;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            (i.isEven ? accent : accentAlt).withValues(alpha: baseAlpha),
            (i.isEven ? accent : accentAlt).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: r));

      canvas.drawCircle(centre, r, paint);
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) =>
      old.t != t ||
      old.intensity != intensity ||
      old.blobs != blobs ||
      old.dark != dark;
}

/// A radar sweep for the Discover screen: rings that expand and fade while a
/// scan is running.
///
/// Discovery is the one state in the app with nothing to look at — an empty
/// list and a "looking…" label. A pulse communicates "still searching" without
/// adding text, and it stops the moment a device is found or the scan ends.
class RadarPulse extends StatefulWidget {
  const RadarPulse({
    super.key,
    required this.active,
    required this.child,
    this.ringCount = 3,
  });

  final bool active;
  final Widget child;
  final int ringCount;

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not `initState`: `Motion.reduceMotion` reads MediaQuery, which is not
    // legal to touch before dependencies are established.
    _sync();
  }

  @override
  void didUpdateWidget(RadarPulse old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (widget.active && Atmosphere.enabled && !Motion.reduceMotion(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active ||
        !Atmosphere.enabled ||
        Motion.reduceMotion(context)) {
      return widget.child;
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: const Size.square(220),
              painter: _RadarPainter(
                t: _controller.value,
                rings: widget.ringCount,
                color: ThrowTheme.accentFg(context),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.t,
    required this.rings,
    required this.color,
  });

  final double t;
  final int rings;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    for (var i = 0; i < rings; i++) {
      // Staggered births so there are always rings on screen at different
      // ages, rather than one ring blinking.
      final phase = (t + i / rings) % 1.0;
      final opacity = (1.0 - phase) * 0.30;
      if (opacity <= 0) continue;
      canvas.drawCircle(
        centre,
        maxRadius * (0.25 + 0.75 * Curves.easeOut.transform(phase)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}

/// A light band that sweeps across a child while work is in progress.
///
/// Used on the active transfer row and on the primary button while a send is in
/// flight. It is the app's "something is happening" signal that does not need
/// text and does not need a spinner next to a percentage that already says so.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.active = true,
    this.period = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final bool active;
  final Duration period;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Not `initState`: `Motion.reduceMotion` reads MediaQuery, which is not
    // legal to touch before dependencies are established.
    _sync();
  }

  @override
  void didUpdateWidget(Shimmer old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active || old.period != widget.period) {
      _controller.duration = widget.period;
      _sync();
    }
  }

  void _sync() {
    if (widget.active && Atmosphere.enabled && !Motion.reduceMotion(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A clipped `ShaderMask` would repaint the child every frame. Instead the
    // band is a separate thin overlay painted above the child, so the child's
    // own repaints are untouched.
    return Stack(
      children: [
        widget.child,
        if (widget.active &&
            Atmosphere.enabled &&
            !Motion.reduceMotion(context))
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _SweepPainter(
                      t: _controller.value,
                      color: ThrowTheme.accentFg(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bandWidth = size.width * 0.28;
    // Travels from fully off the left edge to fully off the right, so the band
    // never pops into existence mid-child.
    final x = -bandWidth + (size.width + bandWidth * 2) * Curves.easeInOut.transform(t);
    final rect = Rect.fromLTWH(x, 0, bandWidth, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.10),
          color.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t || old.color != color;
}
