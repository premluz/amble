/// Component motion tokens for the liquid pulse: a quick compress followed by
/// a spring release that overshoots once and settles. Times are seconds;
/// depth and squash are fractions of the object's own size.
///
/// `bounce` follows [SpringDescription.withDurationAndBounce] (the SwiftUI
/// duration/bounce model): 0 settles with no overshoot, higher values
/// overshoot further. Kept low so the result reads as fluid, not cartoonish.
class LiquidPulseSpec {
  const LiquidPulseSpec({
    required this.depth,
    required this.compressSeconds,
    required this.springSeconds,
    required this.bounce,
    this.squash = .45,
  }) : assert(depth >= 0 && depth < 1),
       assert(compressSeconds > 0),
       assert(springSeconds > 0),
       assert(bounce >= 0 && bounce < 1),
       assert(squash >= 0 && squash <= 1);

  /// How far the object compresses before the spring releases it.
  final double depth;
  final double compressSeconds;
  final double springSeconds;
  final double bounce;

  /// Share of the vertical deformation withheld from the horizontal axis.
  /// Unequal axes are what make the pulse read as liquid rather than a
  /// rigid zoom; 0 is a uniform scale.
  final double squash;

  /// Selecting a pill: felt more than seen.
  static const select = LiquidPulseSpec(
    depth: .06,
    compressSeconds: .09,
    springSeconds: .42,
    bounce: .5,
  );

  /// Selecting a large surface (a zone). Proportional depth would read as a
  /// lurch on a tall block, so it gives less and wobbles less than a pill.
  static const selectSurface = LiquidPulseSpec(
    depth: .025,
    compressSeconds: .09,
    springSeconds: .45,
    bounce: .45,
    squash: .5,
  );

  /// Completing a task: the same gesture with more give and a clearly
  /// elastic rebound — an overshoot and one visible return wobble.
  static const complete = LiquidPulseSpec(
    depth: .14,
    compressSeconds: .11,
    springSeconds: .6,
    bounce: .7,
    squash: .6,
  );

  Duration get compressDuration => Duration(
    microseconds: (compressSeconds * Duration.microsecondsPerSecond).round(),
  );

  Duration get springDuration => Duration(
    microseconds: (springSeconds * Duration.microsecondsPerSecond).round(),
  );
}
