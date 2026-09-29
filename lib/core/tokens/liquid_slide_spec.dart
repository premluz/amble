/// Component motion tokens for a selection highlight moving between
/// connected segments (a tab switch, a dock's grouped buttons): gooey, not
/// rigid. The edge leading the travel springs to its new place quickly; the
/// trailing edge follows on a slower spring — so the highlight stretches
/// toward its target (thinning a touch as it does), then its tail catches up
/// and it settles on the new segment's exact size. Times are seconds.
class LiquidSlideSpec {
  const LiquidSlideSpec({
    required this.leadSeconds,
    required this.leadBounce,
    required this.trailSeconds,
    required this.trailBounce,
    required this.squash,
  }) : assert(leadSeconds > 0 && trailSeconds > 0),
       assert(leadBounce >= 0 && leadBounce < 1),
       assert(trailBounce >= 0 && trailBounce < 1),
       assert(squash >= 0 && squash < 1);

  final double leadSeconds;
  final double leadBounce;
  final double trailSeconds;
  final double trailBounce;

  /// How much the highlight thins per unit of stretch (a highlight twice its
  /// resting width loses this share of its height), like a drop pulled long.
  final double squash;

  static const connected = LiquidSlideSpec(
    leadSeconds: .3,
    leadBounce: .25,
    trailSeconds: .48,
    trailBounce: .15,
    squash: .12,
  );

  Duration get leadDuration => _seconds(leadSeconds);
  Duration get trailDuration => _seconds(trailSeconds);

  static Duration _seconds(double s) =>
      Duration(microseconds: (s * Duration.microsecondsPerSecond).round());
}
