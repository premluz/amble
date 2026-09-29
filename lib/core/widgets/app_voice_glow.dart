import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/color_primitives.dart';
import '../tokens/semantic_theme.dart';
import '../tokens/voice_mode_tokens.dart';

/// Voice mode's backdrop: the page colour fading in over what is behind
/// ([scrim]), and a layered glow of accent tones rising from the bottom edge
/// ([rise]) up to [VoiceModeTokens.glowReach] of the height, so the top of
/// the screen stays clean. Its lobes drift and breathe slowly, so it feels
/// alive rather than a flat radial wash. Still under reduced motion.
class AppVoiceGlow extends StatefulWidget {
  const AppVoiceGlow({
    super.key,
    required this.theme,
    required this.scrim,
    required this.rise,
  });

  final AmbleTheme theme;
  final Animation<double> scrim;
  final Animation<double> rise;

  @override
  State<AppVoiceGlow> createState() => _AppVoiceGlowState();
}

class _AppVoiceGlowState extends State<AppVoiceGlow>
    with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: VoiceModeTokens.glowDriftDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeOf(context)?.disableAnimations == true;
    if (still) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('voice-glow'),
    painter: _VoiceGlowPainter(
      theme: widget.theme,
      scrim: widget.scrim,
      rise: widget.rise,
      drift: _drift,
    ),
  );
}

class _VoiceGlowPainter extends CustomPainter {
  _VoiceGlowPainter({
    required this.theme,
    required this.scrim,
    required this.rise,
    required this.drift,
  }) : super(repaint: Listenable.merge([scrim, rise, drift]));

  final AmbleTheme theme;
  final Animation<double> scrim;
  final Animation<double> rise;
  final Animation<double> drift;

  Color _tone(VoiceGlowTone tone) => switch (tone) {
    VoiceGlowTone.accent => theme.colorAccent,
    VoiceGlowTone.deep => Color.lerp(
      theme.colorAccent,
      theme.colorSurfaceBase,
      VoiceModeTokens.glowDeepMix,
    )!,
    VoiceGlowTone.light => Color.lerp(
      theme.colorAccent,
      theme.colorTextPrimary,
      VoiceModeTokens.glowLightMix,
    )!,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    final base = theme.colorSurfaceBase;
    canvas.drawRect(
      bounds,
      Paint()..color = base.withValues(alpha: base.a * scrim.value),
    );
    final risen = rise.value.clamp(0.0, 1.0);
    if (risen <= 0) return;
    final reach = size.height * VoiceModeTokens.glowReach * risen;

    canvas.saveLayer(bounds, Paint());
    final layers = VoiceModeTokens.glowLayers;
    for (var i = 0; i < layers.length; i++) {
      _paintLayer(canvas, size, reach, layers[i], i);
    }
    // Fades every layer out toward the reach line, whatever its shape, so
    // nothing above it is ever tinted.
    canvas.drawRect(
      bounds,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader =
            LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: const [
                ColorPrimitives.white,
                ColorPrimitives.transparent,
              ],
            ).createShader(
              Rect.fromLTRB(0, size.height - reach, size.width, size.height),
            ),
    );
    canvas.restore();
  }

  void _paintLayer(
    Canvas canvas,
    Size size,
    double reach,
    VoiceGlowLayer layer,
    int index,
  ) {
    // Each layer is offset in phase, and odd layers run the other way, so
    // the lobes slide past each other instead of moving in step.
    final phase =
        drift.value * 2 * math.pi * (index.isOdd ? -1 : 1) +
        index * math.pi / 2;
    final x =
        size.width * (layer.x + VoiceModeTokens.glowDriftX * math.sin(phase));
    final breathe = 1 + VoiceModeTokens.glowBreathe * math.cos(phase);
    final color = _tone(layer.tone);
    canvas
      ..save()
      ..translate(x, size.height)
      ..scale(size.width * layer.width / 2, reach * layer.height * breathe);
    canvas.drawCircle(
      Offset.zero,
      1,
      Paint()
        ..shader = RadialGradient(
          stops: const [0, VoiceModeTokens.glowMidStop, 1],
          colors: [
            color.withValues(alpha: layer.alpha),
            color.withValues(
              alpha: layer.alpha * VoiceModeTokens.glowMidAlphaShare,
            ),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VoiceGlowPainter oldDelegate) =>
      theme != oldDelegate.theme ||
      scrim != oldDelegate.scrim ||
      rise != oldDelegate.rise;
}
