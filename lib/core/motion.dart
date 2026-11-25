import 'package:flutter/material.dart';

/// Motion tokens for Throw.
///
/// One scale, one easing family, used everywhere. The previous revision had no
/// motion at all: buttons changed colour on press and nothing else, lists
/// appeared fully formed, and progress bars teleported to their new value. The
/// reference apps all move: LocalSend staggers its tabs in with
/// `AnimatedOpacity`/`AnimatedSlide` (200–300 ms), Musify animates selection
/// with `AnimatedContainer`.
///
/// Every duration here is a token so the whole app can be slowed or stilled in
/// one place — and [Motion.respectReduceMotion] makes the OS "remove
/// animations" setting a hard override.
abstract final class Motion {
  /// Press-down scale for anything tappable.
  ///
  /// 0.955 rather than 0.97: at 0.97 the press was so shallow it read as a
  /// colour flicker on a large row. iOS buttons dip further and come back with
  /// a little overshoot, which is what makes them feel physical rather than
  /// merely responsive. The scale is paired with [pressCurve] and the spring
  /// below so the release carries that slight bounce.
  static const double pressScale = 0.955;

  /// Quick, for state the user caused (press, selection).
  static const Duration fast = Duration(milliseconds: 120);

  /// The default for layout and colour changes.
  static const Duration standard = Duration(milliseconds: 220);

  /// Slower, for entrances.
  static const Duration slow = Duration(milliseconds: 320);

  /// Gap between staggered children on entrance.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve curve = Curves.easeOutCubic;

  /// Down-press easing. Fast out of the gate — the finger should feel the
  /// button yield immediately — then settle softly into the compressed scale.
  static const Curve pressCurve = Curves.easeOutQuart;

  /// Release easing. Slight overshoot past 1.0, like a spring: this is the
  /// detail that makes an iOS button feel alive rather than merely animated.
  /// Applied only on the way back up, never on the press.
  static const Curve releaseCurve = Curves.easeOutBack;

  /// Duration of the press-down. Shorter than [fast] on purpose: any longer and
  /// the control feels laggy under the finger.
  static const Duration pressIn = Duration(milliseconds: 90);

  /// Release is slower than the press so the spring has room to overshoot.
  static const Duration pressOut = Duration(milliseconds: 260);

  /// Travel curve for a tab change.
  ///
  /// The incoming tab's position eases out faster than its opacity so it
  /// settles almost immediately and the rest of the move is pure dissolve:
  /// the eye reads a fade with a hint of direction rather than a slide.
  static const Curve dissolve = Curves.easeOutQuint;

  /// Duration of a tab change. The transition is short and mostly fades, so it
  /// can be quicker than [standard] without feeling abrupt.
  static const Duration tabChange = Duration(milliseconds: 260);

  /// True when the platform asks for reduced motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// A duration that collapses to zero when reduced motion is on.
  static Duration adapt(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;
}

/// Gives any child a press-down scale, without stealing its gestures.
///
/// Buttons keep their own splash and tap handling — this uses a [Listener],
/// which observes pointer events in the capture phase and never competes in
/// the gesture arena, so wrapping a `FilledButton` changes nothing about how it
/// behaves.
///
/// Applied to every actionable control in the app: Material buttons, peer
/// pills, list rows, icon actions and chips.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = Motion.pressScale,
  });

  final Widget child;

  /// Disabled controls should not react to touch at all.
  final bool enabled;

  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (!widget.enabled || _down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = Motion.reduceMotion(context);
    // The press and the release are different gestures and want different
    // physics. Pressing down is quick and lands softly; letting go springs back
    // with a touch of overshoot. A single AnimatedScale cannot express that —
    // one duration and one curve had to serve both directions, which is why the
    // old feedback read as a colour flicker rather than a button being pushed.
    return Listener(
      // `translucent` puts this Listener on the hit-test path even when the
      // child does not paint an opaque box, while still letting children win
      // their own taps. Without it, wrapping a bare layout widget meant the
      // press animation never fired.
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: reduce
            ? Duration.zero
            : (_down ? Motion.pressIn : Motion.pressOut),
        curve: _down ? Motion.pressCurve : Motion.releaseCurve,
        child: widget.child,
      ),
    );
  }
}

/// A press toggles state here, not a button: a pill that can gain and lose
/// selection animates both the press and the resulting selection.
class AnimatedPressable extends StatelessWidget {
  const AnimatedPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      enabled: enabled && onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: child,
      ),
    );
  }
}
