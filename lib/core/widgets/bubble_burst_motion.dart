import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tokens/bubble_burst_spec.dart';

class BubbleParticle {
  const BubbleParticle(this.offset, this.radius, this.opacity);
  final Offset offset;
  final double radius;
  final double opacity;
}

/// Pure seeded sampling: no per-frame randomness or frame-rate-dependent steps.
Iterable<BubbleParticle> bubbleParticlesAt({
  required double seconds,
  required double sourceWidth,
  BubbleBurstSpec spec = const BubbleBurstSpec(),
}) sync* {
  for (var lane = 0; lane < BubbleBurstSpec.lanes; lane++) {
    for (var index = 0; index < spec.countPerLane; index++) {
      final particle = _sample(seconds, sourceWidth, spec, lane, index);
      if (particle != null) yield particle;
    }
  }
}

double _random(int seed, int lane) {
  final n =
      math.sin(seed * BubbleBurstSpec.seedX + lane * BubbleBurstSpec.seedLane) *
      BubbleBurstSpec.seedScale;
  return n - n.floor();
}

double _smooth(double t) => t * t * (3 - 2 * t);

BubbleParticle? _sample(
  double seconds,
  double width,
  BubbleBurstSpec c,
  int lane,
  int j,
) {
  double random(int seed) => _random(seed, lane);
  final age = _age(seconds, c, lane, j);
  if (age < 0 || age >= 1) return null;
  final fadeIn = _smooth((age / BubbleBurstSpec.fadeInFraction).clamp(0, 1));
  final opacity = c.frontDots * fadeIn * (1 - _smooth(age));
  final heading =
      -math.pi / 2 +
      (random(j + 3) - .5) * BubbleBurstSpec.headingSpread * c.bubbleRandomness;
  final travel =
      age *
      width *
      c.bubbleTravel *
      (BubbleBurstSpec.travelBase +
          random(j + 4) * BubbleBurstSpec.travelVariation * c.bubbleRandomness);
  final scatter =
      math.sin(age * math.pi / 2) * width * c.bubbleSpread * c.bubbleRandomness;
  final laneX = ((lane + .5) / BubbleBurstSpec.lanes - .5) * width;
  return BubbleParticle(
    Offset(
      laneX + travel * math.cos(heading) + (random(j + 8) - .5) * scatter,
      travel * math.sin(heading),
    ),
    width *
        BubbleBurstSpec.radiusFraction *
        (BubbleBurstSpec.radiusBase +
            random(j + 5) *
                BubbleBurstSpec.radiusVariation *
                c.bubbleRandomness) *
        (1 - age * BubbleBurstSpec.radiusDecay),
    opacity,
  );
}

double _age(double seconds, BubbleBurstSpec c, int lane, int j) {
  double random(int seed) => _random(seed, lane);
  final birth =
      lane * c.bubbleStagger +
      (j + random(j + 1) * c.bubbleRandomness * BubbleBurstSpec.birthJitter) /
          c.bubbleRate;
  final lifetime =
      c.bubbleLinger *
      (1 -
          c.bubbleRandomness *
              BubbleBurstSpec.lifetimeVariation *
              random(j + 7));
  return (seconds - birth) / lifetime;
}
