import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';

/// Horizontal navigation between the app's tabs, driven by both the buttons and
/// a swipe.
///
/// The shell keeps every tab alive in an [IndexedStack] so a scan in progress
/// or a scrolled list is not rebuilt when the user comes back. Swiping that
/// stack directly is not possible — an IndexedStack has one child on screen and
/// nothing to drag against — so this widget keeps the same "stay alive"
/// guarantee while adding the horizontal gesture.
///
/// ## Why the incoming screen slides *over* the outgoing one
///
/// The obvious implementation is a [PageView], which slides all tabs in
/// lockstep: dragging toward Settings also drags Transfers and Home, even
/// though you are never going there. With four tabs that reads as a loose
/// carousel rather than a deliberate move. Here the screen you are leaving
/// stays put and the one you are going to slides across it, which is what the
/// platform pickers and LocalSend do, and it keeps the gesture feeling like
/// "this screen is coming in" instead of "the whole strip is shifting".
///
/// The direction is inferred from the index delta, so a tap on a tab to the
/// left animates leftwards, exactly as a swipe would.
class SwipeableTabs extends StatefulWidget {
  const SwipeableTabs({
    super.key,
    required this.index,
    required this.children,
    required this.onChanged,
    this.enabled = true,
  });

  final int index;
  final List<Widget> children;

  /// Called once the move is committed. The owner updates [index].
  final ValueChanged<int> onChanged;

  /// Swiping is off when there is nothing to swipe to, and on wide layouts
  /// where a horizontal drag is more likely to be a scroll than a navigation.
  final bool enabled;

  @override
  State<SwipeableTabs> createState() => _SwipeableTabsState();
}

class _SwipeableTabsState extends State<SwipeableTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.standard,
  );

  /// The index being animated *away from*.
  late int _from = widget.index;

  /// Which way the incoming screen travels: 1 when moving to a higher index
  /// (it comes from the right), -1 when moving to a lower one.
  int _direction = 1;

  /// Measured by a [LayoutBuilder]. `context.size` is not usable here: the
  /// GestureDetector's own render object is only laid out after the gesture
  /// callbacks are created, and reading it mid-drag returned a stale width that
  /// made every flick fall below the commit threshold.
  double _width = 1;

  /// Signed progress of the current drag, -1..1.
  ///
  /// Positive means moving toward the next tab, negative toward the previous
  /// one. The animation controller only carries magnitude, because the arrow
  /// of travel can flip mid-gesture — a signed field is what lets a rightward
  /// drag mean "back" without the controller clamping it to zero and losing
  /// the direction entirely.
  double _drag = 0;

  @override
  void didUpdateWidget(SwipeableTabs old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (Motion.reduceMotion(context)) {
      // No slide at all; the new tab is simply shown.
      _from = widget.index;
      _controller.value = 1;
      return;
    }
    _from = old.index;
    _direction = widget.index > old.index ? 1 : -1;
    _controller
      ..duration = Motion.standard
      ..forward(from: 0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled || widget.children.length < 2) return;
    final velocity = details.primaryVelocity ?? 0;
    final width = _width;

    // Project where the gesture would have ended if it kept going for another
    // ~120 ms at the release velocity — the standard "flick counts as a drag"
    // rule. A leftward flick has negative velocity and adds progress toward the
    // next tab, so it is subtracted.
    final projected = _drag - velocity * 0.12 / width;

    var target = widget.index;
    if (projected > 0.28) {
      target = widget.index + 1;
    } else if (projected < -0.28) {
      target = widget.index - 1;
    }
    target = target.clamp(0, widget.children.length - 1);

    _drag = 0;

    if (target == widget.index) {
      // Not far enough: spring back rather than leaving a half-shifted screen.
      _controller.animateBack(
        0,
        duration: Motion.fast,
        curve: Motion.curve,
      );
      return;
    }

    // Hand off to the owner, which rebuilds with the new index; the movement so
    // far is reused so the gesture feels continuous rather than restarting.
    widget.onChanged(target);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = Motion.reduceMotion(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return GestureDetector(
      // `horizontal` only: a vertical drag belongs to the list inside the tab,
      // and claiming it here would make long lists impossible to scroll.
      onHorizontalDragUpdate: reduce || !widget.enabled
          ? null
          : (details) {
              final width = _width;
              final delta = details.primaryDelta ?? 0;
              // Dragging left (negative) advances; reverse for the last tab.
              // Dragging left (negative delta) moves toward the next tab. At
              // the first tab a rightward drag and at the last tab a leftward
              // one have nowhere to go, so they do not start a shift at all —
              // otherwise the edge would show a blank sliver.
              final atStart = widget.index == 0 && delta > 0;
              final atEnd =
                  widget.index == widget.children.length - 1 && delta < 0;
              if (atStart || atEnd) {
                _drag = 0;
                _controller.value = 0;
                return;
              }
              _drag = (_drag - delta / width).clamp(-1.0, 1.0);
              _controller.value = _drag.abs();
            },
      onHorizontalDragEnd: reduce || !widget.enabled ? null : _onDragEnd,
      // The gesture must not swallow taps meant for the content underneath.
      behavior: HitTestBehavior.translucent,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Motion.curve.transform(_controller.value.clamp(0.0, 1.0));
          // During a drag the arrow comes from the gesture itself, which is the
          // only way to know whether the user is heading forward or back.
          final direction = _controller.value > 0 && _drag != 0
              ? (_drag > 0 ? 1 : -1)
              : _direction;
          return Stack(
            fit: StackFit.expand,
            children: [
              // The screen being left stays put and fades out as the new one
              // covers it. The fade is strong on purpose: at 0.15 the two
              // screens' text overlapped legibly mid-transition, which read as
              // a rendering glitch rather than a slide. By the time the incoming
              // screen is halfway across, the outgoing one is a faint ghost.
              _buildScreen(_from, opacity: 1.0 - 0.72 * t),
              if (t > 0 && widget.index != _from)
                FractionalTranslation(
                  translation: Offset(direction * (1 - t), 0),
                  child: DecoratedBox(
                    // A hairline edge and a soft left shadow so the incoming
                    // screen reads as a surface moving over another, not as two
                    // layers cross-fading.
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.28 * (1 - t),
                          ),
                          blurRadius: 24,
                          offset: Offset(-direction * 6.0, 0),
                        ),
                      ],
                    ),
                    child: _buildScreen(widget.index, opacity: 1.0),
                  ),
                ),
            ],
          );
        },
      ),
        );
      },
    );
  }

  Widget _buildScreen(int index, {required double opacity}) {
    return Opacity(
      opacity: opacity,
      child: _KeepAliveStack(index: index, children: widget.children),
    );
  }
}

/// An [IndexedStack] with the same keep-alive behaviour, factored out so the
/// animated stack and the resting stack cannot drift apart.
class _KeepAliveStack extends StatelessWidget {
  const _KeepAliveStack({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(index: index, children: children);
  }
}

/// A single hairline that slides between tabs to mark the selected one, used by
/// the navigation rail. `AnimatedAlign` gives the slide; the rail's own
/// indicator is suppressed so there is only one selection mark on screen.
class SlidingSelector extends StatelessWidget {
  const SlidingSelector({
    super.key,
    required this.index,
    required this.count,
    required this.extent,
  });

  final int index;
  final int count;
  final double extent;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedAlign(
        duration: Motion.adapt(context, Motion.standard),
        curve: Motion.curve,
        alignment: Alignment(0, (index / (count - 1)) * 2 - 1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Container(
            width: 3,
            height: extent,
            decoration: BoxDecoration(
              color: ThrowTheme.accentFg(context),
              borderRadius: ThrowRadius.chip,
            ),
          ),
        ),
      ),
    );
  }
}
