import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';

/// A thin gradient overlay pinned at the top OR bottom edge of a
/// scrollable area, fading from [color] to transparent — so content
/// scrolling underneath a fixed heading (or above a fixed footer)
/// disappears smoothly instead of hitting a hard visual edge.
///
/// Requested directly for the Timeline first ("give gradient of the
/// color of bg to create that effect of content smoothly fading...so
/// there is not a hard line when content scrolls underneath"), then
/// again when it turned out to be missing everywhere else a fixed
/// heading sits above scrolling content: "cant see that 'shade' top on
/// headers (inbox, tracked..) and modal headers." A bottom-edge variant
/// was added the same way, requested directly: "use same at the
/// bottom" — every surface with a top fade got a mirrored bottom one.
/// Extracted into one shared widget rather than copy-pasted per surface
/// (and per edge), so every one of these stays visually and
/// behaviourally identical instead of slowly drifting apart.
///
/// [color] is the surface it fades FROM — different per surface
/// (`colorSurfaceTimeline` for the Timeline, Inbox, and Tracked,
/// `colorSurfaceBase` for a sheet), since each one paints over a
/// different background and a mismatched fade colour would read as a
/// visible tint rather than a seamless disappearance.
///
/// Always [IgnorePointer]-wrapped: purely decorative, must never
/// intercept a tap or drag meant for whatever's scrolled underneath it.
/// The caller is responsible for positioning this as a `Stack` sibling of
/// the scrollable content, at the edge it's meant to fade against — this
/// widget only draws the fade, it doesn't know its own layout context.
class AppTopScrollFade extends StatelessWidget {
  const AppTopScrollFade({
    super.key,
    required this.color,
    this.height,
    this.fromBottom = false,
  });

  final Color color;

  /// Defaults to `spacingXl * 2` — the fade's own visual height,
  /// deliberately UN-linked from [AmbleTheme.spacingContentTop] (the
  /// separate value every surface's own content-TOP-PADDING uses).
  /// Reported directly after they were briefly locked together: the fade
  /// read as too short, especially on the Timeline, once its height
  /// dropped to match the smaller 30px padding value. The two now vary
  /// independently on purpose — the fade can visually extend well past
  /// where the content padding ends, since it's the same colour as the
  /// surface underneath and reads as one continuous background there,
  /// not a hard second edge.
  final double? height;

  /// False (default) fades from [color] at the TOP down to transparent —
  /// the original top-edge shape. True flips the gradient so [color]
  /// sits at the BOTTOM instead, fading to transparent going up — for a
  /// mirrored fade at a scrollable's bottom edge. The caller still
  /// positions this widget itself (top: 0 vs. bottom: 0); this only
  /// controls which end of the gradient carries the solid colour.
  final bool fromBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return IgnorePointer(
      child: SizedBox(
        height: height ?? theme.spacingXl * 2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fromBottom ? Alignment.bottomCenter : Alignment.topCenter,
              end: fromBottom ? Alignment.topCenter : Alignment.bottomCenter,
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}
