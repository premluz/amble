import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/delete_puff_spec.dart';
import 'delete_puff_motion.dart';

typedef _Tokens = DeletePuffMotionTokens;

/// Emits the delete puff from a delete control and survives its removal.
abstract final class AppDeletePuff {
  static void show({
    required BuildContext context,
    DeletePuffSpec spec = const DeletePuffSpec(),
  }) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true ||
        spec.count == 0) {
      return;
    }
    final overlay = Overlay.of(context, rootOverlay: true);
    final source = context.findRenderObject();
    final target = overlay.context.findRenderObject();
    if (source is! RenderBox || target is! RenderBox || !source.hasSize) {
      throw StateError('Delete puff requires a laid-out delete control.');
    }
    final origin = source.localToGlobal(
      Offset(source.size.width / 2, 0),
      ancestor: target,
    );
    _insert(overlay, origin, source.size.width, spec);
  }

  static void _insert(
    OverlayState overlay,
    Offset origin,
    double sourceWidth,
    DeletePuffSpec spec,
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
            child: DeletePuffEffect(
              origin: origin,
              sourceWidth: sourceWidth,
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

class DeletePuffEffect extends StatefulWidget {
  const DeletePuffEffect({
    super.key,
    required this.origin,
    required this.sourceWidth,
    required this.spec,
    required this.onFinished,
  });

  final Offset origin;
  final double sourceWidth;
  final DeletePuffSpec spec;
  final VoidCallback onFinished;

  @override
  State<DeletePuffEffect> createState() => _DeletePuffEffectState();
}

class _DeletePuffEffectState extends State<DeletePuffEffect>
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
    child: CustomPaint(painter: _DeletePuffPainter(_motion, widget)),
  );
}

class _DeletePuffPainter extends CustomPainter {
  _DeletePuffPainter(this.motion, this.effect) : super(repaint: motion);

  final Animation<double> motion;
  final DeletePuffEffect effect;

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = motion.value * effect.spec.durationSeconds;
    final paint = Paint();
    for (final cloud in deletePuffCloudsAt(
      seconds: seconds,
      sourceWidth: effect.sourceWidth,
      spec: effect.spec,
    )) {
      canvas.save();
      canvas.translate(
        effect.origin.dx + cloud.center.dx,
        effect.origin.dy + cloud.center.dy,
      );
      canvas.rotate(cloud.rotationDegrees * math.pi / 180);
      _drawLobes(
        canvas,
        paint,
        cloud,
        effect.spec.shadowColor,
        cloud.size * _Tokens.shadowOffsetRatio,
      );
      _drawLobes(canvas, paint, cloud, effect.spec.smokeColor, 0);
      for (final index in _Tokens.highlightLobeIndices) {
        final lobe = cloud.lobes[index];
        paint.color = effect.spec.highlightColor.withValues(
          alpha: cloud.opacity,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: lobe.center.translate(
              0,
              -cloud.size * _Tokens.highlightOffsetRatio,
            ),
            width: lobe.radiusX * 2 * _Tokens.highlightWidthRatio,
            height: lobe.radiusY * 2 * _Tokens.highlightHeightRatio,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  void _drawLobes(
    Canvas canvas,
    Paint paint,
    DeletePuffCloud cloud,
    Color color,
    double verticalOffset,
  ) {
    paint.color = color.withValues(alpha: cloud.opacity);
    for (final lobe in cloud.lobes) {
      canvas.drawOval(
        Rect.fromCenter(
          center: lobe.center.translate(0, verticalOffset),
          width: lobe.radiusX * 2,
          height: lobe.radiusY * 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DeletePuffPainter oldDelegate) =>
      oldDelegate.effect != effect;
}
