import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_press_feedback.dart';

/// A navigation control's press: the shared squeeze and haptic, but no dark
/// wash over the label — its active state is instead the next surface up
/// behind it ([AppNavWash], `colorSurfaceSecondary`, the Settings group
/// surface), the same subtle step as the selected day in the week strip.
/// [builder] gets whether it is currently held.
class AppNavPress extends StatefulWidget {
  const AppNavPress({
    super.key,
    required this.onTap,
    required this.builder,
    this.borderRadius,
  });

  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool pressed) builder;
  final BorderRadius? borderRadius;

  @override
  State<AppNavPress> createState() => _AppNavPressState();
}

class _AppNavPressState extends State<AppNavPress> {
  var _pressed = false;

  void _set(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _set(true),
    onPointerUp: (_) => _set(false),
    onPointerCancel: (_) => _set(false),
    child: AppPressFeedback(
      onTap: widget.onTap,
      ripple: false,
      borderRadius: widget.borderRadius,
      child: widget.builder(context, _pressed),
    ),
  );
}

/// The active/hover surface of a navigation control, drawn BEHIND [child]
/// (a label or an icon) and a little past it, taking no layout — so the
/// label never moves. Shown while [visible] (pressed, or a drag hovering
/// it); it fades in and out.
class AppNavWash extends StatelessWidget {
  const AppNavWash({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final outset = theme.spacingXs;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -outset * 2,
          right: -outset * 2,
          top: -outset,
          bottom: -outset,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: theme.motionFast,
              curve: theme.curveStandard,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorSurfaceSecondary,
                  borderRadius: BorderRadius.circular(theme.radiusPill),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
