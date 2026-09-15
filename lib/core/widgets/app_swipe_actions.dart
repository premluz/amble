import 'package:flutter/gestures.dart'
    show HorizontalDragGestureRecognizer;
import 'package:flutter/material.dart';

import '../haptics.dart';
import '../tokens/semantic_theme.dart';

/// How far past an action's resting width the finger must travel before
/// releasing ACTIVATES that action instead of merely parking it open.
///
/// Expressed as a multiple of the resting width rather than a raw pixel
/// distance so the threshold scales with [AppSwipeAction.extent] — a wider
/// action needs a proportionally longer pull, which is what keeps the two
/// stages feeling like one continuous gesture at any size.
const double _kActivateThresholdFactor = 2.0;

/// One side's revealed action: what it looks like, and what it does.
class AppSwipeAction {
  const AppSwipeAction({
    required this.icon,
    required this.background,
    required this.onActivate,
    required this.semanticLabel,
    this.destructive = false,
  });

  /// Whether arming this action warrants the heavier [AmbleHaptic.warning]
  /// instead of the ordinary [AmbleHaptic.selection] — that enum reserves
  /// `warning` for exactly this case ("a destructive target became armed"),
  /// so a remove-style action must set it rather than feeling identical to
  /// a constructive one under the finger.
  final bool destructive;

  final IconData icon;

  /// The colour behind the icon, which is also what the row slides to
  /// reveal — so this doubles as the action's identity at a glance
  /// (destructive vs. constructive) before the icon is even legible.
  final Color background;

  final VoidCallback onActivate;

  /// Announced by screen readers in place of the visual-only icon. This
  /// widget adds no button semantics of its own otherwise, matching
  /// [AppPressFeedback]'s "purely presentational" contract.
  final String semanticLabel;
}

/// A horizontally swipeable row with a **two-stage** reveal on each side,
/// requested directly: "swiping when released, it reveals the button, but
/// if swiping continues, it actually activates the button ... So when it's
/// released, it keeps the button on so it can be tucked. But if continued,
/// it actually activates."
///
/// Stage one — drag to roughly the action's own width and release: the row
/// stays parked open, showing the button as a real tap target. Stage two —
/// keep pulling past [_kActivateThresholdFactor] and release: the action
/// fires immediately and the row snaps shut, no tap needed.
///
/// **Why not `Dismissible`.** `Dismissible` is one-stage by construction:
/// crossing its threshold always dismisses, and it removes the row from the
/// list rather than parking it. Neither half of the requested interaction
/// (park-open, or a non-destructive *schedule* action that must leave the
/// row in place) can be expressed with it.
///
/// **Gesture ownership.** Only [GestureDetector.onHorizontalDrag*] is
/// claimed here, deliberately — the child keeps every vertical and tap
/// gesture it already had. A row with its own inner tap targets (see the
/// Inbox row's three) therefore keeps all of them working while parked
/// open; this widget never wraps them in a competing tap recognizer. The
/// enclosing scrollable keeps vertical drags for the same reason.
class AppSwipeActions extends StatefulWidget {
  const AppSwipeActions({
    super.key,
    required this.child,
    this.startAction,
    this.endAction,
    this.extent = 72.0,
    this.haptics = const PlatformHaptics(),
  });

  final Widget child;

  /// Revealed by swiping RIGHT (the row slides right, exposing this at the
  /// leading edge). Null disables that direction entirely.
  final AppSwipeAction? startAction;

  /// Revealed by swiping LEFT, at the trailing edge. Null disables it.
  final AppSwipeAction? endAction;

  /// Each action's resting width — how far the row parks open at stage one.
  final double extent;

  /// Injected for the same reason [AppPressFeedback] injects it: this is a
  /// leaf presentational widget, and tests pump it with no `ProviderScope`.
  final Haptics haptics;

  @override
  State<AppSwipeActions> createState() => _AppSwipeActionsState();
}

class _AppSwipeActionsState extends State<AppSwipeActions>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1),
  );

  /// Current horizontal offset of the row, in pixels. Positive reveals
  /// [AppSwipeActions.startAction], negative [AppSwipeActions.endAction].
  double _offset = 0;

  /// True once the finger has crossed the activate threshold during THIS
  /// drag, used only to fire the boundary haptic exactly once per crossing
  /// rather than on every pointer move past it.
  bool _pastThreshold = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _activateThreshold =>
      widget.extent * _kActivateThresholdFactor;

  /// Whether a pull in [direction] is allowed at all — a side with no
  /// action configured must not rubber-band open onto an empty background.
  bool _allows(double direction) => direction > 0
      ? widget.startAction != null
      : widget.endAction != null;

  void _handleDragStart(DragStartDetails details) {
    // _offset is deliberately NOT reset here: a drag beginning on a
    // parked-open row continues from where it sits, rather than snapping
    // shut under the finger before moving again.
    _pastThreshold = false;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    var next = _offset + details.delta.dx;
    if (!_allows(next)) next = 0;
    // Hard-stop a little past the activate threshold rather than letting
    // the row travel the full screen width: past this point more travel
    // conveys nothing, since the outcome is already decided.
    final limit = _activateThreshold + widget.extent;
    next = next.clamp(-limit, limit);

    final crossed = next.abs() >= _activateThreshold;
    if (crossed && !_pastThreshold) {
      final arming = next > 0 ? widget.startAction : widget.endAction;
      widget.haptics.play(
        arming?.destructive ?? false
            ? AmbleHaptic.warning
            : AmbleHaptic.selection,
      );
    }
    _pastThreshold = crossed;

    setState(() => _offset = next);
  }

  void _handleDragEnd(DragEndDetails details) {
    final action = _offset > 0 ? widget.startAction : widget.endAction;
    if (action == null) {
      _animateTo(0);
      return;
    }

    // Stage two: past the threshold, releasing fires the action and closes.
    if (_offset.abs() >= _activateThreshold) {
      widget.haptics.play(AmbleHaptic.tap);
      _animateTo(0);
      action.onActivate();
      return;
    }

    // Stage one: parked open if pulled at least halfway to the resting
    // width, otherwise treated as an aborted swipe and closed.
    final parked = _offset.abs() >= widget.extent / 2;
    _animateTo(parked ? widget.extent * _offset.sign : 0);
  }

  void _animateTo(double target) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final from = _offset;
    if (from == target) return;

    _controller
      ..stop()
      ..duration = theme.motionFast
      ..reset();
    final animation = CurvedAnimation(
      parent: _controller,
      curve: theme.curveStandard,
    );
    void listener() {
      setState(() {
        _offset = from + (target - from) * animation.value;
      });
    }

    animation.addListener(listener);
    _controller.forward().whenComplete(() {
      animation.removeListener(listener);
      if (mounted) setState(() => _offset = target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final revealed = _offset > 0 ? widget.startAction : widget.endAction;

    return RawGestureDetector(
      // RawGestureDetector, NOT GestureDetector — and this is load-bearing.
      // A plain GestureDetector here sits ABOVE the child in the tree, so a
      // child that owns a tap (the Inbox row owns three) wins the arena on
      // every press and the horizontal drag is starved: measured directly,
      // the row did not move one pixel through an entire swipe. Declaring
      // the recognizer at this level instead lets it contend on equal terms
      // — the child still wins a stationary press (a tap stays a tap), and
      // this wins once the finger actually travels horizontally past slop.
      //
      // Same defect, same session, as `place_task_line.dart`'s own
      // tap-vs-long-press arena note — see it for the fuller writeup.
      gestures: <Type, GestureRecognizerFactory>{
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer>(
              () => HorizontalDragGestureRecognizer(debugOwner: this),
              (HorizontalDragGestureRecognizer recognizer) => recognizer
                ..onStart = _handleDragStart
                ..onUpdate = _handleDragUpdate
                ..onEnd = _handleDragEnd,
            ),
      },
      child: Stack(
        children: [
          if (revealed != null)
            Positioned.fill(
              child: _ActionSurface(
                action: revealed,
                theme: theme,
                alignment: _offset > 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                width: _offset.abs(),
                // The icon only reads as "armed" once releasing would
                // actually fire it, so the two stages stay visually
                // distinct rather than differing only by how far the row
                // happens to have travelled.
                armed: _offset.abs() >= _activateThreshold,
              ),
            ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// The coloured panel behind the row, sized to exactly the revealed
/// distance so it appears to be uncovered by the row rather than sliding
/// in behind it.
class _ActionSurface extends StatelessWidget {
  const _ActionSurface({
    required this.action,
    required this.theme,
    required this.alignment,
    required this.width,
    required this.armed,
  });

  final AppSwipeAction action;
  final AmbleTheme theme;
  final Alignment alignment;
  final double width;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: action.background,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: ClipRect(
            child: Align(
              alignment: alignment,
              // Never wider than its own resting extent, so the icon stays
              // pinned near the edge instead of drifting with the finger
              // through the whole overshoot.
              widthFactor: 1.0,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: theme.spacingMd),
                child: AnimatedScale(
                  scale: armed ? 1.15 : 1.0,
                  duration: theme.motionFast,
                  curve: theme.curveStandard,
                  child: Semantics(
                    label: action.semanticLabel,
                    button: true,
                    child: Icon(
                      action.icon,
                      color: theme.colorSurfacePrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
