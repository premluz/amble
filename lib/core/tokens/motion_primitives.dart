/// Tier 1 — raw motion durations/curve control points, no semantic meaning.
/// Curve control points are plain doubles here (not `Curve`/`Cubic`, which
/// are `package:flutter` types) to keep this file Flutter-free; Tier 2
/// constructs the actual `Curve` objects.
abstract final class MotionPrimitives {
  static const durationInstantMs = 100;
  static const durationFastMs = 150;
  static const durationContextDockMs = 200;
  static const durationContextDockStaggerMs = 35;
  static const durationViewCrossfadeMs = 140;
  static const durationNormalMs = 250;
  static const durationSlowMs = 400;

  /// Flutter's own default `PageRoute` transition is 300ms. This clears it
  /// with real headroom rather than a hair's margin — at 350ms the reveal
  /// began the instant the modal finished, which still read as "already
  /// done" because the eye hadn't settled on the timeline yet (reported
  /// directly). The extra beat is what makes the animation register as
  /// something that happened rather than something already finished.
  static const durationRouteSettleMs = 500;

  /// [AppSheet]'s own slide-in/out duration (2026-09-23) — reverses the
  /// earlier zero-duration decision for this ONE route, requested directly
  /// ("universal pattern for slide in animation of sheets"). `durationSlow`
  /// (400ms) read as sluggish for a sheet specifically (a smaller, closer
  /// surface than a full-screen route), so this is its own rung rather
  /// than reusing `durationSlowMs` as-is.
  ///
  /// Also the tail window of a measured IME animation: the sheet joins
  /// once this much native animation time remains. Faster IMEs shorten
  /// the window to their own duration; slower ones retain a head start.
  static const durationSheetSlideMs = 180;

  /// Route/barrier timing and non-Android keyboard entrance grace period.
  /// Android sheet motion follows reported IME progress instead.
  static const durationKeyboardSettleMs = 260;

  /// Ensures hardware keyboards or a suppressed IME cannot hide a sheet forever.
  static const durationKeyboardRequestTimeoutMs = 1000;

  // Cubic-bezier control points (x1, y1, x2, y2).
  static const curveStandard = (0.4, 0.0, 0.2, 1.0);
  static const curveDecelerate = (0.0, 0.0, 0.2, 1.0);
  static const curveAccelerate = (0.4, 0.0, 1.0, 1.0);
}
