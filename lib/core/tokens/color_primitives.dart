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
  static final surface2 = oklch(0.951, 0.008, 78.0); // #F2EEE9 — inset field
  static final surface3 = oklch(0.918, 0.012, 78.0); // #E8E3DB — border

  /// **2026-09-20 — the light-mode app background (`colorSurfaceBase`).**
  /// Confirmed directly: "the website's warm paper background... feels
  /// more like Panta" — a NEW anchor, not a repurposed existing ramp step
  /// (distinct from both `surface0` and `cream0`). Solved to exactly
  /// reproduce the given hex #F1F0EC.
  ///
  /// **2026-10-08 — near-neutral, finer steps** (see the Ink note below):
  /// the warmth is kept as a trace (hue 90, chroma .002), not a cream cast.
  ///
  /// **2026-10-10 — warm paper, matched to the Rios reference** (#F7F4EF
  /// paper, #FBF9F6 panel, #E8E2D9 rule, #1F1C1A/#6F6A63 text). The paper,
  /// cream, surface and slate text rungs move to hue ~78 at chroma
  /// .005-.015. The base stays a touch deeper than the reference so it
  /// remains below luminance 0.90 (`elevation_direction_test.dart`).
  static final paper = oklch(0.963, 0.007, 78.0); // #F5F2EE

  // Cream — nested-row/content-card surface. `cream2` is
  // `colorSurfacePrimary` (cards/content) as of 2026-09-20 — confirmed
  // directly: "I wouldn't choose cream1 for cards: it's slightly darker
  // than the website background, so the elevation order would feel
  // reversed," landing on cream2 instead, one genuine step lighter than
  // `paper`. cream0/cream1 keep their own steps in the ramp for whatever
  // future role needs them; only cream2 is wired to a live token today.
  static final cream0 = oklch(0.913, 0.009, 84.6); // #E5E2DC
  static final cream1 = oklch(0.953, 0.007, 78.0); // #F2EFEA
  static final cream2 = oklch(0.983, 0.005, 78.0); // #FBF9F6 — cards/content

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
  static final slate400 = oklch(0.615, 0.015, 77.0); // #8A847B
  static final slate500 = oklch(0.527, 0.012, 76.0); // #6F6A63
  static final slate700 = oklch(0.359, 0.008, 255.5); // #3A3D41
  static final slate900 = oklch(0.229, 0.006, 56.0); // #1F1C1A

  // Mist — the "unassigned" tone: new tasks with no label yet and imported
  // calendar events. It is reserved for those, so it must not be reused for
  // anything else. Its hue (218°) falls in the gap between the label
  // palette's cyan (202°) and sky blue (235°), well away from the accent
  // (287°), sage (138°) and slate (~250°, and near-grey). Its chroma is
  // above any done-task tint (≤ .03), so it never reads as a done pill.
  static final mistLight = oklch(0.855, 0.040, 218.0); // #B3D6E1
  static final mistDark = oklch(0.420, 0.040, 218.0); // #33535C

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
  // **2026-10-10 — Rios palette shift, dark set.** Same families and
  // emphasis as [categoryPalette12Light]: muted, warm-leaning, led by
  // lavender (9), periwinkle (15) and teal (5). Lightness sits where a
  // swatch clears 4.5:1 against `ink900` and still carries a paper glyph
  // at 3:1 or better.
  static final categoryPalette12 = [
    oklch(0.608, 0.050, 18.0), // 0  red / rose   #9F7777
    oklch(0.610, 0.050, 50.0), // 1  orange/peach #9D7B69
    oklch(0.625, 0.040, 75.0), // 2  amber / sand #96856D
    oklch(0.620, 0.040, 105.0), // 3  yellow-green #89886C
    oklch(0.605, 0.040, 138.0), // 4  green / moss #768871
    oklch(0.610, 0.070, 184.0), // 5  teal         #4E9188
    oklch(0.610, 0.045, 200.0), // 6  cyan         #638C8E
    oklch(0.610, 0.050, 240.0), // 7  sky blue     #68889F
    oklch(0.600, 0.060, 258.0), // 8  blue         #6A82A4
    oklch(0.612, 0.095, 300.0), // 9  lavender     #8D76B4
    oklch(0.608, 0.055, 325.0), // 10 magenta      #947895
    oklch(0.605, 0.050, 355.0), // 11 pink / blush #9B7683
    // **2026-09-30 — four more, appended** (requested directly: "4 more,
    // yellowish, bluish"). Appended rather than slotted by hue so every
    // stored `colorToken` keeps its colour.
    oklch(0.640, 0.060, 90.0), // 12 golden yellow #9A8B62
    oklch(0.630, 0.050, 122.0), // 13 lime          #848E6D
    oklch(0.598, 0.075, 248.0), // 14 ocean         #5B84AB
    oklch(0.620, 0.060, 270.0), // 15 periwinkle    #7885AB
  ];

  /// The light-mode counterpart to [categoryPalette12] — same 12 hues, in
  /// the same order, so a stored [Category.colorToken] index keeps its
  /// meaning across a theme switch and no migration is needed.
  ///
  /// **2026-10-10 — soft pastels, Rios-led.** Requested directly: the
  /// AA-against-the-page ramp (L≈0.52) made light-mode pills too strong.
  /// Pills are now light, solid fills whose legibility comes from the
  /// charcoal glyph and text drawn on them (7:1 or better, via
  /// `glyphColorOn`), not from contrast with the page. Emphasis follows the
  /// brand reference: lavender (9), periwinkle (15) and teal (5) carry the
  /// most chroma; every other hue is a quieter supporting tone (moss, sand,
  /// blush and their neighbours). Indices and hue families are unchanged,
  /// so stored `colorToken`s keep their colour.
  ///
  /// Verified in `test/core/tokens/palette_contrast_test.dart`.
  static final categoryPalette12Light = [
    oklch(0.840, 0.050, 18.0), // 0  red / rose   #EABEBE
    oklch(0.850, 0.050, 50.0), // 1  orange/peach #EAC5B1
    oklch(0.880, 0.040, 75.0), // 2  amber / sand #E7D4BB
    oklch(0.870, 0.040, 105.0), // 3  yellow-green #D8D6B8
    oklch(0.820, 0.040, 138.0), // 4  green / moss #B8CBB2
    oklch(0.800, 0.080, 184.0), // 5  teal         #80CFC3
    oklch(0.830, 0.045, 200.0), // 6  cyan         #A6D1D3
    oklch(0.830, 0.050, 240.0), // 7  sky blue     #ABCCE5
    oklch(0.780, 0.060, 258.0), // 8  blue         #A0B9DE
    oklch(0.750, 0.105, 300.0), // 9  lavender     #B89FE7
    oklch(0.800, 0.060, 325.0), // 10 magenta      #D2B1D3
    oklch(0.840, 0.050, 355.0), // 11 pink / blush #E6BECC
    oklch(0.870, 0.060, 90.0), // 12 golden yellow #E3D3A8
    oklch(0.850, 0.050, 122.0), // 13 lime          #C8D3B0
    oklch(0.730, 0.080, 248.0), // 14 ocean         #7FADD8
    oklch(0.820, 0.065, 270.0), // 15 periwinkle    #B3C3EF
  ];

  /// The strong step of each [categoryPalette12Light] hue, same index: a
  /// week block's rail and a pill's icon colour. Solved, not eyeballed: each
  /// accent's lightness walks down from .53 until it reaches 3.1:1 against
  /// its own swatch (WCAG's 3:1 floor for icons), at the swatch's hue with
  /// chroma twice the swatch's, kept in gamut and between .11 and .16.
  static final categoryAccentsLight = [
    oklch(0.530, 0.110, 18.0), // 0  red / rose   #A24F53
    oklch(0.530, 0.110, 50.0), // 1  orange/peach #9D562B
    oklch(0.530, 0.110, 75.0), // 2  amber / sand #906106
    oklch(0.530, 0.110, 105.0), // 3  yellow-green #766F08
    oklch(0.510, 0.110, 138.0), // 4  green / moss #447433
    oklch(0.500, 0.088, 184.0), // 5  teal         #027369
    oklch(0.520, 0.088, 200.0), // 6  cyan         #02787D
    oklch(0.520, 0.110, 240.0), // 7  sky blue     #1870A1
    oklch(0.490, 0.120, 258.0), // 8  blue         #3260A3
    oklch(0.470, 0.160, 300.0), // 9  lavender     #6A3EA5
    oklch(0.510, 0.120, 325.0), // 10 magenta      #884B8B
    oklch(0.530, 0.110, 355.0), // 11 pink / blush #9C4E6F
    oklch(0.530, 0.108, 90.0), // 12 golden yellow #846801
    oklch(0.530, 0.110, 122.0), // 13 lime          #617522
    oklch(0.450, 0.120, 248.0), // 14 ocean         #025894
    oklch(0.520, 0.130, 270.0), // 15 periwinkle    #4C62B3
  ];

  /// The dark-mode counterpart: every accent at L .80, the swatch's hue,
  /// chroma .10 (a little more for teal, lavender, golden yellow and ocean).
  /// A dark pill or block fills with a dark tint of its swatch, so the
  /// accent reads as the light, saturated step of that hue (5.9–6.4:1).
  static final categoryAccentsDark = [
    oklch(0.800, 0.100, 18.0), // 0  red / rose   #F7A3A5
    oklch(0.800, 0.100, 50.0), // 1  orange/peach #F2AB83
    oklch(0.800, 0.100, 75.0), // 2  amber / sand #E4B572
    oklch(0.800, 0.100, 105.0), // 3  yellow-green #C7C274
    oklch(0.800, 0.100, 138.0), // 4  green / moss #9ECD8E
    oklch(0.800, 0.140, 184.0), // 5  teal         #11DAC8
    oklch(0.800, 0.100, 200.0), // 6  cyan         #64D1D7
    oklch(0.800, 0.100, 240.0), // 7  sky blue     #80C7F8
    oklch(0.800, 0.100, 258.0), // 8  blue         #96C0FE
    oklch(0.800, 0.118, 300.0), // 9  lavender     #C9ACFF
    oklch(0.800, 0.110, 325.0), // 10 magenta      #E2A5E5
    oklch(0.800, 0.100, 355.0), // 11 pink / blush #F2A3C1
    oklch(0.800, 0.120, 90.0), // 12 golden yellow #DCBA5C
    oklch(0.800, 0.100, 122.0), // 13 lime          #B3C87F
    oklch(0.800, 0.106, 248.0), // 14 ocean         #85C4FF
    oklch(0.800, 0.100, 270.0), // 15 periwinkle    #A4BBFF
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
  //
  // **2026-10-08 — neutral greys, steps of a few RGB units, hairlines
  // barely above the surface.** Requested directly against Notion
  // Calendar, Linear, Devin and cmux: "very, very subtle color steps...
  // very, very, very subtle separator lines." Measured there: surfaces
  // #171717/#191919/#202020/#262626 (Notion Calendar), separators 1.14-1.23x
  // the surface beneath them (ours were 1.49x). The olive cast (chroma
  // up to .009) becomes a trace of warmth (hue 90, chroma .002).
  //
  // **2026-10-10 — warm charcoal, matched to the Rios reference** (night
  // system #171616/#23211F/#35312D). Hue ~70, chroma .003-.007: warmer
  // than the 2026-10-08 greys, still far from the old olive cast. Steps
  // stay a few RGB units; the hairline is 1.24x the card.
  static final ink900 = oklch(0.203, 0.003, 60.0); // #181615 body/base
  static final ink800 = oklch(0.217, 0.004, 70.0); // #1B1A18 zone/card
  static final ink700 = oklch(0.245, 0.005, 70.0); // #22201E raised panel
  static final ink600 = oklch(0.292, 0.007, 70.0); // #2E2B28 border/hairline

  /// The floating-overlay surface (nav + its adjacent day-strip pane) —
  /// the lightest step in the dark ramp, one above [ink700]. Its own rung
  /// rather than a reuse of [ink600]: that value is the hairline/border
  /// tone and is deliberately lighter than any surface should be.
  static final ink650 = oklch(0.269, 0.006, 70.0); // #282623 nav/overlay

  // Dark-mode form-field fills — the counterparts to surface2/surface3.
  static final inkField = oklch(0.300, 0.006, 70.0); // #302D2B field, rest
  static final inkFieldActive = oklch(
    0.338,
    0.007,
    70.0,
  ); // #3A3734 field, active

  // Sand additions for dark-mode text.
  static final sand200 = oklch(0.957, 0.009, 78.0); // #F4F0EA dark primary
  static final sand400 = oklch(0.754, 0.018, 76.0); // #B6AEA3 dark secondary
  static final sand350 = oklch(0.559, 0.015, 76.0); // #79736B dark tertiary

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
