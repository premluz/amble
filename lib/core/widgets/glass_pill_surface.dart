import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tokens/semantic_theme.dart';

/// A filled pill-shaped surface, in one of two materials — the shared
/// treatment for Timeline blocks that are NOT real, saved tasks.
///
/// Requested directly: "this ghost phantom state should have fill gray
/// semitransparent with bg blur glassy thing / make this style reusable
/// token / the imported should have fill also but just gray not the same
/// glassy / and no dotted line, no line at all."
///
/// Two materials, one widget, because the two cases differ ONLY in
/// material and are otherwise the same box (same shape token, same size
/// contract, same place in the layout):
///
/// - [GlassPillMaterial.glass] — translucent fill over a real
///   `BackdropFilter`, for the quick-create draft placeholder
///   (`PendingTaskPill`). It is airborne: provisional, not yet saved, and
///   sitting over whatever is underneath it.
/// - [GlassPillMaterial.flat] — a plain, opaque-enough gray with NO blur,
///   for an imported calendar event's rail. It is a real thing on the
///   calendar, just not an Amble task, so it reads as solid rather than
///   floating.
///
/// Neither material draws a border. The imported rail previously carried a
/// dashed outline; that was removed here per the same instruction ("no
/// dotted line, no line at all").
///
/// Reuses [AmbleTheme.colorSurfaceBlurOverlay] and
/// [AmbleTheme.blurOverlaySigma] rather than introducing new tokens — the
/// same pair the lifted/dragged task card already frosts with, so every
/// frosted surface in the app uses one material and blurs by one amount.
/// The corner always tracks [AmbleTheme.radiusPill], the active rung of
/// the "Pill shape" setting, so these blocks respond to it exactly like a
/// real task's rail and every other card.
enum GlassPillMaterial {
  /// Translucent + blurred. For content that floats over other content.
  glass,

  /// Flat gray, no blur. For content that sits in the timeline normally.
  flat,
}

class GlassPillSurface extends StatelessWidget {
  const GlassPillSurface({
    super.key,
    required this.theme,
    required this.width,
    required this.height,
    this.material = GlassPillMaterial.glass,
    this.child,
  });

  final AmbleTheme theme;
  final double width;
  final double height;
  final GlassPillMaterial material;

  /// Optional content laid over the fill — e.g. an imported event's
  /// calendar glyph. The draft placeholder passes none: it has no category
  /// until the user picks one, so any glyph would be inventing one.
  final Widget? child;

  /// The flat material's own fill: [AmbleTheme.colorTextSecondary] at low
  /// alpha. Derived from the muted text color rather than a surface token
  /// deliberately — the intent is "a gray stand-in where a category color
  /// would go," which is what the rail it replaces was already doing, and
  /// it stays legible against both themes' backgrounds without needing a
  /// per-theme pair of its own.
  static const double _flatFillAlpha = 0.22;

  /// The glass material's own tint alpha. Deliberately NOT
  /// [AmbleTheme.colorSurfaceBlurOverlay] itself: that token is
  /// `surface1`-derived and measured WHITE in both themes (light
  /// `#FFFFFF` @36%, dark `#121110` @36% — near-black), which made the
  /// phantom read identically light on dark mode. Requested directly:
  /// "this glass phantom should be lighter on dark mode and darker on
  /// light mode." So the tint is resolved from the theme's own text color
  /// instead, which genuinely flips: dark ink on a light theme, pale sand
  /// on a dark one.
  static const double _glassTintAlpha = 0.22;

  /// The glass tint for [theme] — see [_glassTintAlpha] for why this is
  /// derived rather than read straight off `colorSurfaceBlurOverlay`.
  /// Public so a caller compositing its own layers (and any test pinning
  /// the theme-flip behaviour) resolves the identical color.
  static Color glassTint(AmbleTheme theme) =>
      theme.colorTextPrimary.withValues(alpha: _glassTintAlpha);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(theme.radiusPill);
    final box = SizedBox(width: width, height: height, child: child);

    if (material == GlassPillMaterial.flat) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorTextSecondary.withValues(alpha: _flatFillAlpha),
          borderRadius: radius,
        ),
        child: box,
      );
    }

    // Glass: the fill alone, with nothing blurred behind it, reads as a
    // dim rather than glass — see `colorSurfaceBlurOverlay`'s own doc
    // comment. `ClipRRect` is what keeps the blur inside the pill's own
    // rounded shape instead of bleeding past its corners.
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: theme.blurOverlaySigma,
          sigmaY: theme.blurOverlaySigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: glassTint(theme),
            borderRadius: radius,
          ),
          child: box,
        ),
      ),
    );
  }
}
