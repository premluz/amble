import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// Wraps a selected task/zone pill with the shared two-ring selection
/// treatment: a thin accent-colored outer ring, separated from the pill's
/// own fill by a thin, ALWAYS-dark inner ring.
///
/// Requested directly: "the blue selected border should be thinner and
/// have inner dark bg color inner border (hard inner glow/shadow of 1-2px),
/// that makes the effect of separation of blue 'active border' from the
/// pill color in case pill color is also blue." A single accent ring reads
/// fine against most category colors, but disappears into a pill that
/// happens to already be blue — the dark separator ring is what keeps the
/// selection visible regardless of the pill's own color, both for zones
/// and tasks.
///
/// The separator uses [AmbleTheme.colorScrim] rather than a surface
/// token — it's the one color in this theme that's fixed dark in BOTH
/// light and dark mode (every surface token flips with theme), which is
/// what "inner dark" actually needs: a ring that reads as a shadow/gap
/// regardless of which theme or which pill color sits behind it, not a
/// literal near-black that would look wrong composited over a light-theme
/// pill on its own.
///
/// A plain [BoxDecoration] can't express two concentric rings at different
/// widths and colors in one layer — [Border] paints a single stroke — so
/// this nests boxes rather than trying to fold both into one
/// `BoxDecoration`. Callers that need to keep their own sizing/animation
/// contract intact (an `AnimatedContainer` with a fixed `width`/`height`)
/// apply this OUTSIDE that container as a wrapper, not by handing it their
/// decoration to extend — see `TaskCapsuleBlock`'s own hand-nested copy of
/// this same shape for that case.
///
/// [fillColor] and [contentRadius] are taken here — NOT a pre-decorated
/// `child` — deliberately: this widget owns the ONE consistent radius the
/// fill and both rings share. A first version took an already-decorated
/// child painted at the CALLER's own (larger, non-concentric) radius; with
/// no inset between the scrim ring and that fill, the fill's own corner
/// curve peeked out past the scrim ring's stroke at each corner, reading
/// as a third, lighter ring — reported directly: "apart from that solid
/// 1px bg color inner, which is correct, there is lighter one more inner
/// which should not be there (transparent or lighter gray)."
class SelectedPillBorder extends StatelessWidget {
  const SelectedPillBorder({
    super.key,
    required this.theme,
    required this.contentRadius,
    required this.fillColor,
    required this.child,
  });

  final AmbleTheme theme;

  /// The pill's UNSELECTED radius — the two rings nest inward from this,
  /// each shrinking it by their own stroke width so every layer's corner
  /// stays concentric with the others.
  final BorderRadius contentRadius;

  /// The pill's own fill, painted by this widget at the correctly-inset
  /// radius — not by the caller's own separate decoration, which is what
  /// caused the mismatched corners above.
  final Color fillColor;

  /// The pill's content (e.g. its title) — painted on top of [fillColor],
  /// inside both rings.
  final Widget child;

  /// The accent ring's own stroke width — thinner than the un-separated
  /// single-ring treatment this replaces (`borderWidthHairline * 2`),
  /// since the dark separator ring now does the work of standing out from
  /// the pill fill; the accent ring only needs to read as a hairline.
  static double accentWidth(AmbleTheme theme) => theme.borderWidthHairline;

  /// The dark separator ring's stroke width — 1-2px per the direct
  /// request ("hard inner glow/shadow of 1-2px"). `borderWidthHairline`
  /// (2px in this theme) sits at the top of that range rather than the
  /// bottom, so the separation reads clearly rather than as a hairline
  /// that could disappear at a lower device pixel ratio.
  static double separatorWidth(AmbleTheme theme) => theme.borderWidthHairline;

  static BorderRadius _inset(BorderRadius radius, double by) {
    return BorderRadius.only(
      topLeft: Radius.circular((radius.topLeft.x - by).clamp(0.0, double.infinity)),
      topRight: Radius.circular((radius.topRight.x - by).clamp(0.0, double.infinity)),
      bottomLeft: Radius.circular((radius.bottomLeft.x - by).clamp(0.0, double.infinity)),
      bottomRight: Radius.circular((radius.bottomRight.x - by).clamp(0.0, double.infinity)),
    );
  }

  /// How far in from the edge the soft inner shadow starts, as a fraction
  /// of the pill's own radius — the rest of the falloff runs to the edge.
  /// Confirmed directly: the solid separator alone is right ("one inner
  /// solid line is fine separating blue from bg pill") but a softer, more
  /// transparent shadow belongs inside it too ("we still have one more
  /// inner dark softer/transparent something"). That soft ring previously
  /// existed only as a PAINT ARTIFACT — `TaskCapsuleBlock`'s hand-nested
  /// copy set `color:` and `border:` in one `BoxDecoration`, so the fill
  /// bled through the 40%-alpha scrim and blended it. It is now drawn
  /// deliberately, once, here.
  static const double innerShadowStop = 0.72;

  /// The inner shadow's strength, as a fraction of [AmbleTheme.colorScrim]'s
  /// own alpha — softer than the solid separator ring by design.
  static const double innerShadowStrength = 0.55;

  @override
  Widget build(BuildContext context) {
    final accent = accentWidth(theme);
    final separator = separatorWidth(theme);
    final scrimRadius = _inset(contentRadius, accent);
    final fillRadius = _inset(scrimRadius, separator);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorAccent, width: accent),
        borderRadius: contentRadius,
      ),
      child: Padding(
        padding: EdgeInsets.all(accent),
        child: DecoratedBox(
          // The SOLID separator. Its own layer, carrying no `color:` of
          // its own — see [innerShadowExtent] for why that separation
          // matters (a fill here would bleed through this 40%-alpha
          // stroke and soften it into the wrong kind of ring).
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScrim, width: separator),
            borderRadius: scrimRadius,
          ),
          child: Padding(
            padding: EdgeInsets.all(separator),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: fillRadius,
              ),
              // The SOFT inner shadow, over the fill and inside the solid
              // ring. An inset shadow isn't expressible in `BoxDecoration`
              // (`boxShadow` only casts outward), so it's a gradient from
              // the scrim color at the edge to fully transparent a few px
              // in — which is what an inner shadow is. `IgnorePointer` so
              // this purely decorative layer never intercepts a gesture
              // meant for the content beneath it.
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: fillRadius,
                          gradient: RadialGradient(
                            radius: 0.85,
                            colors: [
                              const Color(0x00000000),
                              theme.colorScrim.withValues(
                                alpha: theme.colorScrim.a * innerShadowStrength,
                              ),
                            ],
                            stops: const [innerShadowStop, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
