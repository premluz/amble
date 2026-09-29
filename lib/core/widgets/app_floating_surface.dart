import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/floating_surface_tokens.dart';
import '../tokens/semantic_theme.dart';

export '../tokens/floating_surface_tokens.dart'
    show FloatingMaterial, FloatingElevation;

/// Raised material for floating UI. Strength preserves the tree during lift.
class AppFloatingSurface extends StatelessWidget {
  const AppFloatingSurface({
    super.key,
    required this.theme,
    required this.borderRadius,
    required this.child,
    this.surfaceColor,
    this.material = FloatingMaterial.glass,
    this.elevation = FloatingElevation.menu,
    this.strength = 1,
    this.openBottom = false,
  }) : assert(strength >= 0 && strength <= 1);

  final AmbleTheme theme;
  final BorderRadius borderRadius;
  final Widget child;
  final Color? surfaceColor;
  final FloatingMaterial material;
  final FloatingElevation elevation;
  final double strength;

  /// Leaves the edge off the bottom side, for a surface that runs off the
  /// bottom of the screen (a sheet): a line there would read as a seam.
  final bool openBottom;

  BoxShadow _shadow() {
    final shadow = FloatingSurfaceTokens.shadow(theme, elevation);
    return shadow
        .scale(strength)
        .copyWith(
          color: shadow.color.withValues(alpha: shadow.color.a * strength),
        );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: strength == 0 ? const [] : [_shadow()],
      ),
      child: _material(),
    );
  }

  Widget _material() {
    final glass = material == FloatingMaterial.glass;
    final surface = surfaceColor ?? theme.colorSurfaceOverlay;
    final blur = glass ? FloatingSurfaceTokens.blurSigma * strength : 0.0;
    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: strength == 0 ? Clip.none : Clip.antiAlias,
      child: BackdropFilter(
        enabled: glass,
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: CustomPaint(
          foregroundPainter: _GlassEdge(
            theme,
            borderRadius,
            strength,
            openBottom,
          ),
          child: ColoredBox(
            color: surface.withValues(
              alpha:
                  surface.a *
                  strength *
                  (glass ? FloatingSurfaceTokens.fillAlpha : 1),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _GlassEdge extends CustomPainter {
  const _GlassEdge(this.theme, this.radius, this.strength, this.openBottom);
  final AmbleTheme theme;
  final BorderRadius radius;
  final double strength;
  final bool openBottom;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength == 0 || size.isEmpty) return;
    // An open bottom pushes that side's stroke past the clip.
    final rect =
        Offset.zero &
        (openBottom
            ? Size(size.width, size.height + FloatingSurfaceTokens.borderWidth)
            : size);
    final edge = FloatingSurfaceTokens.border(theme);
    final top = FloatingSurfaceTokens.highlight(theme);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = FloatingSurfaceTokens.borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          top.withValues(alpha: top.a * strength),
          edge.withValues(alpha: edge.a * strength),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      radius.toRRect(rect).deflate(FloatingSurfaceTokens.borderWidth / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlassEdge oldDelegate) =>
      theme != oldDelegate.theme ||
      radius != oldDelegate.radius ||
      strength != oldDelegate.strength ||
      openBottom != oldDelegate.openBottom;
}
