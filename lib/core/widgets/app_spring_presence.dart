import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../tokens/depth_motion_spec.dart';

/// Shows and hides its child by state ([visible]), the dock's way: arriving,
/// it fades in over [duration] while springing up from small — larger,
/// smaller, then its real size (the same bounce a pressed dock button
/// releases with); leaving, it fades and shrinks over [duration] without
/// bouncing — or, with [swell], first swells larger and then shrinks away
/// (submerging). A child that starts visible is simply there. Scales about its
/// own centre, so its layout never moves. Instant under reduced motion.
class AppSpringPresence extends StatefulWidget {
  const AppSpringPresence({
    super.key,
    required this.visible,
    required this.duration,
    required this.child,
    this.curve = Curves.easeInOut,
    this.spec = DepthMotionSpec.standard,
    this.swell = 0,
  });

  final bool visible;

  /// How much larger it swells before shrinking away when hidden (a share of
  /// its size, e.g. .15). 0 = shrink straight away.
  final double swell;

  /// The fade's duration both ways, and the shrink's on the way out.
  final Duration duration;
  final Curve curve;
  final DepthMotionSpec spec;
  final Widget child;

  @override
  State<AppSpringPresence> createState() => _AppSpringPresenceState();
}

class _AppSpringPresenceState extends State<AppSpringPresence>
    with TickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.visible ? 1 : 0,
  );
  late final _opacity = CurvedAnimation(parent: _fade, curve: widget.curve);
  // Unbounded: the spring overshoots past 1 and dips below it.
  late final _scale = AnimationController.unbounded(
    vsync: this,
    value: widget.visible ? 1 : widget.spec.shapeFromScale,
  );

  bool get _still => MediaQuery.maybeOf(context)?.disableAnimations == true;

  @override
  void didUpdateWidget(AppSpringPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fade.duration = widget.duration;
    if (widget.visible == oldWidget.visible) return;
    if (_still) {
      _fade.value = widget.visible ? 1 : 0;
      _scale.value = widget.visible ? 1 : widget.spec.shapeFromScale;
      return;
    }
    if (widget.visible) {
      _fade.forward();
      _spring();
    } else {
      _hide();
    }
  }

  void _hide() {
    if (widget.swell <= 0) {
      _fade.reverse();
      _shrink(widget.duration);
      return;
    }
    // The fade runs the whole way (its ease keeps it nearly opaque while it
    // swells); the scale swells first, then shrinks away.
    _fade.reverse();
    final swellTime = widget.duration * swellShare;
    _scale
        .animateTo(
          1 + widget.swell,
          duration: swellTime,
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (!mounted || widget.visible) return;
          _shrink(widget.duration - swellTime);
        });
  }

  /// Share of a swelling hide spent growing before it shrinks away.
  static const swellShare = .3;

  void _shrink(Duration duration) => _scale.animateTo(
    widget.spec.shapeFromScale,
    duration: duration,
    curve: Curves.easeInCubic,
  );

  void _spring() {
    final spec = widget.spec;
    _scale
        .animateWith(
          SpringSimulation(
            SpringDescription.withDurationAndBounce(
              duration: Duration(
                microseconds:
                    (spec.shapeSpringSeconds * Duration.microsecondsPerSecond)
                        .round(),
              ),
              bounce: spec.shapeBounce,
            ),
            _scale.value,
            1,
            0,
          ),
        )
        // Lands exactly on its real size, not within spring tolerance.
        .then((_) {
          if (mounted && widget.visible) _scale.value = 1;
        });
  }

  @override
  void dispose() {
    _opacity.dispose();
    _fade.dispose();
    _scale.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}
