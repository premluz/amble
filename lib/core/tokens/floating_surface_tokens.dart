import 'package:flutter/material.dart';

import 'color_primitives.dart';
import 'semantic_theme.dart';

/// Material and elevation remain independent of the surface's color role.
enum FloatingMaterial { solid, glass }

enum FloatingElevation { menu, drag }

abstract final class FloatingSurfaceTokens {
  static const fillAlpha = .92;
  static const borderWidth = 1.0;
  static const blurSigma = 12.0;
  static const borderAlphaLight = .06;
  static const borderAlphaDark = .10;
  static const topHighlightAlphaLight = .18;
  static const topHighlightAlphaDark = .16;
  static const selectedAlpha = .10;
  static const menuAlphaLight = .10;
  static const menuAlphaDark = .28;
  static const dragAlphaLight = .16;
  static const dragAlphaDark = .40;
  static const menuOffsetY = 6.0;
  static const menuBlur = 20.0;
  static const menuSpread = -4.0;
  static const dragOffsetY = 12.0;
  static const dragBlur = 32.0;
  static const dragSpread = -6.0;

  static bool _isDark(AmbleTheme theme) =>
      theme.colorTextPrimary.computeLuminance() >
      theme.colorSurfaceOverlay.computeLuminance();

  static Color border(AmbleTheme theme) => theme.colorTextPrimary.withValues(
    alpha: _isDark(theme) ? borderAlphaDark : borderAlphaLight,
  );

  static Color highlight(AmbleTheme theme) => Color.alphaBlend(
    ColorPrimitives.creamOverlay.withValues(
      alpha: _isDark(theme) ? topHighlightAlphaDark : topHighlightAlphaLight,
    ),
    border(theme),
  );

  static Color selected(AmbleTheme theme) => Color.alphaBlend(
    theme.colorAccent.withValues(alpha: selectedAlpha),
    theme.colorSurfaceOverlay,
  );

  static BoxShadow shadow(AmbleTheme theme, FloatingElevation elevation) {
    final dark = _isDark(theme);
    final drag = elevation == FloatingElevation.drag;
    final alpha = drag
        ? (dark ? dragAlphaDark : dragAlphaLight)
        : (dark ? menuAlphaDark : menuAlphaLight);
    return BoxShadow(
      color: (dark ? ColorPrimitives.ink900 : ColorPrimitives.slate900)
          .withValues(alpha: alpha),
      offset: Offset(0, drag ? dragOffsetY : menuOffsetY),
      blurRadius: drag ? dragBlur : menuBlur,
      spreadRadius: drag ? dragSpread : menuSpread,
    );
  }
}
