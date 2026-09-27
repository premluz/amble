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
  // Sage — secondary green ramp (colorTaskCompleted; brand/accent duty
  // moved to `brand500`/`brand300` below).
  //
  // **2026-09-20 — re-derived from a supplied hex source-of-truth.**
  // Proposed as part of a full-palette pass (surface hierarchy + brand
  // rebrand); OKLCH triples below are calculated FROM the given hex, not
  // hand-picked — see docs/DECISIONS.md for the full before/after.
  static final sage50 = oklch(0.975, 0.004, 121.6); // #F6F7F4
  static final sage100 = oklch(0.939, 0.010, 125.7); // #E9ECE5
  static final sage300 = oklch(0.823, 0.026, 134.3); // #BEC9B8
  static final sage500 = oklch(0.614, 0.043, 138.2); // #788B72
  static final sage700 = oklch(0.480, 0.038, 138.3); // #53634E
  static final sage900 = oklch(0.299, 0.019, 138.7); // #293027

  // Surface ramp — light mode's field/inset/border scale.
  // surface2/surface3 carry `colorSurfaceField`/`colorSurfaceFieldActive`
  // (unchanged role) and, as of 2026-09-20, `colorBorder` too (was
  // `sand300`) — "card borders" is surface3's own named role in the
  // confirmed layering. surface0/surface1 are NOT the base/card roles —
  // see `paper`/`cream2` below for those; a pure-white surface1 sitting
  // directly below the pure-white floating overlay collided with it
  // (`elevation_direction_test.dart`), so the base/card roles were moved
  // off this ramp entirely rather than kept here.
  static final surface0 = oklch(0.933, 0.004, 106.5); // #E9E9E6
  static final surface1 = oklch(1.000, 0.000, 0); // #FFFFFF
  static final surface2 = oklch(0.970, 0.005, 95.1); // #F6F5F1 — inset field
  static final surface3 = oklch(0.872, 0.005, 106.5); // #D5D5D1 — border

  /// **2026-09-20 — the light-mode app background (`colorSurfaceBase`).**
  /// Confirmed directly: "the website's warm paper background... feels
  /// more like Panta" — a NEW anchor, not a repurposed existing ramp step
  /// (distinct from both `surface0` and `cream0`). Solved to exactly
  /// reproduce the given hex #F1F0EC.
  static final paper = oklch(0.9540, 0.0045, 85.0); // #F1F0EC

  // Cream — nested-row/content-card surface. `cream2` is
  // `colorSurfacePrimary` (cards/content) as of 2026-09-20 — confirmed
  // directly: "I wouldn't choose cream1 for cards: it's slightly darker
  // than the website background, so the elevation order would feel
  // reversed," landing on cream2 instead, one genuine step lighter than
  // `paper`. cream0/cream1 keep their own steps in the ramp for whatever
  // future role needs them; only cream2 is wired to a live token today.
  static final cream0 = oklch(0.913, 0.009, 84.6); // #E5E2DC
  static final cream1 = oklch(0.946, 0.007, 88.6); // #EFEDE8
  static final cream2 = oklch(0.974, 0.006, 84.6); // #F8F6F2 — cards/content

  /// The light-mode floating overlay (nav + its adjacent day-strip pane).
  /// Pure white, the lightest step in the ramp — confirmed directly:
  /// "reserve white for floating chrome, and use a fine border on cards
  /// plus a soft shadow beneath floating controls" — cards (`cream2`)
  /// separate from the overlay via `colorBorder`/`shadowPane` rather than
  /// a lightness gap, since nothing can sit lighter than white.
  static final creamOverlay = oklch(1.000, 0.000, 0); // #FFFFFF nav/overlay

  // Brand — the accent ramp. Replaces `sage` in the accent ROLE (buttons,
  // FAB, selected states, day pills); sage is retained below because
  // `colorTaskCompleted` still uses it, where green carries the meaning
  // "done" independently of branding.
  //
  // **2026-09-20 — rebranded from blue (266.5°) to violet-purple.**
  // Confirmed directly as an intentional accent change, not a tuning
  // pass. brand500 (light mode) is the interactive-element accent;
  // brand300 (dark mode) additionally now carries "the logo gesture,
  // selections, and expressive brand surfaces" per the same direction —
  // both values recalculated from the given hex, not hand-picked.
  static final brand500 = oklch(0.519, 0.149, 287.5); // #6656B8
  static final brand300 = oklch(0.821, 0.098, 292.6); // #C6B9FF — Flow

  // Sand — neutral/background ramp.
  // **2026-09-20 — re-derived alongside the rest of the palette.**
  static final sand50 = oklch(0.996, 0.003, 106.4); // #FEFEFC
  static final sand100 = oklch(0.976, 0.005, 95.1); // #F8F7F3 (timeline canvas)
  static final sand300 = oklch(0.904, 0.015, 90.2); // #E3DFD4
  static final sand500 = oklch(0.802, 0.027, 90.1); // #C5BEAB
  static final sand700 = oklch(0.595, 0.025, 87.2); // #857E6E
  static final sand900 = oklch(0.318, 0.011, 84.6); // #35322C

  // Slate — text/ink ramp.
  static final slate50 = oklch(0.969, 0.002, 145.6); // #F4F5F4
  static final slate300 = oklch(0.790, 0.008, 253.9); // #B7BBC0
  // The "even subtler" rung between slate500 and slate300, ~3.35:1 —
  // just past WCAG's 3:1 floor for large/decorative text. See git
  // history for the original request this rung answers.
  static final slate400 = oklch(0.614, 0.012, 248.0); // #7F858B
  static final slate500 = oklch(0.525, 0.011, 252.9); // #666B71
  static final slate700 = oklch(0.359, 0.008, 255.5); // #3A3D41
  static final slate900 = oklch(0.217, 0.002, 247.9); // #191A1B

  // Coral — attention/alert ramp.
  static final coral300 = oklch(0.851, 0.059, 35.3); // #F2C1B4
  static final coral500 = oklch(0.694, 0.113, 35.6); // #D9826B
  static final coral700 = oklch(0.528, 0.097, 34.6); // #9B5544

  // Crimson — destructive-action ramp. A true, more saturated red than
  // Coral's warmer attention/alert hue (~35°) — same lightness/chroma
  // shape as the Coral ramp (a light-mode-facing 500 rung, a
  // higher-contrast dark-mode-facing 300 rung) but shifted to ~25° and
  // pushed to higher chroma, so "delete" reads unmistakably stronger than
  // an ordinary alert badge. Requested directly.
  static final crimson300 = oklch(0.815, 0.087, 25.4); // #F5AC9C
  static final crimson500 = oklch(0.628, 0.174, 25.9); // #D1493A

  // Built-in categories' own pale-tint+saturated-icon color pairs used to
  // live here (`clayTint`/`clay500` etc., one pair per `TaskCategoryToken`)
  // — removed entirely, requested directly against a screenshot showing a
  // built-in category's light-mode pill visibly not matching its own
  // swatch. That system was independently solved per theme with no
  // cross-check against the 12-swatch palette below, and the two drifted
  // apart. Every category — built-in or custom — now resolves through
  // `categorySwatches` (below) via `Category.colorToken`; see
  // `category_visual.dart`'s `resolveCategoryVisual`.

  // User-defined Category palette (Phase — new Category entity). Per the
  // confirmed decision (docs/DECISIONS.md): a single saturated swatch per
  // color, not a tint+icon-color pair like the 4 built-in categories above.
  //
  // **2026-09-12 — the "one set works in both themes" assumption this
  // comment used to state was measured and found false.** Run through a
  // contrast checker against each theme's own `bg.base`, all 12 swatches
  // clear AA on dark (`ink900`, 4.73-5.82:1) and all 12 FAIL on light
  // (`surface0`, 3.08-3.66:1) — teal worst at 3.08:1, which is the
  // illegible-on-light case that was reported directly. One lightness
  // cannot serve both backgrounds: L=0.62 is simultaneously bright enough
  // to carry a near-black background and too bright to carry a near-white
  // one. This ramp is therefore the DARK-mode set, and
  // [categoryPalette12Light] below is its independently-solved light
  // counterpart. See that ramp's own comment for the solve.
  //
  // L=0.62/C=0.15 held fixed across all 12, only hue varies — the same
  // "equal lightness/chroma, vary hue" approach Phase 3 used for the
  // original 4-category spacing. L=0.62 is the SAME lightness already
  // measured safe for dark mode by the Phase 13a-pastel-v2 entry (the
  // built-in categories' dark icon-glyph lightness) — reused deliberately
  // rather than picked fresh, since it's already known to clear ~5:1
  // against `ink900`. C=0.15 is a conservative mid-high chroma: enough to
  // read as clearly "saturated swatch" rather than washed out, but below
  // the ~0.19 `brand500` accent chroma so none of the 12 competes with the
  // accent color for visual weight. Hues are 12 EVEN 30° steps starting at
  // 15° (15/45/75/.../345) — offset from 0° specifically so no swatch
  // lands on the four existing built-in category hues (32/153/216/300),
  // avoiding a false "this looks like Health" read. Minimum pairwise hue
  // gap is a uniform 30°, comfortably clear of the ~50-55° floor Phase 3
  // set for the smaller 4/5-hue case — 12 evenly-spaced hues can't match
  // that floor at this count, so distinguishability here leans on the
  // 30°-uniform spacing itself (no two adjacent swatches share a hue
  // family) rather than a CVD-deltaE minimum-pair check; a future revision
  // that hand-tunes chroma per hue (the way `brand500`'s lightness deviates
  // from `brand300`) is real future work if any specific pair reads as too
  // close in practice, not assumed to be needed here.
  // **2026-09-20 — re-derived alongside the rest of the palette** (dark
  // mode no longer out of scope — see the Surface/Brand ramps above for
  // the same reversal). Chroma/lightness now vary per-hue (solved from
  // supplied hex) rather than held uniform at 0.62/0.15 — see the
  // `test/core/tokens/palette_contrast_test.dart` result for whether this
  // still clears the same AA floor the prior uniform ramp targeted.
  static final categoryPalette12 = [
    oklch(0.650, 0.102, 13.2), // 0  red          #C5747D
    oklch(0.654, 0.103, 46.4), // 1  orange       #C47C59
    oklch(0.672, 0.096, 72.7), // 2  amber        #BA8C4F
    oklch(0.660, 0.079, 104.1), // 3  yellow-green #9A955B
    oklch(0.624, 0.063, 140.4), // 4  green        #73916D
    oklch(0.626, 0.059, 178.1), // 5  teal         #609488
    oklch(0.620, 0.053, 202.4), // 6  cyan         #5F9094
    oklch(0.620, 0.057, 235.3), // 7  sky blue     #648CA4
    oklch(0.623, 0.062, 259.8), // 8  blue         #7188AD
    oklch(0.615, 0.074, 291.6), // 9  violet       #857DAE
    oklch(0.613, 0.075, 322.4), // 10 magenta      #9A759F
    oklch(0.628, 0.078, 350.2), // 11 pink/rose    #AD758F
  ];

  /// The light-mode counterpart to [categoryPalette12] — same 12 hues, in
  /// the same order, so a stored [Category.colorToken] index keeps its
  /// meaning across a theme switch and no migration is needed.
  ///
  /// Solved, not eyeballed: for each hue, lightness was walked down from
  /// the dark ramp's 0.62 until the swatch cleared 4.6:1 against
  /// `surface0` (targeting just over the 4.5 AA floor so sRGB rounding
  /// can't drop it under), holding chroma at the dark ramp's 0.15 wherever
  /// that stays in gamut. Five hues (amber, yellow-green, teal, cyan, sky
  /// blue) sit below 0.15 because 0.15 is outside sRGB at their required
  /// lightness — backed off to the highest in-gamut chroma rather than
  /// shifting hue, since hue is what distinguishes the swatches.
  ///
  /// Chroma is deliberately NOT maximized per hue. An earlier solve that
  /// took the most saturated in-gamut chroma at each lightness hit the
  /// target too, but produced a visibly incoherent set (magenta #B602E9,
  /// violet #724EFE) that no longer read as one family — the uniform-
  /// chroma constraint is what keeps the ramp looking like a palette
  /// rather than twelve unrelated colors.
  ///
  /// Every value here is verified in `test/core/tokens/palette_contrast_test.dart`,
  /// which checks BOTH ramps against BOTH backgrounds — the point being
  /// that a swatch is only ever asserted against the background it
  /// actually renders on.
  // **2026-09-20 — 6 of 12 nudged down from the as-specified lightness**
  // (orange, amber, yellow-green, green, teal, blue) after the
  // `surface0` base move left them at 4.12-4.50:1, just under the 4.5:1
  // AA floor — hue/chroma untouched. Re-measured at 4.56-4.58:1. red,
  // cyan, sky blue, violet, magenta, pink/rose already cleared AA as
  // specified and are unchanged.
  static final categoryPalette12Light = [
    oklch(0.528, 0.103, 11.4), // 0  red          #9D505C
    oklch(0.526, 0.095, 47.6), // 1  orange       #975837
    oklch(0.522, 0.078, 70.9), // 2  amber        #866134
    oklch(0.517, 0.070, 104.5), // 3  yellow-green #6E6A39
    oklch(0.513, 0.054, 142.1), // 4  green        #556F52
    oklch(0.512, 0.050, 179.5), // 5  teal         #457067
    oklch(0.513, 0.046, 203.7), // 6  cyan         #466F73
    oklch(0.518, 0.051, 237.0), // 7  sky blue     #4C6D82
    oklch(0.519, 0.069, 259.1), // 8  blue         #506991
    oklch(0.509, 0.077, 289.9), // 9  violet       #655E8F
    oklch(0.506, 0.063, 321.4), // 10 magenta      #76597B
    oklch(0.521, 0.068, 348.3), // 11 pink/rose    #875970
  ];

  // Ink — dark-mode surface ramp.
  //
  // **2026-09-20 — re-derived alongside the rest of the palette.**
  // Confirmed directly: "keeps the calm near-black quality... while
  // creating slightly clearer elevation steps." Hue drifts slightly per
  // step (145.5 → 128.7 → 128.6 → 121.8 → 118.2) rather than holding one
  // fixed warm hue — a deliberate widening of this pass, not an
  // oversight; each step was solved independently rather than as one
  // fixed-hue ramp.
  static final ink900 = oklch(0.185, 0.003, 145.5); // #121312 body/base
  static final ink800 = oklch(0.212, 0.004, 128.7); // #181917 zone/card
  static final ink700 = oklch(0.246, 0.004, 128.6); // #20211F raised panel
  static final ink600 = oklch(0.338, 0.007, 118.2); // #373834 border/hairline

  /// The floating-overlay surface (nav + its adjacent day-strip pane) —
  /// the lightest step in the dark ramp, one above [ink700]. Its own rung
  /// rather than a reuse of [ink600]: that value is the hairline/border
  /// tone and is deliberately lighter than any surface should be.
  static final ink650 = oklch(0.279, 0.006, 121.8); // #282926 nav/overlay

  // Dark-mode form-field fills — the counterparts to surface2/surface3.
  static final inkField = oklch(0.322, 0.009, 116.1); // #33342F field, rest
  static final inkFieldActive = oklch(
    0.391,
    0.012,
    113.5,
  ); // #45463F field, active

  // Sand additions for dark-mode text.
  static final sand200 = oklch(0.955, 0.005, 95.1); // #F1F0EC dark primary
  static final sand400 = oklch(0.760, 0.013, 91.6); // #B4B1A8 dark secondary
  static final sand350 = oklch(0.559, 0.013, 89.8); // #77746C dark tertiary

  // Zone background — a light, low-chroma "this is Zone territory"
  // rendering-only backdrop for the Spatial Task View (Timeline), NOT a
  // category/task color.
  //
  // **2026-09-20 — moved from cool blue (hue 240) to lavender (hue
  // ~293).** Confirmed directly: "clearly distinguishable from both the
  // page background and white cards while remaining quiet." Still
  // deliberately apart from every built-in category hue and the
  // free-window neutral, and still low-chroma so it sits visually
  // "behind" a task capsule rather than competing with it.
  static final zoneBackground = oklch(0.915, 0.026, 293.1); // #E3E0F3
  static final zoneBackgroundDark = oklch(0.291, 0.027, 293.8); // #2C2938

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);
}
