import 'package:flutter/material.dart';

import 'color_primitives.dart';
import 'semantic_theme.dart';

/// Colours for the task state grammar (BRAND.md §17): normal, important,
/// done, and the reserved "no label yet" neutral. Derived from each theme's
/// own text/surface/accent colours, so light and dark each get values that
/// read correctly rather than one grey that is too dark in light mode and
/// too bright in dark mode.
abstract final class TaskStateTokens {
  /// Share of the page colour mixed into a done task's label colour: the
  /// pill recedes to a pale tint of its own label, never a flat grey that
  /// could be mistaken for an unlabeled task.
  static const doneFillMix = .72;

  /// Opacity of a done task's title text.
  static const doneTitleAlpha = .42;

  /// Category glyphs on a pill: warm paper on a dark fill, charcoal on a
  /// light one — never pure white or black.
  static final glyphOnDark = ColorPrimitives.paper;
  static final glyphOnLight = ColorPrimitives.slate900;

  /// Opacity of a done task's glyph: barely there, so the icon recedes well
  /// past its pill's own pale tint.
  static const doneGlyphAlpha = .25;

  /// Opacity of a done task's important star: it recedes with the title
  /// rather than staying at full strength on a finished task.
  static const doneStarAlpha = doneTitleAlpha;

  /// The strike line is the title's own colour, slightly thicker than a
  /// hairline so it reads as a deliberate mark.
  static const doneStrikeThickness = 1.6;

  /// How far an important title leans from the primary text toward the
  /// accent: a tint, not the full brand colour.
  static const importantTitleAccentMix = .35;

  /// Size of the important star relative to the pill width.
  static const importantStarScale = .5;

  /// Surface-coloured separation around the star where it overlaps a pill.
  static const importantStarOutlineWidth = 1.5;

  /// Share of the star past the pill's right edge and above its top edge:
  /// it sits ON the edge, mostly inside, slightly off.
  static const importantStarOverhangX = .3;
  static const importantStarOverhangY = .15;

  /// The star's base leans from the primary text (paper cream in dark,
  /// charcoal in light) toward the page, so it is quieter than the text.
  static const importantStarSoften = .22;

  /// How far the star's gradient end leans toward the accent.
  static const importantStarAccentMix = .5;

  /// Imported events: faint 45° hatching inside their unassigned-tone rail —
  /// informative (it came from another calendar) but quiet.
  static const importedHatchSpacing = 5.0;
  static const importedHatchStroke = 1.0;
  static const importedHatchAlphaLight = .10;
  static const importedHatchAlphaDark = .14;

  static bool _isDark(AmbleTheme theme) =>
      theme.colorTextPrimary.computeLuminance() >
      theme.colorSurfaceBase.computeLuminance();

  static Color doneFill(AmbleTheme theme, Color labelColor) =>
      Color.lerp(labelColor, theme.colorSurfaceBase, doneFillMix)!;

  static Color doneTitle(AmbleTheme theme) =>
      theme.colorTextPrimary.withValues(alpha: doneTitleAlpha);

  /// The reserved "unassigned" tone (opaque): a new task with no label yet
  /// ("General") and an imported calendar event's rail. Nothing else may use
  /// it — not labels, not done tints, not surfaces.
  static Color _unassignedFill(AmbleTheme theme) =>
      _isDark(theme) ? ColorPrimitives.mistDark : ColorPrimitives.mistLight;

  static Color unlabeledFill(AmbleTheme theme) => _unassignedFill(theme);
  static Color importedFill(AmbleTheme theme) => _unassignedFill(theme);

  static Color importedHatch(AmbleTheme theme) =>
      theme.colorTextPrimary.withValues(
        alpha: _isDark(theme)
            ? importedHatchAlphaDark
            : importedHatchAlphaLight,
      );

  static Color importantTitle(AmbleTheme theme) => Color.lerp(
    theme.colorTextPrimary,
    theme.colorAccent,
    importantTitleAccentMix,
  )!;

  /// The star's two gradient stops: a softened primary-text tone (paper in
  /// dark, charcoal in light) easing into a hint of accent.
  static List<Color> importantStarGradient(AmbleTheme theme) {
    final base = Color.lerp(
      theme.colorTextPrimary,
      theme.colorSurfaceBase,
      importantStarSoften,
    )!;
    return [base, Color.lerp(base, theme.colorAccent, importantStarAccentMix)!];
  }
}
