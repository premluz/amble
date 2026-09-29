/// Component motion tokens for the completion ripple: hairline rings that
/// leave the source shape's own outline and spread outward, like water after
/// a stone. Times are seconds; spread is in logical pixels.
class WaterRippleSpec {
  const WaterRippleSpec({
    this.rings = 2,
    this.ringSeconds = .9,
    this.ringDelaySeconds = .14,
    this.spread = 22,
    this.strokeWidth = 1,
    this.peakOpacity = .22,
  }) : assert(rings >= 0),
       assert(ringSeconds > 0),
       assert(ringDelaySeconds >= 0),
       assert(spread > 0),
       assert(strokeWidth > 0),
       assert(peakOpacity >= 0 && peakOpacity <= 1);

  final int rings;
  final double ringSeconds;
  final double ringDelaySeconds;

  /// How far the outermost ring travels beyond the source outline.
  final double spread;
  final double strokeWidth;

  /// Opacity at the moment a ring leaves the outline; it only fades after.
  final double peakOpacity;

  double get seconds =>
      rings == 0 ? 0 : (rings - 1) * ringDelaySeconds + ringSeconds;

  Duration get duration =>
      Duration(microseconds: (seconds * Duration.microsecondsPerSecond).ceil());
}
