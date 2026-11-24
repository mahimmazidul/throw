import 'package:flutter/material.dart';

import '../core/motion.dart';

/// Fades and lifts a child in once, the first time it is built.
///
/// Ported from LocalSend's `InitialFadeTransition` / `InitialSlideTransition`
/// pair, which it uses to stagger tab content in. Two differences: this is a
/// single widget with a `delay` instead of two to nest, and it collapses to
/// "already visible" when the OS asks for reduced motion — a decorative fade
/// is the first thing that setting should remove.
///
/// Held in one `AnimationController` per widget, driven once; it never
/// rebuilds after settling.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = Motion.slow,
    this.offset = const Offset(0, 0.03),
  });

  final Widget child;

  /// Stagger index * [Motion.stagger] is the usual value.
  final Duration delay;

  final Duration duration;

  /// Fractional starting offset; 3% of the widget's height reads as a lift
  /// without looking like a slide.
  final Offset offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _value = CurvedAnimation(
    parent: _controller,
    curve: Motion.curve,
  );
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // The first frame must paint at the start value; kicking the controller
    // from initState directly would skip it on some platforms.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Motion.reduceMotion(context)) {
        _controller.value = 1;
        return;
      }
      _started = true;
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        Future<void>.delayed(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion (including the golden environment, which reports
    // animations disabled) paints the settled state immediately.
    if (!_started && Motion.reduceMotion(context)) return widget.child;

    return AnimatedBuilder(
      animation: _value,
      builder: (context, child) {
        final t = _value.value;
        return Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(
              widget.offset.dx * (1 - t),
              widget.offset.dy * (1 - t),
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Convenience: a column of children, each entering [Motion.stagger] after the
/// previous one. Used for the main bodies of Home, Discover and Settings.
class StaggeredEntrance extends StatelessWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.initialDelay = Duration.zero,
  });

  final List<Widget> children;
  final Duration initialDelay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          Entrance(
            delay: initialDelay + Motion.stagger * i,
            child: children[i],
          ),
      ],
    );
  }
}
