import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../tokens/depth_motion_spec.dart';

/// Recedes a WHOLE object (e.g. voice mode's controls) with a 0..1 [depth]
/// animation: at 0 it is slightly smaller and transparent, at 1 itself.
class AppDepthTransition extends StatelessWidget {
  const AppDepthTransition({
    super.key,
    required this.depth,
    required this.child,
    this.spec = DepthMotionSpec.standard,
  });

  final Animation<double> depth;
  final DepthMotionSpec spec;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: depth,
    child: child,
    builder: (context, child) {
      final t = depth.value.clamp(0.0, 1.0);
      return Opacity(
        opacity: t,
        child: Transform.scale(
          scale: lerpDouble(spec.fromScale, 1, t)!,
          child: child,
        ),
      );
    },
  );
}

/// Carries an [AppDepthPresence]'s emergence (0 = in depth, 1 = arrived) to
/// the parts that take part in it: [AppDepthShape] and [AppDepthFade].
class AppDepthScope extends InheritedWidget {
  const AppDepthScope({
    super.key,
    required this.emergence,
    required this.spec,
    required super.child,
    this.fadeText = true,
  });

  final Animation<double> emergence;
  final DepthMotionSpec spec;

  /// False keeps [AppDepthFade] text fully shown while the shape emerges —
  /// for an object whose text is already on screen (a task flying in from
  /// voice mode), where only its pill is new.
  final bool fadeText;

  static AppDepthScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppDepthScope>();

  @override
  bool updateShouldNotify(AppDepthScope oldWidget) =>
      emergence != oldWidget.emergence ||
      spec != oldWidget.spec ||
      fadeText != oldWidget.fadeText;
}

/// Marks an object's SHAPE (a pill, a badge): on arrival it springs up from
/// small and transparent — larger, smaller, then its real size — in place,
/// scaling about its own centre. On removal it simply shrinks and fades.
/// Outside an [AppDepthPresence] it is inert.
class AppDepthShape extends StatelessWidget {
  const AppDepthShape({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  final Widget child;

  /// The point it springs about — its own centre unless the shape sits
  /// inside a larger box (e.g. a pill within a wider hit area).
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final scope = AppDepthScope.maybeOf(context);
    if (scope == null) return child;
    final spec = scope.spec;
    final spring = SpringSimulation(
      SpringDescription.withDurationAndBounce(
        duration: Duration(
          microseconds:
              (spec.shapeSpringSeconds * Duration.microsecondsPerSecond)
                  .round(),
        ),
        bounce: spec.shapeBounce,
      ),
      0,
      1,
      0,
    );
    final phaseSeconds = spec.enterSeconds * (1 - spec.depthStart);
    return AnimatedBuilder(
      animation: scope.emergence,
      child: child,
      builder: (context, child) {
        final t = scope.emergence.value.clamp(0.0, 1.0);
        final receding = scope.emergence.status == AnimationStatus.reverse;
        final progress = receding || t == 1 ? t : spring.x(t * phaseSeconds);
        return Opacity(
          opacity: receding ? t : (t / spec.shapeFadeShare).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: lerpDouble(spec.shapeFromScale, 1, progress)!,
            alignment: alignment,
            child: child,
          ),
        );
      },
    );
  }
}

/// Marks an object's TEXT: it only fades in on arrival (and out on removal)
/// — no movement. Outside an [AppDepthPresence] it is inert.
class AppDepthFade extends StatelessWidget {
  const AppDepthFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = AppDepthScope.maybeOf(context);
    if (scope == null || !scope.fadeText) return child;
    final start = scope.spec.textFadeStart;
    return FadeTransition(
      opacity: scope.emergence.drive(CurveTween(curve: Interval(start, 1))),
      child: child,
    );
  }
}

/// An object's presence in a list: it can emerge from depth on arrival
/// ([animateIn], optionally after [delay] for staggering) and recede into
/// depth when [present] turns false, calling [onExited] once it is gone so
/// the caller can remove the data. Its own height opens before it emerges
/// and closes after it recedes, so neighbours make and give back room. The
/// object itself never moves or scales as a whole: its marked parts do
/// ([AppDepthShape] springs, [AppDepthFade] fades).
class AppDepthPresence extends StatefulWidget {
  const AppDepthPresence({
    super.key,
    required this.child,
    this.present = true,
    this.animateIn = false,
    this.delay = Duration.zero,
    this.onExited,
    this.spec = DepthMotionSpec.standard,
    this.emerge = true,
    this.opensSpace = true,
  });

  /// False for an object that doesn't sit in a flow (a task at its own time
  /// on the timeline): no room opens or closes, it only emerges and recedes
  /// in place.
  final bool opensSpace;

  /// False when something else supplies the entrance (a card flying into
  /// this slot): the space still opens and closes, but the parts stay put.
  final bool emerge;

  final Widget child;
  final bool present;
  final bool animateIn;
  final Duration delay;
  final VoidCallback? onExited;
  final DepthMotionSpec spec;

  @override
  State<AppDepthPresence> createState() => _AppDepthPresenceState();
}

class _AppDepthPresenceState extends State<AppDepthPresence>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.spec.enterDuration,
    reverseDuration: widget.spec.exitDuration,
    value: widget.animateIn ? 0 : 1,
  );
  // Built once, not in build(): a CurvedAnimation registers a listener on
  // its parent, so rebuilding them would leak one per frame.
  late final _size = CurvedAnimation(
    parent: _controller,
    curve: Interval(0, widget.spec.sizeEnd, curve: Curves.easeOutCubic),
  );
  // Linear on purpose: the shape's spring supplies its own timing.
  late final _emergence = CurvedAnimation(
    parent: _controller,
    curve: Interval(widget.spec.depthStart, 1),
  );
  Timer? _delay;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animateIn) return;
    if (_reducedMotion) {
      _controller.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }
    _delay = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  bool get _reducedMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations == true;

  @override
  void didUpdateWidget(AppDepthPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.present == oldWidget.present) return;
    if (widget.present) {
      _controller.forward();
      return;
    }
    _delay?.cancel();
    if (_reducedMotion) {
      _controller.value = 0;
      widget.onExited?.call();
      return;
    }
    _controller.reverse().then((_) {
      if (mounted) widget.onExited?.call();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _size.dispose();
    _emergence.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppDepthScope(
      emergence: widget.emerge ? _emergence : kAlwaysCompleteAnimation,
      spec: widget.spec,
      child: widget.child,
    );
    return widget.opensSpace
        ? _HeightReveal(reveal: _size, child: scope)
        : scope;
  }
}

/// Opens (and closes) an object's height, top-anchored. Unlike
/// [SizeTransition] it clips only the growing bottom edge, and nothing at
/// all once fully open, so a shape springing past its row's sides (or top)
/// is never cut off.
class _HeightReveal extends StatelessWidget {
  const _HeightReveal({required this.reveal, required this.child});

  final Animation<double> reveal;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: reveal,
    child: child,
    builder: (context, child) {
      final factor = reveal.value.clamp(0.0, 1.0);
      return ClipRect(
        clipBehavior: factor >= 1 ? Clip.none : Clip.hardEdge,
        clipper: const _BottomEdgeClipper(),
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: factor,
          child: child,
        ),
      );
    },
  );
}

/// Clips below the box's bottom edge only; sides and top stay open.
class _BottomEdgeClipper extends CustomClipper<Rect> {
  const _BottomEdgeClipper();

  @override
  // A full box width/height of slack on the open sides is far more than any
  // spring overshoot needs, while staying finite for the clip layer.
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, -size.height, size.width * 2, size.height);

  @override
  bool shouldReclip(_BottomEdgeClipper oldClipper) => false;
}
