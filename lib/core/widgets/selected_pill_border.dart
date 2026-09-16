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
  ///
  /// Null for a caller whose fill isn't a flat colour at all: the
  /// quick-create draft's rail is a blurred `GlassPillSurface`, which it
  /// passes as [child] and paints itself. This widget then contributes
  /// only its two rings, leaving that glass fully visible underneath.
  final Color? fillColor;

  /// The pill's content (e.g. its title) — painted on top of [fillColor],
  /// inside both rings.
  final Widget child;

  /// The accent ring's own stroke width — thinner than the un-separated
  /// single-ring treatment this replaces (`borderWidthHairline * 2`),
  /// since the dark separator ring now does the work of standing out from
  /// the pill fill; the accent ring only needs to read as a hairline.
  static double accentWidth(AmbleTheme theme) => theme.borderWidthHairline;

  /// The dark separator ring's stroke width — `borderWidthHairline * 2`
  /// (4px in this theme), thicker than [accentWidth]. Bumped up twice,
  /// directly: first to `* 1.5` (3px) after the soft inner-shadow
  /// gradient beside it was removed (a separate fix, for a real
  /// circular-artifact bug on tall pills — the gradient never changed
  /// this SOLID line's own numbers, but it was adding visual weight that
  /// made the line read as more present than it measured), then to `* 2`
  /// ("slight more thicken inner solid line") once 3px still read as
  /// thin.
  static double separatorWidth(AmbleTheme theme) =>
      theme.borderWidthHairline * 2;

  static BorderRadius _inset(BorderRadius radius, double by) {
    return BorderRadius.only(
      topLeft: Radius.circular((radius.topLeft.x - by).clamp(0.0, double.infinity)),
      topRight: Radius.circular((radius.topRight.x - by).clamp(0.0, double.infinity)),
      bottomLeft: Radius.circular((radius.bottomLeft.x - by).clamp(0.0, double.infinity)),
      bottomRight: Radius.circular((radius.bottomRight.x - by).clamp(0.0, double.infinity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentWidth(theme);
    final separator = separatorWidth(theme);
    final scrimRadius = _inset(contentRadius, accent);
    final fillRadius = _inset(scrimRadius, separator);

    // Both rings are painted as OVERLAYS in a `Stack`, not as `Padding`
    // that shrinks the content — reported directly: "that added inner
    // border... should not affect inner content, at the moment pushes it
    // a bit." `Padding` was consuming `accent + separator` px of the
    // box's own layout space, so the icon/emoji inside sat progressively
    // smaller/more centered than its unselected counterpart. `Positioned
    // .fill` + `IgnorePointer` paints each ring on top of the full-size
    // fill instead, so [child] keeps the box's REAL size regardless of
    // whether it's selected.
    //
    // A soft inner-shadow gradient used to sit inside the solid ring too,
    // for extra separation — removed (confirmed directly) once measured:
    // `RadialGradient.radius` scales to a box's SHORTER side by Flutter's
    // own convention, so on a tall, narrow pill (e.g. 24x90) it rendered
    // as a circular blob roughly centered in the box rather than shading
    // that followed the pill's actual rounded-rect edges — reported
    // directly as "something circular appears in middle, shouldn't be."
    // The single solid separator line was already confirmed correct on
    // its own ("one inner solid line is fine separating blue from bg
    // pill").
    return Stack(
      children: [
        // Skipped entirely when [fillColor] is null — the caller is
        // painting its own fill inside [child] instead, and a flat colour
        // underneath would either be invisible or (for a translucent one)
        // muddy it. `PendingTaskPill` does exactly this: its fill is a
        // blurred `GlassPillSurface`, which has no single colour to hand
        // over here.
        if (fillColor != null)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: fillRadius,
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScrim, width: separator),
                borderRadius: scrimRadius,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorAccent, width: accent),
                borderRadius: contentRadius,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
