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
    final accent = Theme.of(context).extension<AmbleTheme>()!.colorAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WhatMattersPhase(
      amount: amount,
      enabled: enabled,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          // The ripple only announces turning the mode ON; turning it off
          // simply lets the glow fade.
          if (visible && enabled)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('what-matters-wash'),
                  painter: _WashPainter(amount, accent, isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A page's own background while What Matters can be on: it paints the
/// page [color] and, while the mode is on, a soft glow rising from the bottom
/// centre (where the toolbar button sits), with the page content on top.
/// It replaces the page's solid background container. A glow drawn under
/// that container instead would be covered by it and never seen.
class WhatMattersBackdrop extends StatelessWidget {
  const WhatMattersBackdrop({
    super.key,
    required this.color,
    required this.child,
  });

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = WhatMattersPhase.enabledOf(context);
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: enabled ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : (enabled ? WhatMattersTokens.enter : WhatMattersTokens.leave),
      child: child,
      builder: (context, amount, child) => CustomPaint(
        key: const ValueKey('what-matters-glow'),
        painter: _GlowPainter(amount, theme.colorAccent, isDark, color),
        child: child,
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

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.amount, this.accent, this.isDark, this.background);
  final double amount;
  final Color accent;
  final bool isDark;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    if (amount <= 0) return;
    final peak =
        (isDark
            ? WhatMattersTokens.glowAlphaDark
            : WhatMattersTokens.glowAlphaLight) *
        amount;
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.bottomCenter,
          radius: WhatMattersTokens.glowRadius,
          stops: const [0, WhatMattersTokens.glowMidStop, 1],
          colors: [
            accent.withValues(alpha: peak),
            accent.withValues(
              alpha: peak * WhatMattersTokens.glowMidAlphaShare,
            ),
            accent.withValues(alpha: 0),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      amount != oldDelegate.amount ||
      accent != oldDelegate.accent ||
      isDark != oldDelegate.isDark ||
      background != oldDelegate.background;
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
    // Keep the mode's color feedback transient; the page returns to its
    // ordinary surface once the ripple passes.
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
