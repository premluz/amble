/// Component motion tokens for pressing any tappable control, after Apple's
/// Liquid Glass: press-and-hold swells the control toward the finger, and
/// release springs it home with a fluid overshoot. Times are seconds;
/// `releaseBounce` follows `SpringDescription.withDurationAndBounce`.
///
/// Growth is sized in pixels, not as a flat percentage: [growPx] is spread
/// over the control's longest side and clamped to [minGrow]..[maxGrow], so a
/// small icon button swells noticeably while a full-width row barely moves.
class LiquidPressSpec {
  const LiquidPressSpec({
    required this.growPx,
    required this.minGrow,
    required this.maxGrow,
    required this.growSeconds,
    required this.releaseSeconds,
    required this.releaseBounce,
    required this.squash,
    required this.holdFillAlpha,
  }) : assert(growPx >= 0),
       assert(minGrow >= 0 && minGrow <= maxGrow && maxGrow < 1),
       assert(growSeconds > 0 && releaseSeconds > 0),
       assert(releaseBounce >= 0 && releaseBounce < 1),
       assert(squash >= 0 && squash <= 1),
       assert(holdFillAlpha >= 0 && holdFillAlpha <= 1);

  /// Pixels the control's longest side grows by while held.
  final double growPx;
  final double minGrow;
  final double maxGrow;
  final double growSeconds;
  final double releaseSeconds;
  final double releaseBounce;

  /// Share of the vertical growth withheld from the horizontal axis.
  final double squash;

  /// Peak opacity of the glass fill shown over the control while held, so
  /// a fill-less (ghost) control visibly swells as a whole, not just its
  /// icon.
  final double holdFillAlpha;

  /// The one press every control shares.
  static const standard = LiquidPressSpec(
    growPx: 8,
    minGrow: .02,
    maxGrow: .18,
    growSeconds: .14,
    releaseSeconds: .45,
    releaseBounce: .5,
    squash: .15,
    holdFillAlpha: .08,
  );

  /// Fractional growth for a control whose longest side is [longestSide].
  double growFor(double longestSide) => longestSide <= 0
      ? 0
      : (growPx / longestSide).clamp(minGrow, maxGrow).toDouble();

  Duration get growDuration => Duration(
    microseconds: (growSeconds * Duration.microsecondsPerSecond).round(),
  );

  Duration get releaseDuration => Duration(
    microseconds: (releaseSeconds * Duration.microsecondsPerSecond).round(),
  );
}
