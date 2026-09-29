import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../tokens/liquid_morph_spec.dart';

/// Grows [child] out of a droplet at [origin]: the droplet widens on one
/// spring and stretches on a slightly slower one until it becomes the
/// child's own rounded shape, overshooting a touch before it settles.
///
/// Plays once, on mount. [origin] is in the child's local coordinates and
/// is clamped onto its bounds, so an anchor just outside the shape (a touch
/// point beside a popover) grows from the nearest edge. Reduced motion shows
/// the child immediately.
class AppLiquidMorph extends StatefulWidget {
  const AppLiquidMorph({
    super.key,
    required this.origin,
    required this.borderRadius,
    required this.child,
    this.spec = LiquidMorphSpec.popover,
  });

  final Offset origin;

  /// The child's own corner radius, which the droplet grows into.
  final double borderRadius;
  final LiquidMorphSpec spec;
  final Widget child;

  @override
  State<AppLiquidMorph> createState() => _AppLiquidMorphState();
}

class _AppLiquidMorphState extends State<AppLiquidMorph>
    with TickerProviderStateMixin {
  late final _width = AnimationController.unbounded(vsync: this);
  late final _height = AnimationController.unbounded(vsync: this);
  var _started = false;

  /// True once both axes have reached the full shape. The clip is dropped
  /// from then on, so the spring's settle can never touch the child's rim.
  var _formed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    for (final axis in [_width, _height]) {
      axis.addListener(() {
        if (_width.value >= 1 && _height.value >= 1) _formed = true;
      });
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _width.value = 1;
      _height.value = 1;
      return;
    }
    final spec = widget.spec;
    _spring(_width, spec.widthDuration, spec.widthBounce);
    _spring(_height, spec.heightDuration, spec.heightBounce);
  }

  void _spring(AnimationController axis, Duration duration, double bounce) {
    axis
        .animateWith(
          SpringSimulation(
            SpringDescription.withDurationAndBounce(
              duration: duration,
              bounce: bounce,
            ),
            0,
            1,
            0,
          ),
        )
        // Lands exactly on the final shape, not within spring tolerance.
        .then((_) {
          if (mounted) axis.value = 1;
        });
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: Listenable.merge([_width, _height]),
        builder: (context, child) =>
            _morphed(constraints.biggest, _width.value, _height.value, child!),
        child: widget.child,
      ),
    );
  }

  Widget _morphed(Size size, double pw, double ph, Widget child) {
    final spec = widget.spec;
    final origin = Offset(
      widget.origin.dx.clamp(0, size.width).toDouble(),
      widget.origin.dy.clamp(0, size.height).toDouble(),
    );
    final r0 = (spec.dropletDiameter ?? size.shortestSide) / 2;
    // The reveal stops at the child's own edges. Past 1 the spring would
    // pull an edge that started outside the child (a droplet sitting on the
    // rim) back INSIDE it, shaving the rim's highlight mid-entrance; the
    // overshoot is carried by the content scale instead.
    // Once formed it stays formed: the spring's return swing dips back
    // below 1, which must not shrink the reveal either.
    final cw = _formed ? 1.0 : math.min(pw, 1.0);
    final ch = _formed ? 1.0 : math.min(ph, 1.0);
    final rect = Rect.fromLTRB(
      lerpDouble(origin.dx - r0, 0, cw)!,
      lerpDouble(origin.dy - r0, 0, ch)!,
      lerpDouble(origin.dx + r0, size.width, cw)!,
      lerpDouble(origin.dy + r0, size.height, ch)!,
    );
    final radius = math.min(
      lerpDouble(r0, widget.borderRadius, math.min(cw, ch))!,
      rect.shortestSide / 2,
    );
    final scale = Matrix4.identity()
      ..translateByDouble(origin.dx, origin.dy, 0, 1)
      ..scaleByDouble(
        lerpDouble(spec.contentScaleFrom, 1, pw)!,
        lerpDouble(spec.contentScaleFrom, 1, ph)!,
        1,
        1,
      )
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1);

    return Opacity(
      opacity: (pw / spec.fadeInFraction).clamp(0, 1).toDouble(),
      child: Transform(
        transform: scale,
        child: ClipRRect(
          // Off once formed: the child's own edge takes over, so nothing
          // drawn at its rim (a selection ring) is shaved by the clip.
          clipBehavior: _formed ? Clip.none : Clip.antiAlias,
          clipper: _DropletClipper(
            RRect.fromRectAndRadius(rect, Radius.circular(math.max(0, radius))),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DropletClipper extends CustomClipper<RRect> {
  const _DropletClipper(this.shape);

  final RRect shape;

  @override
  RRect getClip(Size size) => shape;

  @override
  bool shouldReclip(_DropletClipper oldClipper) => oldClipper.shape != shape;
}
