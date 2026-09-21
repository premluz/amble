import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A live audio-level waveform — a row of bars whose heights track
/// [level] (0.0-1.0), used to show that a microphone is actively picking
/// up speech.
///
/// Added for the voice-capture flow (`voice_capture_screen.dart`), and
/// deliberately built as a standalone, SDK-agnostic component per direct
/// request ("make it a reusable component that we have in Storybook
/// because we'll be reusing it") — it takes a plain `double`, not a
/// `speech_to_text` package type, so any future caller can drive it from
/// whatever audio source it has (a different STT package, a voice-memo
/// player, a test) without this widget depending on that package.
///
/// [isActive] false (paused/idle) settles every bar to a flat, still
/// baseline instead of animating — a paused recorder should not look like
/// it's still listening.
class AppVoiceWaveform extends StatefulWidget {
  const AppVoiceWaveform({
    super.key,
    required this.theme,
    required this.level,
    this.isActive = true,
    this.barCount = 24,
  });

  final AmbleTheme theme;

  /// Current input amplitude, 0.0 (silence) to 1.0 (loudest expected
  /// input). Values outside that range are clamped, not asserted — a
  /// caller feeding a raw platform sound-level value (which
  /// `speech_to_text`'s own docs note is NOT normalized the same way
  /// across Android/iOS) does not need to pre-clamp it itself.
  final double level;

  final bool isActive;

  /// Number of bars drawn. Default matches the reference mock's density
  /// at phone width — kept a parameter rather than hardcoded so a
  /// narrower use (e.g. inline in a smaller control) can ask for fewer.
  final int barCount;

  @override
  State<AppVoiceWaveform> createState() => _AppVoiceWaveformState();
}

class _AppVoiceWaveformState extends State<AppVoiceWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.theme.spacingXl,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _WaveformPainter(
            theme: widget.theme,
            level: widget.level.clamp(0.0, 1.0),
            isActive: widget.isActive,
            barCount: widget.barCount,
            // Radians, not the raw [0,1] AnimationController value — each
            // bar reads its own phase-shifted point on one continuous
            // sine cycle (see the painter), so this needs to keep
            // growing across repeats rather than resetting to 0 every
            // loop, or the motion would visibly stutter at each repeat
            // boundary.
            animationClock: _controller.value * 2 * math.pi,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.theme,
    required this.level,
    required this.isActive,
    required this.barCount,
    required this.animationClock,
  });

  final AmbleTheme theme;
  final double level;
  final bool isActive;
  final int barCount;
  final double animationClock;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = theme.borderWidthHairline * 3;
    final gap = (size.width - barCount * barWidth) / (barCount - 1);
    final paint = Paint()
      ..color = theme.colorAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var i = 0; i < barCount; i++) {
      final x = i * (barWidth + gap) + barWidth / 2;

      double barHeight;
      if (!isActive) {
        // Flat, still baseline — no animation term at all, per
        // [AppVoiceWaveform.isActive]'s own doc comment.
        barHeight = size.height * 0.12;
      } else {
        // Each bar samples the SAME sine wave at a different phase
        // offset, scaled by the live [level] — this is what makes the
        // bars ripple across the row ("constantly moving across", per
        // direct request) rather than pulsing in lockstep, while still
        // all responding to one shared amplitude.
        final phase = i * (2 * math.pi / barCount) * 3;
        final wave = (math.sin(animationClock + phase) + 1) / 2; // 0..1
        final amplitude = 0.15 + level * 0.85;
        barHeight = size.height * (0.12 + wave * amplitude * 0.88);
      }

      final center = size.height / 2;
      canvas.drawLine(
        Offset(x, center - barHeight / 2),
        Offset(x, center + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) =>
      oldDelegate.level != level ||
      oldDelegate.isActive != isActive ||
      oldDelegate.animationClock != animationClock ||
      oldDelegate.theme != theme;
}
