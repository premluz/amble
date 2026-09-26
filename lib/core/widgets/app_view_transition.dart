import 'package:flutter/material.dart';

import '../tokens/motion_primitives.dart';

/// An opt-in, readiness-aware crossfade for a stable content host.
///
/// Every view owns one keyed slot for its lifetime. During an interruption,
/// the currently visible blend is sampled as weights over those live slots;
/// no second widget subtree is constructed as a fake snapshot.
class AppViewTransition extends StatefulWidget {
  const AppViewTransition({
    super.key,
    required this.viewId,
    required this.child,
    this.ready = true,
    this.duration,
  });

  final String viewId;
  final Widget child;
  final bool ready;
  final Duration? duration;

  @override
  State<AppViewTransition> createState() => _AppViewTransitionState();
}

class _ViewEntry {
  _ViewEntry(this.child);

  Widget child;
}

class _AppViewTransitionState extends State<AppViewTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _views = <String, _ViewEntry>{};
  Map<String, double> _sourceWeights = const {};
  String? _activeViewId;
  bool _waitingForLayout = false;
  bool _layoutCallbackScheduled = false;

  Duration get _duration =>
      widget.duration ??
      const Duration(milliseconds: MotionPrimitives.durationViewCrossfadeMs);

  @override
  void initState() {
    super.initState();
    _activeViewId = widget.viewId;
    _views[widget.viewId] = _ViewEntry(widget.child);
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
      _views[widget.viewId]?.child = widget.child;
      if (!oldWidget.ready && widget.ready && _waitingForLayout) {
        _scheduleLayoutReadiness();
      }
      return;
    }

    final current = _currentWeights();
    _sourceWeights = current;
    _activeViewId = widget.viewId;
    _views[widget.viewId] = _ViewEntry(widget.child);
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
    setState(() => _sourceWeights = const {});
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
        return Stack(
          fit: StackFit.passthrough,
          children: [
            for (final entry in _views.entries)
              _ViewSlot(
                key: ValueKey('view-slot-${entry.key}'),
                opacity: entry.key == _activeViewId && !_waitingForLayout
                    ? (_sourceWeights.isEmpty ? 1 : weights[entry.key] ?? 0)
                    : weights[entry.key] ?? 0,
                interactive:
                    entry.key == _activeViewId &&
                    !_waitingForLayout &&
                    (weights[entry.key] ?? (_sourceWeights.isEmpty ? 1 : 0)) >=
                        .999,
                participating:
                    entry.key == _activeViewId ||
                    weights.containsKey(entry.key),
                child: entry.value.child,
              ),
          ],
        );
      },
    );
  }
}

class _ViewSlot extends StatelessWidget {
  const _ViewSlot({
    super.key,
    required this.child,
    required this.opacity,
    required this.interactive,
    required this.participating,
  });

  final Widget child;
  final double opacity;
  final bool interactive;
  final bool participating;

  @override
  Widget build(BuildContext context) => Offstage(
    offstage: !participating,
    child: TickerMode(
      enabled: participating,
      child: IgnorePointer(
        ignoring: !interactive,
        child: ExcludeSemantics(
          excluding: !interactive,
          child: ExcludeFocus(
            excluding: !interactive,
            child: Opacity(opacity: opacity.clamp(0, 1), child: child),
          ),
        ),
      ),
    ),
  );
}
