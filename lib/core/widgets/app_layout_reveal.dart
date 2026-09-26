import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// Keeps mount-time positioning invisible without remounting the child.
class AppLayoutReveal extends StatefulWidget {
  const AppLayoutReveal({
    super.key,
    required this.child,
    this.duration = Duration.zero,
    this.curve = Curves.linear,
    this.opacityKey,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final Key? opacityKey;

  @override
  State<AppLayoutReveal> createState() => _AppLayoutRevealState();
}

class _AppLayoutRevealState extends State<AppLayoutReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.duration == Duration.zero ||
          MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => IgnorePointer(
      ignoring: !_controller.isCompleted,
      child: Opacity(
        key: widget.opacityKey,
        opacity: widget.curve.transform(_controller.value),
        child: child,
      ),
    ),
  );
}

/// Retains the outgoing screen underneath until the positioned page fades in.
Route<T> layoutRevealRoute<T>(BuildContext context, WidgetBuilder builder) {
  final theme = Theme.of(context).extension<AmbleTheme>()!;
  return PageRouteBuilder<T>(
    opaque: false,
    transitionDuration: theme.motionFast,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => AppLayoutReveal(
      duration: theme.motionFast,
      curve: theme.curveDecelerate,
      child: builder(context),
    ),
  );
}
