/// Tier 1 — raw motion durations/curve control points, no semantic meaning.
/// Curve control points are plain doubles here (not `Curve`/`Cubic`, which
/// are `package:flutter` types) to keep this file Flutter-free; Tier 2
/// constructs the actual `Curve` objects.
abstract final class MotionPrimitives {
  static const durationInstantMs = 100;
  static const durationFastMs = 150;
  static const durationNormalMs = 250;
  static const durationSlowMs = 400;

  // Cubic-bezier control points (x1, y1, x2, y2).
  static const curveStandard = (0.4, 0.0, 0.2, 1.0);
  static const curveDecelerate = (0.0, 0.0, 0.2, 1.0);
  static const curveAccelerate = (0.4, 0.0, 1.0, 1.0);
}
