/// Component motion tokens for the liquid morph: a droplet at an origin
/// point spreads into the target shape. Width and height ride separate
/// springs so the shape widens a beat before it stretches, which is what
/// reads as liquid rather than a scale-up. Times are seconds; bounce follows
/// `SpringDescription.withDurationAndBounce`.
class LiquidMorphSpec {
  const LiquidMorphSpec({
    this.dropletDiameter,
    required this.widthSeconds,
    required this.widthBounce,
    required this.heightSeconds,
    required this.heightBounce,
    required this.contentScaleFrom,
    this.fadeInFraction = .25,
    this.popFrom = 1,
    this.popSeconds = .5,
    this.popBounce = 0,
  }) : assert(dropletDiameter == null || dropletDiameter > 0),
       assert(widthSeconds > 0 && heightSeconds > 0),
       assert(widthBounce >= 0 && widthBounce < 1),
       assert(heightBounce >= 0 && heightBounce < 1),
       assert(contentScaleFrom > 0 && contentScaleFrom <= 1),
       assert(fadeInFraction > 0 && fadeInFraction <= 1);

  /// Size of the droplet the shape grows out of, in logical pixels. Null
  /// means the child's own shortest side: the dot a pill is stretched from.
  final double? dropletDiameter;
  final double widthSeconds;
  final double widthBounce;
  final double heightSeconds;
  final double heightBounce;

  /// The content grows with the shape from this scale, so it is revealed
  /// and expanded at once rather than uncovered like a mask.
  final double contentScaleFrom;

  /// Share of the horizontal spring over which opacity reaches full.
  final double fadeInFraction;

  /// A whole-shape size spring on arrival, on top of the stretch: from
  /// [popFrom] of its size it springs larger, smaller, then actual. 1 = none.
  final double popFrom;
  final double popSeconds;
  final double popBounce;

  /// Popovers and context menus emerging from a touch point. After Liquid
  /// Glass: the panel pops a touch oversized (about 4–5%) and settles back,
  /// fast enough that the menu is usable almost at once.
  static const popover = LiquidMorphSpec(
    dropletDiameter: 28,
    widthSeconds: .25,
    widthBounce: .4,
    heightSeconds: .32,
    heightBounce: .45,
    contentScaleFrom: .6,
  );

  /// A draft task: the dot at the top of the rail stretches down into the
  /// full-length pill, the brand's dot-to-line grammar. The stretch is the
  /// event, so height gets the longer, bouncier spring.
  static const draftPill = LiquidMorphSpec(
    widthSeconds: .3,
    widthBounce: .2,
    heightSeconds: .55,
    heightBounce: .32,
    contentScaleFrom: .85,
    fadeInFraction: .15,
  );

  /// A toolbar pane stretching from one button into a wider toolbar (the
  /// Inbox mic into voice mode's controls): a quick, firm stretch, while the
  /// pane as a whole springs larger, smaller, then actual. Here [fadeInFraction] is the cross-fade
  /// window: the old content leaves over the first share of the stretch,
  /// the new content arrives over the next.
  static const dockPane = LiquidMorphSpec(
    widthSeconds: .38,
    widthBounce: .12,
    heightSeconds: .3,
    heightBounce: .08,
    contentScaleFrom: .9,
    fadeInFraction: .3,
    popFrom: .75,
    popSeconds: .55,
    popBounce: .6,
  );

  Duration get widthDuration => Duration(
    microseconds: (widthSeconds * Duration.microsecondsPerSecond).round(),
  );

  Duration get heightDuration => Duration(
    microseconds: (heightSeconds * Duration.microsecondsPerSecond).round(),
  );
}
