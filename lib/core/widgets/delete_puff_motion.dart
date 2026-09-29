import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/delete_puff_spec.dart';

typedef _Tokens = DeletePuffMotionTokens;

class DeletePuffLobe {
  const DeletePuffLobe(this.center, this.radiusX, this.radiusY);

  final Offset center;
  final double radiusX;
  final double radiusY;
}

class DeletePuffCloud {
  const DeletePuffCloud({
    required this.center,
    required this.size,
    required this.opacity,
    required this.rotationDegrees,
    required this.lobes,
  });

  final Offset center;
  final double size;
  final double opacity;
  final double rotationDegrees;
  final List<DeletePuffLobe> lobes;
}

/// Samples the same seeded cloud trajectories as the motion-studio export.
Iterable<DeletePuffCloud> deletePuffCloudsAt({
  required double seconds,
  required double sourceWidth,
  DeletePuffSpec spec = const DeletePuffSpec(),
}) sync* {
  if (spec.count == 0 || sourceWidth <= 0) return;

  final t = (seconds / spec.durationSeconds).clamp(0.0, 1.0);
  final unitScale = sourceWidth / _Tokens.referenceObjectWidth * spec.scale;
  for (var index = 0; index < spec.count; index++) {
    double random(int n) => _random(spec.seed, index * 19 + n);
    final birth = _Tokens.firstBirth + random(1) * spec.stagger;
    final age = ((t - birth) / (1 - birth)).clamp(0.0, 1.0);
    if (t <= birth || age >= 1) continue;

    final angle =
        index / spec.count * math.pi * 2 +
        (random(2) - .5) * _Tokens.angleJitter;
    final travel = _ease(age);
    final drift = math.sin(age * math.pi) * spec.curl * (random(3) - .5);
    final radialDistance =
        (_Tokens.radialStart + spec.spread * travel) *
        (_Tokens.radialRandomBase + random(4) * _Tokens.radialRandomSpan);
    final center = Offset(
      math.cos(angle) * radialDistance + drift,
      math.sin(angle) * radialDistance * _Tokens.verticalRadialRatio -
          spec.lift * age * age,
    );
    final cloudSize =
        spec.size *
        (_Tokens.sizeRandomBase + random(5) * _Tokens.sizeRandomSpan) *
        _smooth(age / _Tokens.fadeInFraction) *
        (1 -
            _Tokens.sizeFadeAmount *
                _smooth((age - _Tokens.sizeFadeStart) / _Tokens.sizeFadeSpan));
    final lobes = List<DeletePuffLobe>.generate(_Tokens.lobeCount, (lobeIndex) {
      final angle = lobeIndex / _Tokens.lobeCount * math.pi * 2;
      final radius =
          cloudSize *
          (_Tokens.lobeRadiusBase +
              _random(spec.seed, index * 31 + lobeIndex) *
                  _Tokens.lobeRadiusSpan);
      return DeletePuffLobe(
        Offset(
          math.cos(angle) * cloudSize * _Tokens.lobeXRatio,
          math.sin(angle) * cloudSize * _Tokens.lobeYRatio,
        ),
        radius,
        radius * _Tokens.lobeHeightRatio,
      );
    }, growable: false);

    yield DeletePuffCloud(
      center: center * unitScale,
      size: cloudSize * unitScale,
      opacity: 1 - _smooth((age - spec.fadeStart) / (1 - spec.fadeStart)),
      rotationDegrees:
          (random(6) - .5) * _Tokens.clusterRotation +
          age * (random(7) - .5) * _Tokens.rotationDrift,
      lobes: lobes
          .map(
            (lobe) => DeletePuffLobe(
              lobe.center * unitScale,
              lobe.radiusX * unitScale,
              lobe.radiusY * unitScale,
            ),
          )
          .toList(growable: false),
    );
  }
}

double _random(int seed, int value) {
  final n =
      math.sin(seed * _Tokens.seedMultiplier + value * _Tokens.laneMultiplier) *
      _Tokens.randomScale;
  return n - n.floorToDouble();
}

double _smooth(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _ease(double value) {
  final remainder = 1 - value.clamp(0.0, 1.0);
  return 1 - remainder * remainder * remainder;
}
