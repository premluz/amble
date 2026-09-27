import 'package:flutter/material.dart';

import '../tokens/bubble_burst_spec.dart';
import '../tokens/semantic_theme.dart';
import 'bubble_burst_motion.dart';

/// Decorative feedback that survives a completed row disappearing or reflowing.
abstract final class AppBubbleBurst {
  /// [origin] is the pill's top-center in [context]'s local coordinates.
  static void show({
    required BuildContext context,
    required Offset origin,
    required double sourceWidth,
    BubbleBurstSpec spec = const BubbleBurstSpec(),
  }) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true ||
        spec.countPerLane == 0 ||
        spec.frontDots == 0) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final source = context.findRenderObject();
    final target = overlay.context.findRenderObject();
    if (source is! RenderBox || target is! RenderBox || !source.hasSize) {
      throw StateError(
        'Bubble emission requires a laid-out source and overlay.',
      );
    }
    final position = source.localToGlobal(origin, ancestor: target);
    final color = Theme.of(context).extension<AmbleTheme>()!.colorAccent;
    _insert(overlay, position, sourceWidth, color, spec);
  }

  static void _insert(
    OverlayState overlay,
    Offset position,
    double sourceWidth,
    Color color,
    BubbleBurstSpec spec,
  ) {
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
            child: BubbleBurstEffect(
              origin: position,
              sourceWidth: sourceWidth,
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

class BubbleBurstEffect extends StatefulWidget {
  const BubbleBurstEffect({
    super.key,
    required this.origin,
    required this.sourceWidth,
    required this.color,
    required this.spec,
    required this.onFinished,
  });
  final Offset origin;
  final double sourceWidth;
  final Color color;
  final BubbleBurstSpec spec;
  final VoidCallback onFinished;

  @override
  State<BubbleBurstEffect> createState() => _BubbleBurstEffectState();
}

class _BubbleBurstEffectState extends State<BubbleBurstEffect>
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
    child: CustomPaint(painter: _BubblePainter(_motion, widget)),
  );
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.motion, this.effect) : super(repaint: motion);
  final Animation<double> motion;
  final BubbleBurstEffect effect;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final particle in bubbleParticlesAt(
      seconds: motion.value * effect.spec.seconds,
      sourceWidth: effect.sourceWidth,
      spec: effect.spec,
    )) {
      paint.color = effect.color.withValues(alpha: particle.opacity);
      canvas.drawCircle(
        effect.origin + particle.offset,
        particle.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) =>
      oldDelegate.effect != effect;
}
