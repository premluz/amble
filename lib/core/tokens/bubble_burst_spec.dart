/// Component motion tokens adapted from rios-motion 15's settling bubbles.
/// Times are seconds; travel/spread/radius scale with the source pill width.
class BubbleBurstSpec {
  const BubbleBurstSpec({
    this.bubbleEmission = .25,
    this.bubbleRate = 8,
    this.bubbleStagger = .035,
    this.bubbleLinger = .8,
    this.bubbleRandomness = .8,
    this.bubbleTravel = 1.8,
    this.bubbleSpread = .7,
    this.frontDots = .7,
  }) : assert(bubbleEmission >= 0),
       assert(bubbleRate > 0),
       assert(bubbleStagger >= 0),
       assert(bubbleLinger > 0),
       assert(bubbleRandomness >= 0 && bubbleRandomness <= 1),
       assert(bubbleTravel >= 0),
       assert(bubbleSpread >= 0),
       assert(frontDots >= 0 && frontDots <= 1);

  final double bubbleEmission;
  final double bubbleRate;
  final double bubbleStagger;
  final double bubbleLinger;
  final double bubbleRandomness;
  final double bubbleTravel;
  final double bubbleSpread;
  final double frontDots;

  static const lanes = 3;
  static const radiusFraction = .07;
  static const birthJitter = .65;
  static const lifetimeVariation = .3;
  static const fadeInFraction = .1;
  static const headingSpread = .65;
  static const travelBase = .7;
  static const travelVariation = .6;
  static const radiusBase = .65;
  static const radiusVariation = .5;
  static const radiusDecay = .8;
  static const seedX = 127.1;
  static const seedLane = 311.7;
  static const seedScale = 43758.5453;

  int get countPerLane => (bubbleEmission * bubbleRate).ceil();
  double get seconds =>
      (lanes - 1) * bubbleStagger +
      bubbleEmission +
      birthJitter / bubbleRate +
      bubbleLinger;
  Duration get duration =>
      Duration(microseconds: (seconds * Duration.microsecondsPerSecond).ceil());
}
