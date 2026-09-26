import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import '../tokens/what_matters_tokens.dart';

export 'what_matters_item.dart';

/// Provides a common phase for lane packing and a quiet accent wash.
class WhatMattersScene extends StatelessWidget {
  const WhatMattersScene({
    super.key,
    required this.enabled,
    required this.child,
    this.visible = true,
  });
  final bool enabled;
  final Widget child;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    // Day owns the header and content together; embedded timelines reuse it.
    if (context.dependOnInheritedWidgetOfExactType<WhatMattersPhase>() !=
        null) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: enabled ? 1 : 0, end: enabled ? 1 : 0),
      duration: enabled ? WhatMattersTokens.enter : WhatMattersTokens.leave,
      child: child,
      builder: (context, value, child) => _compose(context, value, child!),
    );
  }

  Widget _compose(BuildContext context, double value, Widget child) {
    final amount = MediaQuery.disableAnimationsOf(context)
        ? (enabled ? 1.0 : 0.0)
        : value;
    return WhatMattersPhase(
      amount: amount,
      enabled: enabled,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          if (visible)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('what-matters-wash'),
                  painter: _WashPainter(
                    amount,
                    Theme.of(context).extension<AmbleTheme>()!.colorAccent,
                    Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WhatMattersPhase extends InheritedWidget {
  const WhatMattersPhase({
    super.key,
    required this.amount,
    required this.enabled,
    required super.child,
  });
  final double amount;
  final bool enabled;
  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WhatMattersPhase>()?.enabled ??
      false;
  bool get compactLanes => amount >= WhatMattersTokens.laneSettleStart;
  static bool compactLanesOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WhatMattersPhase>()
          ?.compactLanes ??
      false;
  @override
  bool updateShouldNotify(WhatMattersPhase oldWidget) =>
      compactLanes != oldWidget.compactLanes || enabled != oldWidget.enabled;
}

class _WashPainter extends CustomPainter {
  _WashPainter(this.amount, this.accent, this.isDark);
  final double amount;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..color = accent.withValues(
          alpha:
              (isDark
                  ? WhatMattersTokens.tintAlphaDark
                  : WhatMattersTokens.tintAlphaLight) *
              amount,
        ),
    );
    final wash = _rippleBounds(bounds, size);
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(
      wash,
      Paint()..shader = _rippleGradient().createShader(wash),
    );
    canvas.restore();
  }

  Rect _rippleBounds(Rect bounds, Size size) {
    final reach = math.sqrt(
      size.height * size.height + size.width * size.width / 4,
    );
    final radius = reach * amount;
    final width = reach * WhatMattersTokens.rippleWidth;
    return Rect.fromCircle(center: bounds.bottomCenter, radius: radius + width);
  }

  RadialGradient _rippleGradient() {
    final radius = amount;
    const width = WhatMattersTokens.rippleWidth;
    return RadialGradient(
      stops: [
        0,
        math.max(0, (radius - width) / (radius + width)),
        radius / (radius + width),
        1,
      ],
      colors: [
        accent.withValues(alpha: 0),
        accent.withValues(alpha: 0),
        accent.withValues(
          alpha:
              (isDark
                  ? WhatMattersTokens.washAlphaDark
                  : WhatMattersTokens.washAlphaLight) *
              math.sin(math.pi * amount),
        ),
        accent.withValues(alpha: 0),
      ],
    );
  }

  @override
  bool shouldRepaint(_WashPainter oldDelegate) =>
      amount != oldDelegate.amount ||
      accent != oldDelegate.accent ||
      isDark != oldDelegate.isDark;
}
