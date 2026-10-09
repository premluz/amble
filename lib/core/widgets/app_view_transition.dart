import 'package:flutter/material.dart';

import '../tokens/motion_primitives.dart';
import '../tokens/semantic_theme.dart';
import '../tokens/follow_through_spec.dart';
import 'app_context_menu.dart';
import 'app_follow_through.dart';
import 'app_view_transition_motion.dart';
import 'app_view_transition_slot.dart';
import 'app_staggered_fill.dart' show AppViewArrival;

/// Readiness-aware transitions sample live slot positions on interruption.
class AppViewTransition extends StatefulWidget {
  const AppViewTransition({
    super.key,
    required this.viewId,
    required this.child,
    this.ready = true,
    this.duration,
    this.slide = false,
    this.forward = true,
  });

  final String viewId;
  final Widget child;
  final bool ready;
  final Duration? duration;
  final bool slide;
  final bool forward;

  @override
  State<AppViewTransition> createState() => _AppViewTransitionState();
}

class _AppViewTransitionState extends State<AppViewTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _views = <String, Widget>{};
  Map<String, double> _sourceWeights = const {};
  Map<String, Offset> _sourceTranslations = const {};
  String? _activeViewId;
  bool _waitingForLayout = false;
  bool _layoutCallbackScheduled = false;

  /// Bumped on every view change, so followers place themselves once per
  /// slide ([AppFollowThroughScope.generation]).
  int _generation = 0;

  Duration get _duration =>
      widget.duration ??
      (widget.slide
          // The page slides over the first part; its items follow through.
          ? FollowThroughSpec.pages.duration
          : const Duration(
              milliseconds: MotionPrimitives.durationViewCrossfadeMs,
            ));

  double get _motionProgress {
    final t = _controller.value;
    return Theme.of(context).extension<AmbleTheme>()!.curveDecelerate.transform(
      widget.slide
          ? const Interval(0, FollowThroughSpec.pagesPageShare).transform(t)
          : t,
    );
  }

  @override
  void initState() {
    super.initState();
    _activeViewId = widget.viewId;
    _views[widget.viewId] = widget.child;
    _waitingForLayout = !widget.ready;
    _controller = AnimationController(
      vsync: this,
      duration: _duration,
      value: widget.ready ? 1 : 0,
    );
    if (_waitingForLayout) _scheduleLayoutReadiness();
  }

  @override
  void didUpdateWidget(AppViewTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = _duration;
    if (oldWidget.viewId == widget.viewId) {
      _views[widget.viewId] = widget.child;
      if (!oldWidget.ready && widget.ready && _waitingForLayout) {
        _scheduleLayoutReadiness();
      }
      return;
    }
    AppContextMenu.dismissOpenMenusAfterFrame();
    _generation++;
    final current = _currentWeights();
    _sourceTranslations = AppViewTransitionMotion.sample(
      slide: oldWidget.slide,
      forward: oldWidget.forward,
      progress: _motionProgress,
      sourceWeights: _sourceWeights,
      sourceTranslations: _sourceTranslations,
      activeViewId: _activeViewId,
    );
    _sourceWeights = current;
    _activeViewId = widget.viewId;
    _views[widget.viewId] = widget.child;
    _waitingForLayout = !widget.ready;
    _controller.value = 0;
    if (!_waitingForLayout) _scheduleLayoutReadiness();
  }

  Map<String, double> _currentWeights() {
    if (_sourceWeights.isEmpty) {
      final id = _activeViewId;
      if (id != null && !_waitingForLayout) {
        return {id: 1};
      }
      return const {};
    }
    final progress = _controller.value;
    final weights = <String, double>{};
    for (final entry in _sourceWeights.entries) {
      final weight = entry.value * (1 - progress);
      if (weight > 0) weights[entry.key] = weight;
    }
    final id = _activeViewId;
    if (id != null && !_waitingForLayout && progress > 0) {
      weights[id] = progress;
    }
    return weights;
  }

  void _scheduleLayoutReadiness() {
    if (_layoutCallbackScheduled) return;
    _layoutCallbackScheduled = true;
    final expectedViewId = widget.viewId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutCallbackScheduled = false;
      if (!mounted || _activeViewId != expectedViewId) return;
      if (!widget.ready) {
        _waitingForLayout = true;
        return;
      }
      _waitingForLayout = false;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
        _finish();
      } else {
        _controller.forward().whenCompleteOrCancel(_finish);
      }
    });
  }

  void _finish() {
    if (!mounted || _controller.value < 1) return;
    setState(() {
      _sourceWeights = const {};
      _sourceTranslations = const {};
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingForLayout) _scheduleLayoutReadiness();
    return LayoutBuilder(
      builder: (context, box) => _slots(box.hasBoundedWidth ? box.maxWidth : 0),
    );
  }

  Widget _followed(MapEntry<String, Widget> entry, double width) {
    final (from, to) = AppViewTransitionMotion.endpoints(
      id: entry.key,
      activeViewId: _activeViewId,
      forward: widget.forward,
      sourceTranslations: _sourceTranslations,
    );
    return AppFollowThroughScope(
      timeline: _controller,
      from: from,
      to: to,
      pageWidth: width,
      curve: Theme.of(context).extension<AmbleTheme>()!.curveDecelerate,
      generation: _generation,
      child: entry.value,
    );
  }

  Widget _slots(double width) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final weights = _currentWeights();
        final motionProgress = _motionProgress;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            // The arriving page paints underneath and the page being left
            // on top, so the leaving page's items, trailing back toward the
            // arriving side, stay visible whichever way the pages travel.
            // Keyed slots keep their state when reordered.
            for (final entry in [
              ..._views.entries.where((e) => e.key == _activeViewId),
              ..._views.entries.where((e) => e.key != _activeViewId),
            ])
              AppViewTransitionSlot(
                key: ValueKey('view-slot-${entry.key}'),
                opacity: entry.key == _activeViewId && !_waitingForLayout
                    ? (widget.slide
                          ? 1
                          : (_sourceWeights.isEmpty
                                ? 1
                                : weights[entry.key] ?? 0))
                    : (widget.slide ? 1 : weights[entry.key] ?? 0),
                translation: widget.slide
                    ? AppViewTransitionMotion.translation(
                        id: entry.key,
                        activeViewId: _activeViewId,
                        forward: widget.forward,
                        progress: motionProgress,
                        sourceTranslations: _sourceTranslations,
                      )
                    : Offset.zero,
                interactive:
                    entry.key == _activeViewId &&
                    !_waitingForLayout &&
                    (weights[entry.key] ?? (_sourceWeights.isEmpty ? 1 : 0)) >=
                        .999,
                participating:
                    entry.key == _activeViewId ||
                    weights.containsKey(entry.key),
                // Tells the page it just arrived (slide or fade), for
                // entrance details such as Patterns' fill-in.
                child: AppViewArrival(
                  arrival: entry.key == _activeViewId ? _generation : -1,
                  child: widget.slide ? _followed(entry, width) : entry.value,
                ),
              ),
          ],
        );
      },
    );
  }
}
