import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import '../tokens/what_matters_tokens.dart';

double _phase(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0);

/// Keeps the child mounted and preserves its current pose on rapid reversal.
class WhatMattersMotion extends StatefulWidget {
  const WhatMattersMotion({
    super.key,
    required this.hidden,
    required this.child,
    this.collapse = false,
    this.move = true,
  });
  final bool hidden;
  final bool collapse;
  final bool move;
  final Widget child;
  @override
  State<WhatMattersMotion> createState() => _MotionState();
}

class _MotionState extends State<WhatMattersMotion>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<WhatMattersMotion> {
  late final AnimationController _clock;
  late bool _hidden;
  late ({double release, double closing}) _from;

  @override
  bool get wantKeepAlive => widget.collapse;

  @override
  void initState() {
    super.initState();
    _hidden = widget.hidden;
    final value = _hidden ? 1.0 : 0.0;
    _from = (release: value, closing: value);
    _clock = AnimationController(vsync: this, value: 1);
  }

  @override
  void didUpdateWidget(WhatMattersMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collapse != widget.collapse) updateKeepAlive();
    if (oldWidget.hidden == widget.hidden) return;
    _from = _sample();
    _hidden = widget.hidden;
    _clock.duration = _hidden
        ? WhatMattersTokens.enter
        : WhatMattersTokens.leave;
    _clock.forward(from: 0);
  }

  ({double release, double closing}) _sample() {
    final target = _hidden ? 1.0 : 0.0;
    final release = _phase(
      _clock.value,
      _hidden ? WhatMattersTokens.releaseStart : WhatMattersTokens.returnStart,
      _hidden
          ? WhatMattersTokens.releaseEnd
          : WhatMattersTokens.returnRevealEnd,
    );
    final closing = Curves.easeInOutCubic.transform(
      _phase(
        _clock.value,
        _hidden
            ? WhatMattersTokens.collapseStart
            : WhatMattersTokens.returnStart,
        _hidden ? WhatMattersTokens.collapseEnd : 1,
      ),
    );
    return (
      release: _from.release + (target - _from.release) * release,
      closing: _from.closing + (target - _from.closing) * closing,
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (context, child) {
        final target = _hidden ? 1.0 : 0.0;
        final pose = MediaQuery.disableAnimationsOf(context)
            ? (release: target, closing: target)
            : _sample();
        return _render(context, pose.release, pose.closing, child!);
      },
    );
  }

  Widget _render(
    BuildContext context,
    double release,
    double closing,
    Widget child,
  ) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return IgnorePointer(
      ignoring: _hidden || release > 0,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: widget.collapse ? 1 - closing : 1,
        child: Opacity(
          opacity: 1 - (widget.move ? release : closing),
          child: Transform.translate(
            offset: Offset(
              0,
              widget.move ? theme.spacingXl * release * release : 0,
            ),
            child: Transform.scale(
              scale:
                  1 - (widget.move ? WhatMattersTokens.scaleLoss * release : 0),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
