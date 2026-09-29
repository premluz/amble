import 'package:flutter/widgets.dart';

import '../tokens/liquid_pulse_spec.dart';
import 'liquid_deformation.dart';

/// Plays a liquid pulse on [child] each time [active] turns true: a quick
/// compress, then a spring release that overshoots once and settles.
///
/// Turning [active] false never pulses — deselecting or un-completing is a
/// retreat, not an event worth marking. Layout is untouched; only paint is
/// transformed, so neighbours never shift while it plays.
class AppLiquidPulse extends StatefulWidget {
  const AppLiquidPulse({
    super.key,
    required this.active,
    required this.child,
    this.spec = LiquidPulseSpec.select,
    this.alignment = Alignment.center,
    this.suppressed = false,
  });

  /// True while the child is under direct manipulation (dragged, resized).
  /// Any pulse in flight snaps to rest, and activations are swallowed, so
  /// the child tracks the finger exactly.
  final bool suppressed;

  final bool active;
  final Widget child;
  final LiquidPulseSpec spec;

  /// The point that stays fixed while the child deforms.
  final Alignment alignment;

  @override
  State<AppLiquidPulse> createState() => _AppLiquidPulseState();
}

class _AppLiquidPulseState extends State<AppLiquidPulse>
    with SingleTickerProviderStateMixin {
  late final _deformation = LiquidDeformation(this);

  @override
  void didUpdateWidget(AppLiquidPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.suppressed) {
      _deformation.settle();
      return;
    }
    if (!widget.active || oldWidget.active) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) return;
    _deformation.pulse(widget.spec);
  }

  @override
  void dispose() {
    _deformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _deformation.listenable,
      // Always a Transform, even at rest: swapping it in and out would
      // change the tree shape and remount the child's gesture state.
      builder: (context, child) => Transform(
        alignment: widget.alignment,
        transform: _deformation.matrix(widget.spec.squash),
        child: child,
      ),
      child: widget.child,
    );
  }
}
