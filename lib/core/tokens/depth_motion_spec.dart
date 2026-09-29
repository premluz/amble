/// Component motion tokens for depth: objects emerge from the depth of the
/// screen when created and recede into it when removed (BRAND.md §18's
/// "emerge / release / settle"). The object's space opens and stays still;
/// its SHAPE (a pill, a badge) springs up from small and transparent —
/// larger, smaller, then actual — while its TEXT only fades in. No blur, no
/// sideways movement. Times are seconds; phases are fractions of the whole.
class DepthMotionSpec {
  const DepthMotionSpec({
    required this.enterSeconds,
    required this.exitSeconds,
    required this.sizeEnd,
    required this.depthStart,
    required this.staggerSeconds,
    required this.fromScale,
    required this.shapeFromScale,
    required this.shapeSpringSeconds,
    required this.shapeBounce,
    required this.shapeFadeShare,
    required this.textFadeStart,
    this.submergeSwell = .15,
  }) : assert(enterSeconds > 0 && exitSeconds > 0),
       assert(sizeEnd > 0 && sizeEnd <= 1),
       assert(depthStart >= 0 && depthStart < 1),
       assert(staggerSeconds >= 0),
       assert(fromScale > 0 && fromScale <= 1),
       assert(shapeFromScale >= 0 && shapeFromScale < 1),
       assert(shapeSpringSeconds > 0),
       assert(shapeBounce >= 0 && shapeBounce < 1),
       assert(shapeFadeShare > 0 && shapeFadeShare <= 1),
       assert(textFadeStart >= 0 && textFadeStart < 1);

  final double enterSeconds;
  final double exitSeconds;

  /// The object's own height opens over `0..sizeEnd` of the transition, so
  /// neighbours make room before it has fully arrived.
  final double sizeEnd;

  /// The emergence itself runs over `depthStart..1`. Played in reverse on
  /// exit: it recedes first, then its space closes.
  final double depthStart;

  /// Gap between consecutive arrivals when several objects emerge at once.
  final double staggerSeconds;

  /// Scale a whole object recedes to ([AppDepthTransition], e.g. controls).
  final double fromScale;

  /// A shape starts this small, then springs to its real size.
  final double shapeFromScale;

  /// The shape's spring (SwiftUI duration/bounce model): with this bounce it
  /// overshoots, dips just under, then settles — larger, smaller, actual.
  final double shapeSpringSeconds;
  final double shapeBounce;

  /// The shape is fully opaque by this share of the emergence.
  final double shapeFadeShare;

  /// Text starts fading in at this share of the emergence.
  final double textFadeStart;

  /// A control that submerges (swells, then shrinks away) grows by this
  /// share of its size first.
  final double submergeSwell;

  static const standard = DepthMotionSpec(
    enterSeconds: .8,
    exitSeconds: .34,
    sizeEnd: .45,
    depthStart: .15,
    staggerSeconds: .1,
    fromScale: .92,
    shapeFromScale: .3,
    shapeSpringSeconds: .5,
    shapeBounce: .45,
    shapeFadeShare: .3,
    textFadeStart: .25,
  );

  Duration get enterDuration => Duration(
    microseconds: (enterSeconds * Duration.microsecondsPerSecond).round(),
  );

  Duration staggerFor(int index) => Duration(
    microseconds: (index * staggerSeconds * Duration.microsecondsPerSecond)
        .round(),
  );

  Duration get exitDuration => Duration(
    microseconds: (exitSeconds * Duration.microsecondsPerSecond).round(),
  );
}
