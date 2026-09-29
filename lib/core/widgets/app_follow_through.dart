import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../tokens/follow_through_spec.dart';

/// A sliding page's motion, for the items on it that follow through. Put
/// in place by the page transition ([AppViewTransition] with `slide`): the
/// page travels from [from] to [to] (fractions of [pageWidth]) along
/// [curve], over the first [FollowThroughSpec.pageShare] of [timeline].
class AppFollowThroughScope extends InheritedWidget {
  const AppFollowThroughScope({
    super.key,
    required this.timeline,
    required this.from,
    required this.to,
    required this.pageWidth,
    required this.curve,
    required this.generation,
    required super.child,
    this.spec = FollowThroughSpec.pages,
  });

  /// Changes with every new slide, so followers place themselves (work out
  /// their delay) once per slide rather than every frame.
  final int generation;

  final Animation<double> timeline;
  final Offset from;
  final Offset to;
  final double pageWidth;
  final Curve curve;
  final FollowThroughSpec spec;

  static AppFollowThroughScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppFollowThroughScope>();

  /// The page's own progress along its slide at timeline [t].
  double pageProgress(double t) =>
      curve.transform(Interval(0, spec.pageShare).transform(t));

  @override
  bool updateShouldNotify(AppFollowThroughScope oldWidget) =>
      timeline != oldWidget.timeline ||
      generation != oldWidget.generation ||
      from != oldWidget.from ||
      to != oldWidget.to ||
      pageWidth != oldWidget.pageWidth ||
      curve != oldWidget.curve ||
      spec != oldWidget.spec;
}

/// Marks a key item on a page (a task, a tracked card, a card's dot): while
/// the page slides, it trails behind and catches up, so the content feels
/// like it follows through. Rows higher up go first, and across the page
/// the edge leading the travel goes first; it works the same entering or
/// leaving, whichever way the page goes. Nested inside another follower
/// (a dot in a card), it trails that follower instead of the page. Paint
/// only: layout and hit testing never move. Inert outside a sliding page.
class AppFollowThrough extends SingleChildRenderObjectWidget {
  const AppFollowThrough({super.key, super.child});

  @override
  RenderFollowThrough createRenderObject(BuildContext context) =>
      RenderFollowThrough(
        AppFollowThroughScope.maybeOf(context),
        MediaQuery.sizeOf(context).height,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFollowThrough renderObject,
  ) {
    renderObject
      ..scope = AppFollowThroughScope.maybeOf(context)
      ..screenHeight = MediaQuery.sizeOf(context).height;
  }
}

/// The render object behind [AppFollowThrough].
class RenderFollowThrough extends RenderProxyBox {
  RenderFollowThrough(this._scope, this._screenHeight);

  AppFollowThroughScope? _scope;
  double _screenHeight;

  /// This slide's delay and this frame's progress, read by nested followers.
  double _delay = 0;
  double _progress = 1;

  /// The lag last painted, in pixels (tests read it; paint is otherwise
  /// unobservable from a widget test).
  @visibleForTesting
  double get debugLag => _lastLag;
  double _lastLag = 0;

  set scope(AppFollowThroughScope? value) {
    if (identical(value?.timeline, _scope?.timeline) &&
        value?.from == _scope?.from &&
        value?.to == _scope?.to) {
      _scope = value;
      return;
    }
    if (attached) _scope?.timeline.removeListener(markNeedsPaint);
    _scope = value;
    if (attached) _scope?.timeline.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  set screenHeight(double value) {
    if (value == _screenHeight) return;
    _screenHeight = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scope?.timeline.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _scope?.timeline.removeListener(markNeedsPaint);
    super.detach();
  }

  /// The slide this follower last placed itself for, and what it found:
  /// its delay (in [_delay]) and the follower it trails, if nested.
  int? _placedFor;
  RenderFollowThrough? _leaderFound;

  /// How many times any follower has placed itself (tests read it: once per
  /// follower per slide, never per frame).
  @visibleForTesting
  static int debugPlacements = 0;

  /// Horizontal lag in pixels behind whatever this follows (0 at rest).
  double _lag(AppFollowThroughScope scope) {
    final t = scope.timeline.value.clamp(0.0, 1.0);
    final travel = scope.to.dx - scope.from.dx;
    final spec = scope.spec;
    final page = scope.pageProgress(t);
    final width = scope.pageWidth;
    if (t >= 1 || travel == 0 || width <= 0 || !hasSize) {
      _progress = 1;
      return 0;
    }
    // Where it sits (and so its delay) is worked out once per slide: the
    // screen-position lookups are the costly part, and a dense grid of dots
    // would otherwise repeat them every frame.
    if (_placedFor != scope.generation) {
      _place(scope, travel, page);
      _placedFor = scope.generation;
    }
    final end = (_delay + spec.pageShare).clamp(0.0, 1.0);
    _progress = scope.curve.transform(Interval(_delay, end).transform(t));
    final leader = _leaderFound;
    final ahead = leader != null && leader.attached ? leader._progress : page;
    return (_progress - ahead) * travel * width;
  }

  void _place(AppFollowThroughScope scope, double travel, double page) {
    debugPlacements++;
    final spec = scope.spec;
    final width = scope.pageWidth;
    RenderFollowThrough? leader;
    for (var node = parent; node != null; node = node.parent) {
      if (node is RenderFollowThrough) {
        leader = node;
        break;
      }
    }
    _leaderFound = leader;
    final centre = localToGlobal(size.center(Offset.zero));
    // The edge the page travels toward leads; the far side trails.
    double lead(double x, double span) {
      final share = (x / span).clamp(0.0, 1.0);
      return travel < 0 ? share : 1 - share;
    }

    // A leader paints (and so places itself) before its followers.
    if (leader != null && leader.hasSize) {
      final origin = leader.localToGlobal(Offset.zero).dx;
      _delay =
          leader._delay +
          spec.tail *
              spec.nestedShare *
              lead(centre.dx - origin, leader.size.width);
      return;
    }
    final pageLeft = width * Offset.lerp(scope.from, scope.to, page)!.dx;
    final row = _screenHeight <= 0
        ? 0.0
        : (centre.dy / _screenHeight).clamp(0.0, 1.0);
    _delay =
        spec.tail *
        (1 - spec.nestedShare) *
        (spec.rowWeight * row +
            (1 - spec.rowWeight) * lead(centre.dx - pageLeft, width));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final scope = _scope;
    final lag = scope == null ? 0.0 : _lag(scope);
    _lastLag = lag;
    if (lag == 0) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.translationValues(lag, 0, 0),
      super.paint,
      oldLayer: switch (layer) {
        final TransformLayer previous => previous,
        _ => null,
      },
    );
  }
}
