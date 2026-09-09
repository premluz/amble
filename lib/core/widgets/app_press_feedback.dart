import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// Wraps a tap target so pressing it feels answered: a soft circular wash
/// expands from the exact point the finger landed, while the whole control
/// dips very slightly and springs back on release.
///
/// Requested directly: "let's introduce tap 'interaction' on buttons and
/// hit areas ... nice animation starting from place of tap ... subtle ...
/// so the touch feels 'responsive' assurance." Confirmed via
/// AskUserQuestion as ripple-from-tap-point PLUS the slight scale-down,
/// rather than either alone.
///
/// **Why not `InkWell`/`InkResponse`.** Material's own ink splash only
/// paints on a [Material] ancestor, which several of this design system's
/// controls deliberately don't have (a `CupertinoButton`, a plain
/// `Container` with its own `BoxDecoration`), and it is unavailable on the
/// Cupertino branch every adaptive widget here takes on iOS — the primary
/// target platform. Rather than leave iOS with no positional feedback at
/// all (its native controls only fade opacity), this paints the wash
/// itself, so both platforms get the identical interaction rather than two
/// different ones. Existing `InkWell`/`InkResponse` usages that already
/// work on Material are replaced by this for the same reason: one
/// behaviour everywhere beats two that only coincidentally look similar.
///
/// Purely presentational — it adds no semantics of its own. Callers that
/// need a `Semantics` button role (see [AppFieldActionButton]) still wrap
/// this themselves, exactly as they did around the widget this replaced.
///
/// A null [onTap] renders [child] with no gesture handling and no
/// animation at all, matching every other control's "null means disabled"
/// contract in this layer.
class AppPressFeedback extends StatefulWidget {
  const AppPressFeedback({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.rippleColor,
    this.behavior = HitTestBehavior.opaque,
    this.decorationOnly = false,
    this.maxRippleRadius,
  });

  final Widget child;

  /// The tap to run, when this widget owns the gesture. With
  /// [decorationOnly] set this is never invoked — it is then only a
  /// non-null/null flag for whether the control is enabled (a disabled
  /// one animates nothing).
  final VoidCallback? onTap;

  /// True when [child] ALREADY handles its own tap — a real platform
  /// button ([AppButton]'s `CupertinoButton`/`ElevatedButton`), which
  /// must keep its own hit-testing, semantics and disabled rendering
  /// intact. This widget then only *observes* pointers to drive the
  /// animation, via a [Listener] rather than a [GestureDetector], so it
  /// never competes with the child in the gesture arena.
  ///
  /// Load-bearing, and learned the hard way twice: routing the tap
  /// through this widget while the platform button sat inside it meant
  /// the button won the arena and the wrapper's own `onTap` never fired
  /// (every sheet opened from an `AppButton` silently stopped opening),
  /// and neutralising the button with an `IgnorePointer` instead left 40
  /// existing tests tapping a non-hit-testable node. Observing pointers
  /// keeps the child's behaviour byte-for-byte unchanged.
  final bool decorationOnly;

  /// Clips the ripple to the control's own rounded corners. Ignored when
  /// [shape] is [BoxShape.circle] (a circle needs no corner radius), and
  /// null means square corners.
  final BorderRadius? borderRadius;

  /// [BoxShape.circle] clips the ripple to a circle instead of a
  /// (possibly rounded) rectangle — for the circular icon buttons, whose
  /// wash would otherwise square off at their bounds.
  final BoxShape shape;

  /// Defaults to [AmbleTheme.colorTextPrimary] at a low alpha (see
  /// [_rippleAlpha]) — a neutral darkening that reads correctly on every
  /// surface this wraps, rather than a tint that would fight an accent- or
  /// category-colored fill. Pass a color explicitly for a control whose
  /// own fill is dark enough that a dark wash would be invisible (e.g.
  /// [AppButton]'s filled primary variant, which passes the light
  /// foreground color instead).
  final Color? rippleColor;

  /// Forwarded to the underlying [GestureDetector] — [HitTestBehavior.opaque]
  /// by default so padded-out tap targets stay tappable across their whole
  /// area, matching what the raw `GestureDetector`s this replaces already
  /// specified.
  final HitTestBehavior behavior;

  /// Caps how far the wash grows, in logical pixels. Null (the default)
  /// lets it expand to the control's furthest corner, which is what a
  /// real button wants — the whole surface acknowledges the press.
  ///
  /// A large, mostly-invisible hit area passes a small fixed value
  /// instead: the Timeline's tap-to-create layer covers the entire day
  /// column, and an uncapped wash there would flood the whole view rather
  /// than marking the spot the finger actually landed on.
  final double? maxRippleRadius;

  @override
  State<AppPressFeedback> createState() => _AppPressFeedbackState();
}

class _AppPressFeedbackState extends State<AppPressFeedback>
    with TickerProviderStateMixin {
  /// Drives the expanding/fading wash. Runs forward on tap-down and is
  /// left to finish on its own — a ripple that got cut short the instant
  /// the finger lifted would make a quick tap (the common case) show
  /// almost no feedback at all.
  late final AnimationController _rippleController;

  /// Drives the press-down dip. Separate from [_rippleController] because
  /// it is genuinely reversible: it holds while the finger is down and
  /// springs back on release/cancel, however long that takes.
  late final AnimationController _scaleController;

  /// Where the finger landed, in this widget's own local coordinates —
  /// the ripple's origin. Null before the first tap.
  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(vsync: this);
    _scaleController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Starts both animations from [localPosition]. Shared by the
  /// gesture-owning and the decoration-only ([Listener]) paths, so the
  /// two produce an identical animation from an identical origin.
  void _startPress(Offset localPosition, AmbleTheme theme) {
    setState(() => _tapPosition = localPosition);
    _rippleController
      ..duration = theme.motionNormal
      ..forward(from: 0);
    // motionFast (not motionNormal): the dip has to land while the finger
    // is still going down, so it reads as the control yielding to the
    // press rather than animating after it.
    _scaleController
      ..duration = theme.motionFast
      ..forward();
  }

  void _handleTapDown(TapDownDetails details, AmbleTheme theme) =>
      _startPress(details.localPosition, theme);

  void _handleTapCancel() => _releasePress();

  void _releasePress() {
    if (!mounted) return;
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Disabled: no gesture, no animation, no extra layers in the tree —
    // byte-for-byte the child a caller would have rendered without this
    // wrapper at all.
    if (widget.onTap == null) return widget.child;

    final rippleColor = widget.rippleColor ?? theme.colorTextPrimary;

    final animated = AnimatedBuilder(
      animation: Listenable.merge([_rippleController, _scaleController]),
      builder: (context, child) {
        final pressT = theme.curveStandard.transform(_scaleController.value);
        return Transform.scale(
          // A deliberately small dip — the point is a physical sense of
          // give, not a visible shrink. Anything deeper starts to read
          // as the control moving away from the finger.
          scale: 1 - (_pressScaleDepth * pressT),
          // _RipplePaint is built INSIDE the builder, not passed as the
          // pre-built `child` below: whether it renders at all depends
          // on the ripple controller's own state (it drops out entirely
          // once the wash finishes), so a version hoisted out of the
          // rebuild would paint the first ripple and then never clear
          // it. Only the caller's own `child` — genuinely animation-
          // independent — is hoisted.
          child: _RipplePaint(
            controller: _rippleController,
            origin: _tapPosition,
            color: rippleColor,
            borderRadius: widget.borderRadius,
            shape: widget.shape,
            curve: theme.curveStandard,
            maxRadius: widget.maxRippleRadius,
            child: child!,
          ),
        );
      },
      // Built once, outside the builder: the caller's own subtree never
      // changes as a result of these animations, so rebuilding it every
      // frame would be pure waste on what may be a whole list row.
      child: widget.child,
    );

    // Decoration-only: the child owns its own tap, so this must NOT enter
    // the gesture arena at all. A Listener observes raw pointer events
    // without competing for them — see [AppPressFeedback.decorationOnly].
    if (widget.decorationOnly) {
      return Listener(
        onPointerDown: (event) => _startPress(event.localPosition, theme),
        onPointerUp: (_) => _releasePress(),
        onPointerCancel: (_) => _releasePress(),
        child: animated,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (details) => _handleTapDown(details, theme),
      // The action runs from onTapUp, NOT onTap. `onTap` only fires once
      // the gesture arena has declared a winner, and inside a scrollable
      // the arena holds the tap open to see whether the pointer turns
      // into a scroll — so the action landed a visible beat after the
      // finger lifted. Reported directly: "tap and nothing happens for
      // some time (and action after a moment)." `onTapUp` fires the
      // instant the finger lifts. Same reasoning (and the same fix)
      // `place_task_line.dart` already uses for the Timeline's own
      // tap-to-place gesture.
      onTapUp: (details) {
        _releasePress();
        widget.onTap?.call();
      },
      onTapCancel: _handleTapCancel,
      child: animated,
    );
  }
}

/// How far the control dips while held, as a fraction of its own size.
const double _pressScaleDepth = 0.02;

/// Peak opacity of the wash, at the very start of the ripple. Low by
/// design — the ripple is confirmation, not decoration, and reads on both
/// the light and dark palettes at this value.
const double _rippleAlpha = 0.12;

/// Paints the expanding wash beneath [child], clipped to the control's own
/// bounds so it never bleeds past a rounded corner or a circular edge.
class _RipplePaint extends StatelessWidget {
  const _RipplePaint({
    required this.controller,
    required this.origin,
    required this.color,
    required this.borderRadius,
    required this.shape,
    required this.curve,
    required this.maxRadius,
    required this.child,
  });

  final AnimationController controller;
  final Offset? origin;
  final Color color;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Curve curve;
  final double? maxRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tapOrigin = origin;
    // Nothing tapped yet, or the ripple has fully played out — skip the
    // clip and painter entirely rather than keeping an inert layer
    // around. `isCompleted` (not `isDismissed`) is the finished state
    // here: this controller only ever runs forward, so it settles at 1.0
    // and never returns to 0.
    if (tapOrigin == null || controller.isCompleted || controller.isDismissed) {
      return child;
    }

    return ClipPath(
      clipper: _ShapeClipper(borderRadius: borderRadius, shape: shape),
      child: CustomPaint(
        // foregroundPainter, NOT painter: `painter` draws BEHIND the
        // child, and every control this wraps has an opaque fill of its
        // own (a Container with a color, an ElevatedButton, a
        // CupertinoButton) — so the wash was painted and then immediately
        // covered by that fill, invisible on every platform. Reported
        // directly as "cant see ripple on android"; it was equally
        // invisible on iOS. The wash is deliberately low-alpha (see
        // [_rippleAlpha]) precisely so it can sit OVER the control's
        // content without obscuring the label underneath it.
        foregroundPainter: _RipplePainter(
          progress: curve.transform(controller.value),
          origin: tapOrigin,
          color: color,
          maxRadius: maxRadius,
        ),
        child: child,
      ),
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  const _ShapeClipper({required this.borderRadius, required this.shape});

  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  Path getClip(Size size) {
    final bounds = Offset.zero & size;
    if (shape == BoxShape.circle) {
      return Path()..addOval(bounds);
    }
    final radius = borderRadius;
    if (radius == null) return Path()..addRect(bounds);
    return Path()..addRRect(radius.toRRect(bounds));
  }

  @override
  bool shouldReclip(_ShapeClipper oldClipper) =>
      oldClipper.borderRadius != borderRadius || oldClipper.shape != shape;
}

class _RipplePainter extends CustomPainter {
  const _RipplePainter({
    required this.progress,
    required this.origin,
    required this.color,
    required this.maxRadius,
  });

  /// 0 → 1, already curve-transformed by the caller.
  final double progress;
  final Offset origin;
  final Color color;

  /// Caps how far the wash grows. Null lets it reach the furthest corner
  /// (the right behaviour for a real control, which should be washed
  /// edge to edge) — see [AppPressFeedback.maxRippleRadius] for why a
  /// large invisible hit area passes a fixed cap instead.
  final double? maxRadius;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    // Radius needed to reach whichever corner is furthest from the tap —
    // so the wash always covers the whole control by the time it finishes,
    // regardless of where in it the finger landed. Without this, a tap
    // near one edge would leave the opposite corner visibly unwashed.
    final furthestCorner = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((corner) => (corner - origin).distance).reduce(math.max);
    final target = maxRadius == null
        ? furthestCorner
        : math.min(furthestCorner, maxRadius!);

    // Fades as it grows: fully visible at the moment of contact, gone by
    // the time it reaches the edge, so the control returns to rest without
    // a hard cut.
    final paint = Paint()
      ..color = color.withValues(alpha: _rippleAlpha * (1 - progress));
    canvas.drawCircle(origin, target * progress, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.origin != origin ||
      oldDelegate.color != color;
}
