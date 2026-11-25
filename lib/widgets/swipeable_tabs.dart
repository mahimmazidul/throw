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

  /// The screens of the transition currently on screen, or null when idle.
  ///
  /// This used to be a bare `_from` set when a move started, with the incoming
  /// screen assumed to be `widget.index`. The assumption only held for as long
  /// as `_from` was refreshed, and nothing refreshed it when a move finished
  /// (or when a move was abandoned before it began). It stayed latched at an
  /// old index forever, so every later drag previewed whichever screen had last
  /// been left behind — the user saw a third screen slide in from the wrong
  /// side. Naming both ends and clearing them on completion keeps the stage
  /// honest.
  int? _outgoing;
  int? _incoming;

  /// Progress carried over from a drag that has just been committed.
  ///
  /// When a drag crosses the commit threshold the gesture is handed to the
  /// owner, which rebuilds with the new index and starts an animation. Starting
  /// that animation at zero snapped the incoming screen back off the edge and
  /// replayed the whole transition from the beginning — the transition visibly
  /// stuttered at the moment of release. Carrying the gesture's progress across
  /// makes the release continue from where the finger left off.
  double? _handOffFrom;

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

  /// Fraction of a screen of travel that commits a move.
  ///
  /// This was 0.28 when a swipe shoved a whole screen across; the transition is
  /// short now, so 0.18 (a fifth of the width, or a modest flick) is enough.
  static const double _commitAt = 0.18;

  @override
  void didUpdateWidget(SwipeableTabs old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    if (Motion.reduceMotion(context)) {
      // No slide at all; the new tab is simply shown.
      _outgoing = null;
      _incoming = null;
      _handOffFrom = null;
      _controller.value = 1;
      return;
    }
    _outgoing = old.index;
    _incoming = widget.index;
    _direction = widget.index > old.index ? 1 : -1;

    // Resume from the gesture when there is one, otherwise start clean.
    final start = _handOffFrom?.clamp(0.0, 0.92);
    _handOffFrom = null;
    _controller
      ..duration = Motion.tabChange
      ..value = start ?? 0;
    _controller.forward().whenCompleteOrCancel(() {
        if (!mounted) return;
        // The move is done: drop the stage, or the next drag would replay it.
        setState(() {
          _outgoing = null;
          _incoming = null;
        });
      });
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
    if (projected > _commitAt) {
      target = widget.index + 1;
    } else if (projected < -_commitAt) {
      target = widget.index - 1;
    }
    target = target.clamp(0, widget.children.length - 1);

    // Progress already on screen. The transition is short, so it takes less
    // travel than a full-screen slide would to feel committed.
    final carried = _controller.value;

    _drag = 0;

    if (target == widget.index) {
      // Not far enough: ease back rather than leaving a half-shifted screen.
      _controller.animateBack(
        0,
        duration: Motion.fast,
        curve: Motion.curve,
      );
      return;
    }

    // Hand off to the owner, which rebuilds with the new index. The progress
    // the gesture had reached is carried into the animation so it continues
    // from under the finger instead of snapping back and replaying. This was
    // the visible stutter on release: `forward(from: 0)` restarted the move
    // from the far edge.
    _handOffFrom = carried;
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

          // Which screens are on stage.
          //
          // A committed move has both ends named by `didUpdateWidget`. A live
          // drag has neither: the owner is only told on release, so the
          // incoming screen is inferred from the gesture.
          final int outgoing;
          final int? incoming;
          if (_outgoing != null && _incoming != null) {
            outgoing = _outgoing!;
            incoming = _incoming;
          } else if (_drag != 0) {
            outgoing = widget.index;
            incoming = (widget.index + (_drag > 0 ? 1 : -1))
                .clamp(0, widget.children.length - 1);
          } else {
            outgoing = widget.index;
            incoming = null;
          }

          final moving = incoming != null && incoming != outgoing;
          final travel = _drag != 0
              ? (_drag > 0 ? 1 : -1)
              : _direction;

          if (!moving) {
            return Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < widget.children.length; i++)
                  _layer(
                    i,
                    visible: i == outgoing,
                    translation: Offset.zero,
                    shadow: false,
                  ),
              ],
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              for (var i = 0; i < widget.children.length; i++)
                if (i == outgoing)
                  _layer(
                    i,
                    visible: true,
                    translation: Offset(-travel * t, 0),
                    shadow: false,
                  )
                else if (i == incoming)
                  _layer(
                    i,
                    visible: true,
                    translation: Offset(travel * (1 - t), 0),
                    shadow: true,
                  )
                else
                  _layer(
                    i,
                    visible: false,
                    translation: Offset.zero,
                    shadow: false,
                  ),
            ],
          );
        },
      ),
        );
      },
    );
  }

  /// One tab, at a fixed position in the tree.
  ///
  /// Every tab is built here, every frame, in index order — the same length,
  /// the same order, whatever the transition is doing. Only whether it paints
  /// and where it sits changes.
  ///
  /// That fixed position is the whole point. The previous version built the
  /// transition from two separate `IndexedStack`s, one per screen on stage, so
  /// a tab lived at `Stack/children[0]` while idling and at
  /// `Stack/ClipRect/Stack/children[1]` mid-swipe. Flutter cannot migrate an
  /// element between positions, so it destroyed every tab and rebuilt it from
  /// scratch three times per swipe. Each rebuild restarted [Entrance] from
  /// transparent, so a swipe made the text fade in and drop again and again
  /// while the screen slid — the "text comes twice or thrice" report. It also
  /// silently broke the keep-alive promise this widget exists to keep: a scan
  /// in progress and every scroll offset were discarded on each tab change.
  ///
  /// `maintainState` keeps an off-stage tab mounted, so state survives; it just
  /// is not painted and does not take part in layout.
  ///
  /// The `ColoredBox` is load-bearing: every screen draws onto a clear canvas
  /// (the ambient drift is a translucent layer and the page paints no
  /// background), so a screen only looked opaque because it happened to sit
  /// directly on the shell's Scaffold. The moment two are on screen together,
  /// both are see-through and the transition reads as the app going
  /// transparent. Painting the canvas colour under each one makes "in front"
  /// mean something.
  Widget _layer(
    int index, {
    required bool visible,
    required Offset translation,
    required bool shadow,
  }) {
    final canvas = Theme.of(context).scaffoldBackgroundColor;

    // The wrapper chain is the same for every tab in every state — shadow or
    // not, on stage or not. Swapping a wrapper in and out when a tab becomes
    // the incoming screen changes the widget type at that position, and Flutter
    // answers a changed type by throwing the subtree away: the tab was rebuilt
    // the moment it started entering and again when it finished. Only the
    // decoration's value varies.
    return Visibility(
      visible: visible,
      maintainState: true,
      maintainAnimation: true,
      child: FractionalTranslation(
        translation: translation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: Offset(translation.dx.sign * 4, 0),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: ColoredBox(color: canvas, child: widget.children[index]),
        ),
      ),
    );
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
