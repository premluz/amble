import 'package:flutter/material.dart';

import '../tokens/motion_primitives.dart';
import '../tokens/semantic_theme.dart';

/// Tells a page when it has just become the shown view: the value changes
/// each time `AppViewTransition` brings it in (whether the pages slide or
/// fade), and is -1 while another view is shown.
class AppViewArrival extends InheritedWidget {
  const AppViewArrival({
    super.key,
    required this.arrival,
    required super.child,
  });

  final int arrival;

  /// 0 outside any `AppViewTransition` (a page shown on its own).
  static int of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppViewArrival>()?.arrival ??
      0;

  @override
  bool updateShouldNotify(AppViewArrival oldWidget) =>
      arrival != oldWidget.arrival;
}

/// A fill that colours in from [rest] to [color], one after another by
/// [order] (0 first … 1 last) within [MotionPrimitives.durationFillStaggerMs].
/// Plays when it first appears and again each time its page arrives
/// ([AppViewArrival]). Only fills that differ from [rest] animate; reduced
/// motion shows [color] at once.
class AppStaggeredFill extends StatefulWidget {
  const AppStaggeredFill({
    super.key,
    required this.rest,
    required this.color,
    required this.order,
    required this.builder,
  });

  final Color rest;
  final Color color;
  final double order;
  final Widget Function(BuildContext context, Color fill) builder;

  @override
  State<AppStaggeredFill> createState() => _AppStaggeredFillState();
}

class _AppStaggeredFillState extends State<AppStaggeredFill>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(
      milliseconds:
          MotionPrimitives.durationFillStaggerMs +
          MotionPrimitives.durationFastMs,
    ),
  );
  int? _arrival;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arrival = AppViewArrival.of(context);
    if (arrival < 0 || arrival == _arrival) return;
    _arrival = arrival;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// This item's own 0→1 within the shared timeline: it waits its turn,
  /// then fades over [MotionPrimitives.durationFastMs].
  double _progress(double t) {
    const total =
        MotionPrimitives.durationFillStaggerMs +
        MotionPrimitives.durationFastMs;
    final start =
        widget.order.clamp(0.0, 1.0) *
        MotionPrimitives.durationFillStaggerMs /
        total;
    return ((t - start) * total / MotionPrimitives.durationFastMs).clamp(
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.color == widget.rest) {
      return widget.builder(context, widget.color);
    }
    final curve = Theme.of(context).extension<AmbleTheme>()!.curveStandard;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => widget.builder(
        context,
        Color.lerp(
          widget.rest,
          widget.color,
          curve.transform(_progress(_controller.value)),
        )!,
      ),
    );
  }
}
