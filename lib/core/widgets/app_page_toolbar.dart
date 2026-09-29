import 'dart:async';

import 'package:flutter/widgets.dart';

import '../tokens/depth_motion_spec.dart';
import '../tokens/motion_primitives.dart';
import 'app_follow_through.dart';
import 'app_spring_presence.dart';

/// Holds a page's toolbar still while the page slides, like the Day dock
/// (which lives outside the pages): the toolbar doesn't travel with its
/// page, it submerges and emerges in place ([AppPageToolbarGate]). Inert
/// outside a sliding page.
class AppPageToolbarAnchor extends StatelessWidget {
  const AppPageToolbarAnchor({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = AppFollowThroughScope.maybeOf(context);
    if (scope == null) return child;
    return AnimatedBuilder(
      animation: scope.timeline,
      child: child,
      builder: (context, child) {
        final page = scope.pageProgress(scope.timeline.value.clamp(0.0, 1.0));
        final slid = Offset.lerp(scope.from, scope.to, page)!.dx;
        return Transform.translate(
          offset: Offset(-slid * scope.pageWidth, 0),
          child: child,
        );
      },
    );
  }
}

/// Whether a page's toolbar is showing: off the moment its page starts to
/// leave (so it submerges while the page goes), and on shortly after its
/// page arrives ([revealDelay]), once the previous page's toolbar has gone
/// — out, then in. A toolbar already there when the app starts is simply
/// there. Always on outside a sliding page.
class AppPageToolbarGate extends StatefulWidget {
  const AppPageToolbarGate({super.key, required this.builder, this.order = 0});

  final Widget Function(BuildContext context, bool showing) builder;

  /// Position among the page's toolbar buttons, left to right: each later
  /// one submerges and emerges one dock stagger step after the one before,
  /// like the Day dock's own buttons.
  final int order;

  /// The step between neighbouring toolbar buttons.
  static const stagger = Duration(
    milliseconds: MotionPrimitives.durationContextDockStaggerMs,
  );

  /// How long an arriving page's toolbar waits for the leaving one.
  static const revealDelay = Duration(
    milliseconds: MotionPrimitives.durationContextDockMs,
  );

  @override
  State<AppPageToolbarGate> createState() => _AppPageToolbarGateState();
}

class _AppPageToolbarGateState extends State<AppPageToolbarGate> {
  bool? _active;
  var _showing = false;
  Timer? _reveal;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppFollowThroughScope.maybeOf(context);
    final active = scope == null || scope.to == Offset.zero;
    if (active == _active) return;
    final first = _active == null;
    _active = active;
    _reveal?.cancel();
    final step = AppPageToolbarGate.stagger * widget.order;
    if (!active) {
      if (step == Duration.zero || first) {
        _showing = false;
        return;
      }
      _reveal = Timer(step, () {
        if (mounted && _active == false) setState(() => _showing = false);
      });
      return;
    }
    final settled = scope == null || scope.timeline.isCompleted;
    final still = MediaQuery.maybeOf(context)?.disableAnimations == true;
    if ((first && settled) || still) {
      _showing = true;
      return;
    }
    _showing = false;
    _reveal = Timer(AppPageToolbarGate.revealDelay + step, () {
      if (mounted && _active == true) setState(() => _showing = true);
    });
  }

  @override
  void dispose() {
    _reveal?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _showing);
}

/// A single toolbar button on a page (the "+", the Inbox mic): held in
/// place while its page slides, it submerges as the page leaves (swells,
/// then shrinks away) and springs back in (larger, smaller, actual) as the
/// page arrives — the same motion as the Day dock's buttons. [visible]
/// false hides it for the page's own reasons too (e.g. under voice mode).
class AppPageToolbarItem extends StatelessWidget {
  const AppPageToolbarItem({
    super.key,
    required this.child,
    this.visible = true,
    this.order = 0,
  });

  final Widget child;
  final bool visible;

  /// See [AppPageToolbarGate.order].
  final int order;

  @override
  Widget build(BuildContext context) => AppPageToolbarAnchor(
    child: AppPageToolbarGate(
      order: order,
      builder: (context, showing) => AppSpringPresence(
        visible: visible && showing,
        duration: DepthMotionSpec.standard.exitDuration,
        swell: DepthMotionSpec.standard.submergeSwell,
        child: child,
      ),
    ),
  );
}
