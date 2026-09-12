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
  // Phase 13a-pastel: sage500/700/50 lightened and re-derived for a gentler
  // accent, per direct feedback to move the light palette toward a softer,
  // pastel character (see docs/DECISIONS.md). sage500 is the ramp's
  // functional anchor — it's the accent/button/FAB fill, so it's tuned to
  // hold WCAG AA (4.76:1 white-glyph, 4.56:1 vs sand50), not picked purely
  // by eye. sage100/sage300/sage900 are left UNCHANGED: sage300 is dark
  // mode's `colorAccent` (Phase 13a) and dark mode is explicitly out of
  // scope this session, so its value can't move without an out-of-scope
  // dark-mode side effect; sage900/sage700(prev)/sage50(prev) had no
  // consumers to begin with, so sage50/sage700 were still nudged for ramp
  // consistency around the new sage500 anchor, at zero risk.
  static final sage50 = oklch(0.975, 0.006, 138);
  static final sage100 = oklch(0.927, 0.014, 129);
  static final sage300 = oklch(0.787, 0.046, 132);
  static final sage500 = oklch(0.550, 0.060, 140);
  static final sage700 = oklch(0.430, 0.050, 138);
  static final sage900 = oklch(0.289, 0.024, 135);

  // Surface ramp — the app's neutral chrome (light mode). Zero chroma by
  // deliberate decision, not oversight: the surface system is specified as
  // true greys (#F7F7F7 bg / #FFFFFF pane), so the warm `sand` tint that
  // used to carry these roles is explicitly not applied here. The four
  // steps are a single scale — background behind panes, the pane itself,
  // a form field's resting fill inside a pane, and that field's
  // focused/active fill one tone darker.
  //
  // Lightness values are DERIVED, not eyeballed: each was solved back
  // through this file's own oklch() pipeline to land on the intended sRGB
  // byte, so the values survive the perceptual round-trip rather than
  // being hand-copied past it.
  //
  // The 0→1 step (#F7F7F7 → #FFFFFF) is only ~3% lightness and cannot
  // define a pane's edge on its own. That boundary is carried by
  // `shadowPane` instead (see AmbleTheme) — a subtle drop shadow, which is
  // what separates the two levels without either darkening the specified
  // background or drawing a border.
  static final surface0 = oklch(0.9746, 0.0, 0); // #F7F7F7 — app background
  static final surface1 = oklch(1.0, 0.0, 0); // #FFFFFF — pane
  static final surface2 = oklch(0.9204, 0.0, 0); // #E4E4E4 — field, at rest
  static final surface3 = oklch(0.8590, 0.0, 0); // #D1D1D1 — field, active

  // **2026-09-12 — light-mode counterparts to the re-anchored ink ramp.**
  // Derived from the same two directly-specified dark anchors (#121110
  // body / #171615 zone) by mirroring their RELATIONSHIP rather than their
  // values: dark steps upward from its base in four rungs (0.178 -> 0.201
  // -> 0.232 -> 0.270), light steps DOWNWARD toward white in the same
  // four-rung shape (0.945 -> 0.959 -> 0.977 -> 1.0), and both carry the
  // same faint warm chroma at hue 67.7 so the two themes read as the same
  // product rather than one warm and one clinically grey.
  //
  // Deliberately additive — `surface0`-`surface3` above are untouched.
  // Those carry the app's existing true-grey specification across many
  // roles (form fields, focus states); re-tinting the whole scale to chase
  // two dark-mode anchors would be a far wider visual change than was
  // asked for. This ramp exists for the surfaces the request actually
  // named: body, card, nested row, and the floating overlay.
  //
  // **Re-solved a second time, 2026-09-12** — a `colorSurfaceSecondary`
  // that reused `cream1` (the same value as `colorSurfacePrimary`) meant
  // light mode had only 2 visually distinct steps where dark mode has 3.
  // Reported directly: a Manage-screen row card (`colorSurfaceSecondary`)
  // was indistinguishable from the page it sat on in light mode, while the
  // same rows were clearly visible in dark. `cream1`/`cream2` now form a
  // real 2-step climb between base and overlay, mirroring
  // `ink800`/`ink700`'s own distinctness.
  static final cream0 = oklch(0.945, 0.0035, 67.7); // #EEECEA body/base
  static final cream1 = oklch(0.959, 0.0030, 67.7); // #F3F1EF pane
  static final cream2 = oklch(0.977, 0.0025, 67.7); // #F9F7F6 card/row

  /// The light-mode floating overlay (nav + its adjacent day-strip pane).
  /// Pure white, the lightest step in the ramp — light mode's elevation
  /// direction is the inverse of dark's (moving TOWARD white rather than
  /// away from black), and white plus `shadowPane` is what reads as
  /// "floating above" a near-white page.
  static final creamOverlay = oklch(1.0, 0.0, 0); // #FFFFFF nav/overlay

  // Brand — the accent ramp. Replaces `sage` in the accent ROLE (buttons,
  // FAB, selected states, day pills); sage is retained below because
  // `colorTaskCompleted` still uses it, where green carries the meaning
  // "done" independently of branding.
  //
  // Solved back through this file's own oklch() pipeline to reproduce the
  // specified #3B63DB (lands on #3B62DB — 1/255 on the green channel, the
  // same tolerance the pastel category tints were accepted at). Measured,
  // not assumed: white-on-brand500 is 5.31:1 and brand500 on the light
  // background is 4.96:1, both past WCAG AA for normal text.
  static final brand500 = oklch(0.538, 0.191, 266.5);
  // Dark mode's accent, same hue. Light enough to clear AA against
  // `ink900` (5.12:1) — the light-mode value measures only ~2.4:1 there,
  // so the two palettes genuinely need different anchors.
  static final brand300 = oklch(0.700, 0.140, 266.5);

  // Sand — neutral/background ramp.
  static final sand50 = oklch(1.0, 0.0, 0); // pure white
  static final sand100 = oklch(1.0, 0.0, 0); // pure white (timeline canvas)
  static final sand300 = oklch(0.919, 0.015, 90);
  static final sand500 = oklch(0.814, 0.028, 91);
  static final sand700 = oklch(0.611, 0.028, 89);
  static final sand900 = oklch(0.325, 0.014, 90);

  // Slate — text/ink ramp.
  static final slate50 = oklch(0.970, 0.002, 248);
  static final slate300 = oklch(0.780, 0.009, 248);
  // **2026-09-12 — new rung, between slate500 and slate300.** Requested
  // directly: zone names needed to read as "even subtler" than the
  // existing secondary text color (`slate500`, 4.66:1 against the light
  // base). `slate300` (already spoken for by `colorTaskSkipped`) measures
  // only 1.7:1 — too faint to be legible text at all. Solved for ~3.35:1,
  // just past WCAG's 3:1 floor for large/decorative text with margin for
  // sRGB rounding: perceptibly lighter than `slate500` while still
  // reading as a deliberate label, not a rendering glitch.
  static final slate400 = oklch(0.600, 0.013, 252); // #7B8188, 3.35:1
  static final slate500 = oklch(0.521, 0.013, 252);
  static final slate700 = oklch(0.362, 0.010, 254);
  static final slate900 = oklch(0.212, 0.005, 248);

  // Coral — attention/alert ramp.
  static final coral300 = oklch(0.830, 0.074, 36);
  static final coral500 = oklch(0.683, 0.141, 36);
  static final coral700 = oklch(0.533, 0.124, 35);

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
  static final clayTint = oklch(0.900, 0.053, 36); // health pill (peach)
  static final clay500 = oklch(0.540, 0.150, 32); // health icon, 3.97:1
  static final ochreTint = oklch(0.900, 0.087, 153); // work pill (mint)
  // **2026-09-12 — darkened for AA on the light base.** At L=0.550 this
  // measured 4.27:1 against `cream0`, under the 4.5 floor; this is the
  // green-teal reported as illegible in light mode. Hue and chroma are
  // untouched, so the category still reads as the same color.
  static final ochre500 = oklch(0.510, 0.110, 153); // work icon, 4.64:1
  static final periwinkleTint = oklch(0.900, 0.074, 218); // personal pill (sky)
  // Same AA correction as ochre500 above: 4.11:1 -> 4.63:1. Chroma backs
  // off slightly (0.130 -> 0.095) because 0.130 is outside sRGB at the
  // lightness this hue needs.
  static final periwinkle500 = oklch(
    0.515,
    0.090,
    216,
  ); // personal icon, 4.63:1
  static final berryTint = oklch(0.900, 0.056, 300); // admin pill (lavender)
  static final berry500 = oklch(0.535, 0.140, 300); // admin icon, 4.67:1
  // The neutral "no category chosen yet" pair. Zero chroma so it reads as
  // absence of a category rather than a fifth meaning, at the same
  // lightness as the four tints above so it sits in the same family. Icon
  // lightness matches the other *500 icons for equal contrast against its
  // own fill.
  static final neutralTint = oklch(0.956, 0.0, 0); // default pill (grey)
  // Was 4.50:1 — technically at the floor, but close enough that sRGB
  // rounding could drop it under. Nudged to 4.69:1.
  static final neutral500 = oklch(0.520, 0.0, 0); // default icon, 4.69:1

  // Dark-mode category pills — the ORIGINAL pre-pastel mid-tone values,
  // kept under their own names so dark mode's rendering is byte-for-byte
  // unchanged by this session. Dark mode is explicitly out of scope; these
  // four names used to BE clay500/ochre500/periwinkle500/berry500 before
  // this session repurposed those names for the new light-mode icon
  // glyphs, so they're preserved here rather than silently inherited —
  // Phase 13a measured these exact values at 4.9-5.2:1 against `ink900`,
  // and that measurement is only valid for these numbers, not whatever the
  // light-mode icon color happens to become later. See docs/DECISIONS.md.
  static final clay500Dark = oklch(0.62, 0.10, 30);
  static final ochre500Dark = oklch(0.62, 0.10, 120);
  static final periwinkle500Dark = oklch(0.62, 0.10, 250);
  static final berry500Dark = oklch(0.62, 0.10, 340);
  // Same lightness as the four above, zero chroma — the neutral default's
  // dark-mode pill.
  static final neutral500Dark = oklch(0.62, 0.0, 0);

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
  static final categoryPalette12 = [
    oklch(0.62, 0.15, 15), // 0  red
    oklch(0.62, 0.15, 45), // 1  orange
    oklch(0.62, 0.15, 75), // 2  amber
    oklch(0.62, 0.15, 105), // 3  yellow-green
    oklch(0.62, 0.15, 135), // 4  green
    oklch(0.62, 0.15, 165), // 5  teal
    oklch(0.62, 0.15, 195), // 6  cyan
    oklch(0.62, 0.15, 225), // 7  sky blue
    oklch(0.62, 0.15, 255), // 8  blue
    oklch(0.62, 0.15, 285), // 9  violet
    oklch(0.62, 0.15, 315), // 10 magenta
    oklch(0.62, 0.15, 345), // 11 pink/rose
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
  static final categoryPalette12Light = [
    oklch(0.540, 0.150, 15), // 0  red          #B54152  4.66:1
    oklch(0.535, 0.150, 45), // 1  orange       #B04907  4.68:1
    oklch(0.525, 0.110, 75), // 2  amber        #8F5F02  4.68:1
    oklch(0.520, 0.110, 105), // 3  yellow-green #736C01  4.63:1
    oklch(0.510, 0.145, 135), // 4  green        #3E7709  4.65:1
    oklch(0.510, 0.105, 165), // 5  teal         #097957  4.63:1
    oklch(0.510, 0.085, 195), // 6  cyan         #0A7575  4.69:1
    oklch(0.515, 0.095, 225), // 7  sky blue     #0B7290  4.66:1
    oklch(0.525, 0.150, 255), // 8  blue         #206ABE  4.63:1
    oklch(0.535, 0.150, 285), // 9  violet       #675CBF  4.63:1
    oklch(0.540, 0.150, 315), // 10 magenta      #8F4FA9  4.64:1
    oklch(0.540, 0.150, 345), // 11 pink/rose    #A84482  4.68:1
  ];

  // Ink — dark-mode surface ramp. Derived the same way as every other ramp
  // here (deliberate OKLCH triples, not an inversion or auto-darken of the
  // light values), per docs/DECISIONS.md's Pre-Phase 3 entry.
  //
  // Hue stays at 90 — the same warm neutral as the `sand` ramp — so dark
  // mode reads as the same product in low light rather than a generic grey
  // theme. Chroma is deliberately tiny (0.008–0.012) and *rises* slightly
  // with lightness: at very low L a neutral needs almost no chroma to read
  // as warm, and pushing it higher makes dark surfaces look muddy/brown.
  // Lightness steps are uneven on purpose (0.185 → 0.225 → 0.285 → 0.360):
  // perceived separation between near-black surfaces compresses, so equal
  // steps would make the darkest pair indistinguishable on a real screen.
  // **2026-09-12 — re-anchored from two directly-specified values.** The
  // body color was given as #121110 and the zone/card surface as #171615;
  // converted back through this file's own pipeline they are
  // oklch(0.178, 0.0026, 67.7) and oklch(0.201, 0.0025, 67.7). Two things
  // changed versus the previous ramp: everything got slightly darker, and
  // chroma dropped roughly 3x (0.008 -> 0.0026), so dark mode now reads as
  // a near-neutral charcoal rather than a warm brown-grey. Hue moved 90 ->
  // 67.7 to match, which at this chroma is barely perceptible on its own
  // but keeps the ramp internally consistent.
  //
  // The two given anchors set the first step (0.178 -> 0.201, a deliberate
  // 0.023); the steps above them widen (0.031, 0.038) for the same reason
  // the old ramp's did — perceived separation between near-black surfaces
  // compresses, so equal steps would make the darkest pairs
  // indistinguishable on a real screen.
  //
  // Verified rather than assumed: on the new (darker) body, primary text
  // measures 15.83:1 and secondary 7.61:1 (both slightly BETTER than the
  // old ramp's 15.63/7.52), and every dark category swatch still clears AA
  // at 4.79:1 or above. See test/core/tokens/palette_contrast_test.dart.
  static final ink900 = oklch(0.178, 0.0026, 67.7); // #121110 body/base
  static final ink800 = oklch(0.201, 0.0025, 67.7); // #171615 zone/card
  static final ink700 = oklch(0.232, 0.0026, 67.7); // #1E1D1C raised panel
  static final ink600 = oklch(0.330, 0.0026, 67.7); // #363534 border/hairline

  /// The floating-overlay surface (nav + its adjacent day-strip pane) —
  /// the lightest step in the dark ramp, one above [ink700]. Its own rung
  /// rather than a reuse of [ink600]: that value is the hairline/border
  /// tone and is deliberately lighter than any surface should be.
  static final ink650 = oklch(0.270, 0.0026, 67.7); // #272625 nav/overlay

  // Dark-mode form-field fills — the counterparts to surface2/surface3.
  // They sit ABOVE `ink700` (the raised panel a field lives inside), which
  // inverts light mode's direction: on a white pane a field reads as a
  // darker inset, but on a near-black panel the same "inset" has to get
  // LIGHTER to stay visible at all. Chroma follows the ink ramp's warm 90°
  // rather than the light ramp's zero, so fields belong to the surface
  // they're on instead of reading as neutral patches on a warm panel.
  static final inkField = oklch(0.330, 0.011, 90); // field, at rest
  static final inkFieldActive = oklch(0.395, 0.012, 90); // field, active

  // Sand additions for dark-mode text. Not reusing `sand50`/`sand500`: on a
  // near-black surface `sand50` is bright enough to bloom/halo, and
  // `sand500` doesn't clear comfortable secondary-text contrast. These two
  // are tuned against `ink900` specifically — 15.6:1 and 7.5:1, both past
  // WCAG AA.
  static final sand200 = oklch(0.940, 0.008, 90); // dark-mode primary text
  static final sand400 = oklch(0.720, 0.018, 90); // dark-mode secondary text
  // **2026-09-12 — dark-mode counterpart to slate400 (light).** Zone names
  // needed to read as "even subtler" than secondary text in BOTH themes,
  // not just light. Solved against the current (re-anchored) `ink900`
  // base for ~3.4:1 — matching light's own slate400 (3.35:1) as closely
  // as the two ramps' different chroma/hue allow, rather than chasing an
  // identical ratio.
  static final sand350 = oklch(0.520, 0.018, 90); // dark-mode tertiary, 3.43:1

  // Zone background — a light, low-chroma "this is Zone territory"
  // rendering-only backdrop for the Spatial Task View (Timeline), NOT a
  // category/task color. Deliberately distinct in hue from every existing
  // signal on that screen so it never reads as a category or a status:
  // hue 240 sits apart from all 4 built-in category hues (clay 32, ochre
  // 153, periwinkle 216, berry 300) and from `colorFreeWindow`'s neutral
  // (zero-chroma) sand tone — a viewer can't mistake a zone block for a
  // category tint or a free-window gap indicator. Chroma is intentionally
  // very low (0.02, versus 0.055-0.075 for the pale category tints) so it
  // sits visually "behind" and beneath every other color on the screen,
  // never competing with a task capsule for attention. Confirmed with the
  // user directly (cool blue-grey over a zero-chroma neutral) before
  // building — flagged per the work order's own instruction, not treated
  // as a small enough choice to decide silently.
  //
  // Dark variant follows the same "hue 240, very low chroma" family rather
  // than the `ink` ramp's own warm 90° hue — a zone block needs to read as
  // the same kind of thing in both palettes, not blend into dark mode's
  // neutral surface ramp.
  static final zoneBackground = oklch(0.97, 0.02, 240);
  static final zoneBackgroundDark = oklch(0.28, 0.02, 240);

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Color(0x00000000);
}
