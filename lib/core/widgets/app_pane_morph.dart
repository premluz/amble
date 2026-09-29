import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../tokens/liquid_morph_spec.dart';
import '../tokens/semantic_theme.dart';
import 'app_dock_primitives.dart';

/// A glass toolbar pane that morphs between two places, driven by
/// [animation] (typically a route's): at 0 it is the [origin] pane showing
/// [from] (e.g. the Inbox mic), at 1 the [target] pane showing [child] (the
/// voice toolbar). Going forward it springs, stretching past and settling,
/// like the dock's panes regrouping between views. Going back it speeds home
/// without bouncing, arriving early ([returnEnd]). Rects are in this widget's own coordinates; place it
/// with `Positioned.fill` over the screen.
class AppPaneMorph extends StatelessWidget {
  const AppPaneMorph({
    super.key,
    required this.theme,
    required this.animation,
    required this.origin,
    required this.target,
    required this.from,
    required this.child,
    this.spec = LiquidMorphSpec.dockPane,
    this.forwardSeconds,
  });

  final AmbleTheme theme;
  final Animation<double> animation;
  final Rect origin;
  final Rect target;
  final Widget from;
  final Widget child;
  final LiquidMorphSpec spec;

  /// How long [animation] takes to run forward, so the springs play in real
  /// time (settling early, then holding) instead of being stretched over
  /// it. Null plays them across the whole animation.
  final double? forwardSeconds;

  /// The pane itself fades in over this first share of the morph (and out
  /// over the last share on the way back), so a pane of a different
  /// material (a dark screen over a light page) takes over without a jump.
  static const surfaceFadeShare = .15;

  /// On the way back the pane is home once the animation is down to this
  /// value, and it gets there accelerating: a decisive return that speeds
  /// into place rather than drifting in.
  static const returnEnd = .55;

  static SpringSimulation _spring(Duration duration, double bounce) =>
      SpringSimulation(
        SpringDescription.withDurationAndBounce(
          duration: duration,
          bounce: bounce,
        ),
        0,
        1,
        0,
      );

  @override
  Widget build(BuildContext context) {
    final width = _spring(spec.widthDuration, spec.widthBounce);
    final height = _spring(spec.heightDuration, spec.heightBounce);
    final pop = _spring(
      Duration(
        microseconds: (spec.popSeconds * Duration.microsecondsPerSecond)
            .round(),
      ),
      spec.popBounce,
    );
    final seconds =
        forwardSeconds ??
        [
          spec.widthSeconds,
          spec.heightSeconds,
          spec.popSeconds,
        ].reduce(math.max);
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value.clamp(0.0, 1.0);
        final back = animation.status == AnimationStatus.reverse;
        // Played backwards, an ease-OUT curve reads as speeding up.
        double along(SpringSimulation spring) => back
            ? Curves.easeOutQuart.transform(
                ((t - returnEnd) / (1 - returnEnd)).clamp(0.0, 1.0),
              )
            : t == 1
            ? 1
            : spring.x(t * seconds);
        // The size spring plays only while arriving; at rest and on the
        // way back the pane is its own size.
        final arriving = animation.status == AnimationStatus.forward;
        final size = arriving ? lerpDouble(spec.popFrom, 1, along(pop))! : 1.0;
        return _frame(along(width), along(height), size, t, child!);
      },
    );
  }

  Widget _frame(double pw, double ph, double size, double t, Widget child) {
    final rect = Rect.fromLTRB(
      lerpDouble(origin.left, target.left, pw)!,
      lerpDouble(origin.top, target.top, ph)!,
      lerpDouble(origin.right, target.right, pw)!,
      lerpDouble(origin.bottom, target.bottom, ph)!,
    );
    final fade = spec.fadeInFraction;
    final fromOpacity = (1 - pw / fade).clamp(0.0, 1.0);
    final toOpacity = ((pw - fade) / fade).clamp(0.0, 1.0);
    final scale = lerpDouble(spec.contentScaleFrom, 1, math.min(pw, 1))!;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: Transform.scale(
            scale: size,
            child: Opacity(
              opacity: (t / surfaceFadeShare).clamp(0.0, 1.0),
              child: AppDockSurface(
                theme: theme,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radiusPillFull),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (fromOpacity > 0)
                        IgnorePointer(
                          child: Opacity(
                            opacity: fromOpacity,
                            child: Center(child: from),
                          ),
                        ),
                      // Laid out at its final size throughout, so it is revealed
                      // and grown rather than squeezed while the pane stretches.
                      IgnorePointer(
                        ignoring: t < 1,
                        child: Opacity(
                          opacity: toOpacity,
                          child: OverflowBox(
                            minWidth: target.width,
                            maxWidth: target.width,
                            minHeight: target.height,
                            maxHeight: target.height,
                            child: Transform.scale(scale: scale, child: child),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
