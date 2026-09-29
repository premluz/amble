import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../tokens/liquid_slide_spec.dart';

/// A selection highlight that moves between connected segments like a
/// liquid (see [LiquidSlideSpec]): place it in a `Stack` under the
/// segments, with [target] the selected segment's rect in that Stack. It
/// renders [child] (the highlight's look, filling its box) positioned on
/// its current, animating rect. First build: simply there. Reduced motion:
/// jumps.
class AppLiquidSlide extends StatefulWidget {
  const AppLiquidSlide({
    super.key,
    required this.target,
    required this.child,
    this.spec = LiquidSlideSpec.connected,
  });

  final Rect target;
  final Widget child;
  final LiquidSlideSpec spec;

  @override
  State<AppLiquidSlide> createState() => _AppLiquidSlideState();
}

class _AppLiquidSlideState extends State<AppLiquidSlide>
    with TickerProviderStateMixin {
  late final _left = AnimationController.unbounded(
    vsync: this,
    value: widget.target.left,
  );
  late final _right = AnimationController.unbounded(
    vsync: this,
    value: widget.target.right,
  );

  @override
  void didUpdateWidget(AppLiquidSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.target;
    if (target.left == oldWidget.target.left &&
        target.right == oldWidget.target.right) {
      return;
    }
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      _left.value = target.left;
      _right.value = target.right;
      return;
    }
    final currentCentre = (_left.value + _right.value) / 2;
    final movingRight = target.center.dx >= currentCentre;
    final spec = widget.spec;
    // The edge the highlight is heading toward leads; the other trails.
    _spring(
      _right,
      target.right,
      movingRight ? spec.leadDuration : spec.trailDuration,
      movingRight ? spec.leadBounce : spec.trailBounce,
    );
    _spring(
      _left,
      target.left,
      movingRight ? spec.trailDuration : spec.leadDuration,
      movingRight ? spec.trailBounce : spec.leadBounce,
    );
  }

  void _spring(
    AnimationController edge,
    double to,
    Duration duration,
    double bounce,
  ) {
    edge
        .animateWith(
          SpringSimulation(
            SpringDescription.withDurationAndBounce(
              duration: duration,
              bounce: bounce,
            ),
            edge.value,
            to,
            edge.velocity,
          ),
        )
        // Lands exactly on the segment, not within spring tolerance.
        .then((_) {
          if (mounted) edge.value = to;
        });
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_left, _right]),
    child: widget.child,
    builder: (context, child) {
      final target = widget.target;
      final left = math.min(_left.value, _right.value);
      final right = math.max(_left.value, _right.value);
      final width = math.max(right - left, 0.0);
      // Thins as it stretches past its resting width, like a drop pulled.
      final stretch = target.width <= 0
          ? 0.0
          : math.max(0.0, width / target.width - 1);
      final thin =
          target.height * math.min(widget.spec.squash * stretch, .5) / 2;
      return Positioned(
        left: left,
        width: width,
        top: target.top + thin,
        height: math.max(target.height - thin * 2, 0),
        child: child!,
      );
    },
  );
}
