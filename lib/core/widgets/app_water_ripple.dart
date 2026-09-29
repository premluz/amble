import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import '../tokens/water_ripple_spec.dart';

/// One ring's state at an instant: how far it has left the outline, and how
/// visible it still is.
typedef WaterRing = ({double distance, double opacity, double progress});

/// Share of a ring's life spent fading in, so it never pops on.
const _fadeInFraction = .08;

/// Each later ring travels this much less than the one before — water
/// loses energy as it spreads.
const _ringDecay = .25;

/// Deterministic ring state at [seconds] into the effect.
List<WaterRing> waterRingsAt({
  required double seconds,
  required WaterRippleSpec spec,
}) {
  final rings = <WaterRing>[];
  for (var i = 0; i < spec.rings; i++) {
    final t = (seconds - i * spec.ringDelaySeconds) / spec.ringSeconds;
    if (t <= 0 || t >= 1) continue;
    final reach = spec.spread * math.max(0, 1 - i * _ringDecay);
    final fadeIn = math.min(1, t / _fadeInFraction);
    rings.add((
      distance: Curves.easeOutCubic.transform(t) * reach,
      opacity: spec.peakOpacity * fadeIn * math.pow(1 - t, 1.5),
      progress: t,
    ));
  }
  return rings;
}

/// Decorative completion feedback: hairline rings leave the source shape's
/// own outline and spread outward. Lives on the root overlay so it survives
/// the source row reflowing or disappearing.
abstract final class AppWaterRipple {
  /// [rect] is the source shape in [context]'s local coordinates, and
  /// [radius] its corner radius; the rings keep that shape as they grow.
  static void show({
    required BuildContext context,
    required Rect rect,
    required double radius,
    WaterRippleSpec spec = const WaterRippleSpec(),
  }) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true ||
        spec.rings == 0) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final source = context.findRenderObject();
    final target = overlay.context.findRenderObject();
    if (source is! RenderBox || target is! RenderBox || !source.hasSize) {
      throw StateError('Water ripple requires a laid-out source and overlay.');
    }
    final topLeft = source.localToGlobal(rect.topLeft, ancestor: target);
    final color = Theme.of(context).extension<AmbleTheme>()!.colorAccent;
    late OverlayEntry entry;
    var removed = false;
    void remove() {
      if (removed) return;
      removed = true;
      entry.remove();
      entry.dispose();
    }

    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: WaterRippleEffect(
              rect: topLeft & rect.size,
              radius: radius,
              color: color,
              spec: spec,
              onFinished: remove,
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
  }
}

class WaterRippleEffect extends StatefulWidget {
  const WaterRippleEffect({
    super.key,
    required this.rect,
    required this.radius,
    required this.color,
    required this.spec,
    required this.onFinished,
  });

  final Rect rect;
  final double radius;
  final Color color;
  final WaterRippleSpec spec;
  final VoidCallback onFinished;

  @override
  State<WaterRippleEffect> createState() => _WaterRippleEffectState();
}

class _WaterRippleEffectState extends State<WaterRippleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion =
      AnimationController(vsync: this, duration: widget.spec.duration)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onFinished();
        });

  @override
  void initState() {
    super.initState();
    _motion.forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _RipplePainter(_motion, widget)),
  );
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.motion, this.effect) : super(repaint: motion);

  final Animation<double> motion;
  final WaterRippleEffect effect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    final maxRadius = effect.rect.shortestSide / 2;
    for (final ring in waterRingsAt(
      seconds: motion.value * effect.spec.seconds,
      spec: effect.spec,
    )) {
      paint
        ..color = effect.color.withValues(alpha: ring.opacity)
        // Thins as it spreads, like a wave losing height.
        ..strokeWidth = effect.spec.strokeWidth * (1 - .4 * ring.progress);
      final bounds = effect.rect.inflate(ring.distance);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds,
          Radius.circular(math.min(effect.radius, maxRadius) + ring.distance),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.effect != effect;
}
