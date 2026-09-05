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
  static final slate500 = oklch(0.546, 0.013, 252);
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
  static final clayTint = oklch(0.975, 0.075, 36); // health pill (peach)
  static final clay500 = oklch(0.540, 0.150, 32); // health icon
  static final ochreTint = oklch(0.956, 0.060, 153); // work pill (mint)
  static final ochre500 = oklch(0.550, 0.110, 153); // work icon
  static final periwinkleTint = oklch(0.956, 0.055, 218); // personal pill (sky)
  static final periwinkle500 = oklch(0.550, 0.130, 216); // personal icon
  static final berryTint = oklch(0.946, 0.066, 300); // admin pill (lavender)
  static final berry500 = oklch(0.550, 0.140, 300); // admin icon
  // The neutral "no category chosen yet" pair. Zero chroma so it reads as
  // absence of a category rather than a fifth meaning, at the same
  // lightness as the four tints above so it sits in the same family. Icon
  // lightness matches the other *500 icons for equal contrast against its
  // own fill.
  static final neutralTint = oklch(0.956, 0.0, 0); // default pill (grey)
  static final neutral500 = oklch(0.550, 0.0, 0); // default icon

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
  // color, not a tint+icon-color pair like the 4 built-in categories above
  // — simpler, and this palette needs to read the same in both a light and
  // a dark picker sheet without a second dark-specific set.
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
  static final ink900 = oklch(0.185, 0.008, 90); // deepest surface
  static final ink800 = oklch(0.225, 0.009, 90); // timeline canvas
  static final ink700 = oklch(0.285, 0.011, 90); // raised panel
  static final ink600 = oklch(0.360, 0.012, 90); // border/hairline

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
