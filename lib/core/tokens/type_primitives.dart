import 'dart:ui';

/// Tier 1 — raw type scale, no semantic meaning.
abstract final class TypePrimitives {
  /// **2026-09-21 — the app's MONOSPACE font**, one half of a dual-font
  /// system (see [fontFamilySans] for the other). Every `TextStyle` built
  /// in `semantic_theme.dart` reads one of these two rather than
  /// hardcoding a family name.
  ///
  /// Kept for: timeline times, start/end time and duration, habit/
  /// tracked-behavior counts, statistics and numeric history, technical/
  /// export metadata, version numbers and storage sizes — anything
  /// genuinely numeric or temporal — AND zone names specifically, an
  /// explicit carve-out confirmed directly: zone names would otherwise
  /// read as ordinary titles/headlines (→ [fontFamilySans]), but must
  /// stay monospace.
  ///
  /// Name unchanged from the single-font era (was simply "the app's
  /// font") to minimise the diff — every existing monospace-bound call
  /// site already reads this exact constant.
  static const fontFamily = 'JetBrains Mono';

  /// **2026-09-21 — the app's SANS font**, the DM-Sans-by-default half of
  /// the dual-font system. Headlines, section titles, task/event/routine
  /// names, category names, buttons/navigation/menus, body copy and
  /// descriptions, empty states and onboarding — everything that is NOT
  /// one of [fontFamily]'s numeric/temporal/zone-name exceptions.
  ///
  /// Also `main.dart`'s own `ThemeData.fontFamily` fallback, so default
  /// Material text NOT built from one of our own tokens (an AlertDialog
  /// action, a SnackBar) matches too — nothing un-tokenized in this app
  /// is inherently numeric, so defaulting the fallback to sans carries no
  /// risk of silently mis-rendering a value display.
  ///
  /// Vendored as a single variable font (`assets/fonts/DMSans-Variable
  /// .ttf`), not per-weight static files like [fontFamily] above — see
  /// `pubspec.yaml`'s own `DM Sans` font block for why that's the
  /// correct pattern here, not a workaround.
  static const fontFamilySans = 'DM Sans';

  // **2026-09-12 — new smallest rung.** Added so the task-size scale's own
  // "sm" setting could shift one step down (see AmbleTheme.textTaskTitleSm)
  // — nothing below `size1` existed until this. 11, not a full 2px step
  // like every other rung here: a genuine 2px drop from the already-small
  // 12px would risk legibility at the smallest task-size setting, so this
  // one step is intentionally half the usual gap.
  static const size0 = 11.0;
  static const size1 = 12.0;
  static const size2 = 14.0;
  static const size3 = 16.0;
  static const size4 = 20.0;
  static const size5 = 24.0;
  static const size6 = 32.0;
  static const size7 = 40.0;

  static const weightRegular = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemibold = FontWeight.w600;
  static const weightBold = FontWeight.w700;

  static const lineHeightTight = 1.1;
  static const lineHeightNormal = 1.3;
  static const lineHeightRelaxed = 1.5;
}
