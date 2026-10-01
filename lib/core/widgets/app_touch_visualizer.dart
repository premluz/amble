import 'package:flutter/material.dart';

import '../tokens/component_tokens.dart';
import '../tokens/semantic_theme.dart';

/// Shows a soft dot under every finger on [child] — for screen recordings,
/// like iOS's "show touches" (requested directly, from a SwiftUI
/// `TouchVisualizer`). Unlike a drag gesture, the [Listener] here only
/// observes: every touch still reaches the app underneath. Each finger gets
/// its own dot, so pinches and two-finger presses show both.
class AppTouchVisualizer extends StatefulWidget {
  const AppTouchVisualizer({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<AppTouchVisualizer> createState() => _AppTouchVisualizerState();
}

class _AppTouchVisualizerState extends State<AppTouchVisualizer> {
  /// Live and leaving touches by pointer id; a released dot stays until its
  /// fade has played.
  final _touches = <int, _Touch>{};
  int _serial = 0;

  void _down(PointerDownEvent event) {
    if (!widget.enabled) return;
    setState(
      () => _touches[event.pointer] = _Touch(_serial++, event.localPosition),
    );
  }

  void _move(PointerMoveEvent event) {
    final touch = _touches[event.pointer];
    if (touch == null || touch.released) return;
    setState(() => touch.position = event.localPosition);
  }

  void _up(PointerEvent event) {
    final touch = _touches[event.pointer];
    if (touch == null) return;
    setState(() => touch.released = true);
  }

  void _gone(_Touch touch) {
    if (!mounted) return;
    setState(() => _touches.removeWhere((_, t) => identical(t, touch)));
  }

  @override
  void didUpdateWidget(AppTouchVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _touches.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Mounted while off too, so the toggle never changes the tree's shape
    // above the app (the handlers simply ignore touches).
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final size = TouchVisualizerTokens.diameter(theme);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          for (final touch in _touches.values)
            Positioned(
              key: ValueKey(touch.serial),
              left: touch.position.dx - size / 2,
              top: touch.position.dy - size / 2,
              child: IgnorePointer(
                child: _TouchDot(
                  theme: theme,
                  size: size,
                  released: touch.released,
                  onGone: () => _gone(touch),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Touch {
  _Touch(this.serial, this.position);

  final int serial;
  Offset position;
  bool released = false;
}

/// One fingertip: settles in from slightly small, and on release fades
/// while easing a little larger.
class _TouchDot extends StatefulWidget {
  const _TouchDot({
    required this.theme,
    required this.size,
    required this.released,
    required this.onGone,
  });

  final AmbleTheme theme;
  final double size;
  final bool released;
  final VoidCallback onGone;

  @override
  State<_TouchDot> createState() => _TouchDotState();
}

class _TouchDotState extends State<_TouchDot> with TickerProviderStateMixin {
  late final _appear = AnimationController(
    vsync: this,
    duration: TouchVisualizerTokens.appear(widget.theme),
  )..forward();
  late final _release = AnimationController(
    vsync: this,
    duration: TouchVisualizerTokens.release(widget.theme),
  );

  @override
  void initState() {
    super.initState();
    if (widget.released) _letGo();
  }

  @override
  void didUpdateWidget(_TouchDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.released && !oldWidget.released) _letGo();
  }

  void _letGo() => _release.forward().whenComplete(widget.onGone);

  @override
  void dispose() {
    _appear.dispose();
    _release.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return AnimatedBuilder(
      animation: Listenable.merge([_appear, _release]),
      builder: (context, child) {
        final arrive = theme.curveDecelerate.transform(_appear.value);
        final leave = theme.curveStandard.transform(_release.value);
        final scale =
            TouchVisualizerTokens.appearScale +
            (1 - TouchVisualizerTokens.appearScale) * arrive +
            (TouchVisualizerTokens.releaseScale - 1) * leave;
        return Opacity(
          opacity: arrive * (1 - leave),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TouchVisualizerTokens.fill(theme),
          border: Border.all(
            color: TouchVisualizerTokens.ring(theme),
            width: TouchVisualizerTokens.ringWidth(theme),
          ),
        ),
      ),
    );
  }
}
