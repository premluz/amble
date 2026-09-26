import 'package:flutter/material.dart';

import '../tokens/motion_primitives.dart';
import '../tokens/semantic_theme.dart';
import 'app_view_transition_motion.dart';
import 'app_view_transition_slot.dart';

/// Opt-in, readiness-aware transitions retain keyed live slots and sample
/// their current positions on interruption instead of building snapshots.
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

  Duration get _duration =>
      widget.duration ??
      Duration(
        milliseconds: widget.slide
            ? MotionPrimitives.durationFastMs
            : MotionPrimitives.durationViewCrossfadeMs,
      );

  double get _motionProgress =>
      Theme.of(context)
          .extension<AmbleTheme>()!
          .curveDecelerate
          .transform(_controller.value);

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final weights = _currentWeights();
        final motionProgress = _motionProgress;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            for (final entry in _views.entries)
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
                child: entry.value,
              ),
          ],
        );
      },
    );
  }
}
