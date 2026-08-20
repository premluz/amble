import 'dart:ui';

import 'oklch.dart';

/// Tier 1 — raw color values, no semantic meaning.
/// Do not reference these directly from widgets; use Tier 2 semantic
/// tokens (see semantic_theme.dart) instead.
///
/// Authored as OKLCH (L, C, H) triples, converted via [oklch] — see
/// docs/DECISIONS.md ("Color primitives switched to OKLCH") and
/// docs/ARCHITECTURE.md for why this one Tier 1 category is `static final`
/// rather than `const`.
abstract final class ColorPrimitives {
  // Sage — primary brand ramp.
  static final sage50 = oklch(0.967, 0.007, 124);
  static final sage100 = oklch(0.927, 0.014, 129);
  static final sage300 = oklch(0.787, 0.046, 132);
  static final sage500 = oklch(0.517, 0.051, 136);
  static final sage700 = oklch(0.404, 0.039, 137);
  static final sage900 = oklch(0.289, 0.024, 135);

  // Sand — neutral/background ramp.
  static final sand50 = oklch(0.985, 0.004, 91);
  static final sand100 = oklch(0.970, 0.007, 89);
  static final sand300 = oklch(0.919, 0.015, 90);
  static final sand500 = oklch(0.814, 0.028, 91);
  static final sand700 = oklch(0.611, 0.028, 89);
  static final sand900 = oklch(0.325, 0.014, 90);

  // Slate — text/ink ramp.
  static final slate50 = oklch(0.970, 0.002, 248);
  static final slate300 = oklch(0.780, 0.009, 248);
  static final slate500 = oklch(0.546, 0.013, 252);
  static final slate700 = oklch(0.362, 0.010, 254);
  static final slate900 = oklch(0.212, 0.005, 248);

  // Coral — attention/alert ramp.
  static final coral300 = oklch(0.830, 0.074, 36);
  static final coral500 = oklch(0.683, 0.141, 36);
  static final coral700 = oklch(0.533, 0.124, 35);

  // Category accent hues — one mid-tone swatch per task category.
  // Equal lightness (0.62) and chroma (0.10) — one step darker/more muted
  // than the original 0.70/0.13, per direct feedback that the category
  // palette read too saturated/bright. Hues unchanged, still deliberately
  // spread (minimum 50° apart, none opposite/complementary) so they stay
  // distinguishable under common red-green color-vision deficiency, not
  // just at a glance in typical vision. See docs/DECISIONS.md.
  static final clay500 = oklch(0.62, 0.10, 30); // health
  static final ochre500 = oklch(0.62, 0.10, 120); // work
  static final periwinkle500 = oklch(0.62, 0.10, 250); // personal
  static final berry500 = oklch(0.62, 0.10, 340); // admin

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);
}
