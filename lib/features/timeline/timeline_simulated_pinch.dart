import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../core/tokens/component_tokens.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/providers/preferences_providers.dart';

class SimulatedPinch {
  const SimulatedPinch({
    required this.center,
    required this.startScale,
    required this.zoomIn,
    required this.scrollOffset,
  });
  static const zoomFactor = 1.25;
  final Offset center;
  final double startScale;
  final bool zoomIn;
  final double scrollOffset;

  double scaleAt(double progress) {
    final target = (zoomIn ? startScale * zoomFactor : startScale / zoomFactor)
        .clamp(
          TimelinePixelsPerMinuteSetting.minPixelsPerMinute,
          TimelinePixelsPerMinuteSetting.maxPixelsPerMinute,
        );
    return startScale + (target - startScale) * progress;
  }

  double scrollAt(double scale) => timelineAnchoredScrollOffset(
    scrollOffset: scrollOffset,
    anchorY: center.dy,
    fromScale: startScale,
    toScale: scale,
  );
}

/// The scroll offset that keeps the time under [anchorY] (a y in the
/// viewport) where it is on screen as the scale goes from [fromScale] to
/// [toScale]: zoom around the pointer, not the top of the day. Shared by
/// the simulated pinch and scroll-wheel zoom.
double timelineAnchoredScrollOffset({
  required double scrollOffset,
  required double anchorY,
  required double fromScale,
  required double toScale,
}) =>
    (scrollOffset + anchorY - TimelineScrollTokens.topClearance) *
        toScale /
        fromScale +
    TimelineScrollTokens.topClearance -
    anchorY;

/// Shares the recording dots' tokens, but exists only during a keyboard pinch.
class SimulatedPinchPainter extends CustomPainter {
  const SimulatedPinchPainter({
    required this.pinch,
    required this.progress,
    required this.theme,
  });
  static const fadeFraction = .2;
  final SimulatedPinch pinch;
  final double progress;
  final AmbleTheme theme;

  List<Offset> get centers {
    final ratio =
        pinch.scaleAt(theme.curveStandard.transform(progress)) /
        pinch.startScale;
    final offset = Offset(0, TouchVisualizerTokens.diameter(theme) * ratio);
    return [pinch.center - offset, pinch.center + offset];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = math
        .min(progress / fadeFraction, (1 - progress) / fadeFraction)
        .clamp(0.0, 1.0);
    final fill = Paint()
      ..color = TouchVisualizerTokens.fill(theme)
          .withValues(alpha: TouchVisualizerTokens.fillAlpha * opacity);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = TouchVisualizerTokens.ringWidth(theme)
      ..color = TouchVisualizerTokens.ring(theme)
          .withValues(alpha: TouchVisualizerTokens.ringAlpha * opacity);
    for (final center in centers) {
      final radius = TouchVisualizerTokens.diameter(theme) / 2;
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, ring);
    }
  }

  @override
  bool shouldRepaint(SimulatedPinchPainter oldDelegate) =>
      pinch != oldDelegate.pinch ||
      progress != oldDelegate.progress ||
      theme != oldDelegate.theme;
}
