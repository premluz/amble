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

  // Category accent hues — one pale-tint pill fill + one saturated icon
  // glyph per task category (two colors, not one). Re-derived a second time
  // this session against a user-supplied reference palette ("8 Soft Pastel
  // Colors" — Peach/Mint/Sky/Lavender chosen for health/work/personal/admin)
  // whose swatches sit at L≈0.95-0.99, C≈0.02-0.08 — a true pale tint, not a
  // mid-tone accent. At that lightness no single glyph color (light or dark)
  // clears real contrast, so per direct decision the pill is now a two-part
  // color: a pale tint fill (*Tint below) matched to the reference hexes
  // through this file's own oklch() pipeline (not hand-copied — verified to
  // reproduce the reference hex within 1-3/255 per channel), plus a
  // saturated, same-hue icon glyph (*Icon below) that actually carries the
  // legible/distinguishing signal, since the pale fill alone cannot.
  //
  // Hues were nudged from the reference's raw values (personal 234->218,
  // admin 292->300) specifically to widen the personal/admin gap — the two
  // pale-blue/violet reference swatches sit close enough in hue that a first
  // pass scored *below* the pre-pastel palette's worst-pair OKLab distance
  // under a red-green-CVD proxy (0.051 vs the old floor of 0.060). The nudge
  // brings the icon-level worst pair to 0.076, clearing the old floor with
  // margin — checked, not assumed. See docs/DECISIONS.md for the full
  // before/after and the distinguishability math.
  // **Tints strengthened 2026-09-12.** Reported directly: "color of
  // container is pale on light mode[,] needs to be stronger" — the
  // near-white tints (L≈0.95-0.98) passed contrast math against their own
  // icon glyphs but read as washed-out/indistinguishable at a glance,
  // specifically called out for the personal (blue) and work (teal)
  // badges. Deepened to L=0.90 with chroma raised ~1.45x (capped to stay
  // in gamut and short of neon), same hues throughout. Icon-on-badge
  // contrast drops from ~4.5-4.9:1 to ~4.0-4.2:1 — still clear of the 3:1
  // floor a decorative icon glyph needs, since deepening the badge
  // necessarily narrows the gap to the icon sitting on it.
  // **2026-09-20 — re-derived, quieter and closer to a muted-circle
  // reference.** Confirmed directly: "color supports recognition but does
  // not dominate the schedule." Token names/roles unchanged (health/work/
  // personal/admin still map to clay/ochre/periwinkle/berry); only the
  // OKLCH triples move.
  //
  // Icon lightness NUDGED DOWN from the as-specified values after the
  // `surface0` base move (`colorSurfaceBase`, semantic_theme.dart) left
  // all four just under 4.5:1 AA (4.39-4.47:1) — hue/chroma untouched, so
  // the specified color character is unchanged, only how dark it reads.
  // Re-measured at 4.58-4.60:1 against the new base. See
  // `test/core/tokens/palette_contrast_test.dart`.
  // **2026-09-23 — category set expanded from 5 to 9, and two hues
  // reassigned.** Requested directly: "Healthy should be Redish[,] Work
  // should be blueish," plus four brand-new built-ins (Home, Personal,
  // Social, Reading, Learning — see `BuiltInCategoryIds`/
  // `category_providers.dart`'s seed list). `clay`/`ochre`/`periwinkle`/
  // `berry` keep their names (renaming them purely for accuracy wasn't
  // worth the diff), but two now point at DIFFERENT hues than their name
  // suggests:
  //   - `clay` (health) moves from 35.9° (orange/peach) to 25° (true red).
  //   - `ochre` (work) moves from 137.8° (green) to 263.2° (blue) — the
  //     exact hue `periwinkle` used to occupy.
  //   - `periwinkle` is REPOINTED to `home` (a new category) at 137.8°
  //     (green) — the hue `ochre`/work just vacated — since the OLD
  //     "Personal" role (home icon) is renamed to "Home" and a DIFFERENT
  //     new "Personal" (user icon) takes its own fresh hue below.
  //   - `berry` (admin) is unchanged.
  // Four entirely new pairs (`amber`/personal, `teal`/social, `sky`/
  // reading, `rose`/learning) fill hues chosen for ≥33° separation from
  // every other built-in hue, verified against this file's own AA floors
  // (icon ≥4.5:1 against `colorSurfaceBase` each theme, tint >1.15:1
  // against white, icon-on-tint ≥3:1 — see
  // `test/core/tokens/palette_contrast_test.dart`).
  static final clayTint = oklch(0.904, 0.034, 25.0); // #F7D6CC health pill
  static final clay500 = oklch(0.529, 0.101, 25.0); // #9E5142 health icon
  static final ochreTint = oklch(0.908, 0.022, 263.2); // #D9E1F0 work pill
  static final ochre500 = oklch(0.518, 0.067, 263.2); // #52698F work icon
  static final periwinkleTint = oklch(0.918, 0.025, 137.8); // #DCE8D8 home pill
  static final periwinkle500 = oklch(0.512, 0.059, 137.8); // #546F4F home icon
  static final berryTint = oklch(0.918, 0.020, 315.7); // #E9E0ED admin pill
  static final berry500 = oklch(0.524, 0.054, 325.2); // #7A5F7B admin icon
  // Personal (NEW — user icon), hue 90° (yellow-green).
  static final amberTint = oklch(0.905, 0.060, 90.0); // #EFDFB3 personal pill
  static final amber500 = oklch(0.530, 0.095, 90.0); // #81691F personal icon
  static final amber500Dark = oklch(0.590, 0.075, 90.0); // #8F7B47
  // Social (NEW — two-people icon), hue 185° (teal).
  static final tealTint = oklch(0.905, 0.060, 185.0); // #B3EDE5 social pill
  static final teal500 = oklch(0.515, 0.095, 185.0); // #00796F social icon
  static final teal500Dark = oklch(0.580, 0.075, 185.0); // #3F8980
  // Reading (NEW — book icon), hue 218° (sky blue).
  static final skyTint = oklch(0.905, 0.060, 218.0); // #B3EAFA reading pill
  static final sky500 = oklch(0.520, 0.095, 218.0); // #00758D reading icon
  static final sky500Dark = oklch(0.585, 0.075, 218.0); // #428799
  // Learning (NEW — graduation cap icon), hue 350° (pink/magenta).
  static final roseTint = oklch(0.905, 0.060, 350.0); // #FFD0E5 learning pill
  static final rose500 = oklch(0.540, 0.095, 350.0); // #985676 learning icon
  static final rose500Dark = oklch(0.600, 0.075, 350.0); // #A36E86
  // The neutral "no category chosen yet" pair — same family, zero-ish
  // chroma, as before.
  static final neutralTint = oklch(0.927, 0.004, 106.5); // #E7E7E4
  static final neutral500 = oklch(0.514, 0.007, 128.6); // #666864

  // Dark-mode category pills — re-derived alongside light mode as of
  // 2026-09-20 (previously explicitly out of scope; that scoping is
  // reversed here per direct request — full palette, both themes,
  // together).
  //
  // **2026-09-23 — hues swapped to match the light-mode reassignment
  // above**: `clay` (health) → 25° red, `ochre` (work) → 263.2° blue,
  // `periwinkle` (now home) → 137.8° green. Chroma/lightness held at
  // their prior values; only hue moved, mirroring exactly how the light
  // triples above were edited.
  static final clay500Dark = oklch(0.646, 0.079, 25.0); // #C08272
  static final ochre500Dark = oklch(0.625, 0.053, 258.0); // #7489A8
  static final periwinkle500Dark = oklch(0.635, 0.046, 140.8); // #7C9278
  static final berry500Dark = oklch(0.609, 0.058, 327.3); // #967795
  static final neutral500Dark = oklch(0.653, 0.007, 137.8); // #8E918D

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
