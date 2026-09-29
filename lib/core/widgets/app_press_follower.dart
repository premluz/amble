import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../tokens/liquid_press_spec.dart';
import 'liquid_deformation.dart';

/// Swells [child] with the shared Liquid Glass press while [pressed] is
/// true, for a surface that IS the visible button but is not the widget
/// receiving the touch — a dock pane drawn behind its single action.
class AppPressFollower extends StatefulWidget {
  const AppPressFollower({
    super.key,
    required this.pressed,
    required this.child,
    this.spec = LiquidPressSpec.standard,
  });

  final ValueListenable<bool> pressed;
  final LiquidPressSpec spec;
  final Widget child;

  @override
  State<AppPressFollower> createState() => _AppPressFollowerState();
}

class _AppPressFollowerState extends State<AppPressFollower>
    with SingleTickerProviderStateMixin {
  late final _deformation = LiquidDeformation(this);

  @override
  void initState() {
    super.initState();
    widget.pressed.addListener(_follow);
  }

  @override
  void didUpdateWidget(AppPressFollower oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pressed == widget.pressed) return;
    oldWidget.pressed.removeListener(_follow);
    widget.pressed.addListener(_follow);
  }

  void _follow() {
    if (!widget.pressed.value) {
      _deformation.unpress(widget.spec);
      return;
    }
    final size = context.size;
    if (size == null ||
        MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return;
    }
    _deformation.press(widget.spec, math.max(size.width, size.height));
  }

  @override
  void dispose() {
    widget.pressed.removeListener(_follow);
    _deformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _deformation.listenable,
    builder: (context, child) => Transform(
      alignment: Alignment.center,
      transform: _deformation.matrix(widget.spec.squash),
      child: child,
    ),
    child: widget.child,
  );
}
