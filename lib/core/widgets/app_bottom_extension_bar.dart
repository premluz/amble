import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_icon_button.dart';

/// The shared chrome for a bar that sits directly above the bottom nav,
/// as its own adjacent surface — the shape [DayStrip] established for the
/// Timeline (day-navigation strip + create button), reused unchanged for
/// the Inbox (Tasks/Templates switch + create button) and the Tracked tab
/// (create button alone), so a "+" button always sits at the exact same
/// screen position across every tab rather than shifting per screen.
///
/// Requested directly: "this 'extended' nav and adjacent 'functional'
/// sheet would have rounded top corners same rounding as sliding in
/// sheets" — [AmbleTheme.radiusModal] is the same token [AppSheet] uses
/// for its own top corners, so a sheet opened from this bar reads as a
/// continuation of the same surface language, not a different one.
///
/// [leading] is the scrollable/selectable content (a day strip, a tab
/// switcher) that takes the remaining width; [onCreatePressed] is always
/// the trailing "+", in the same slot [DayStrip]'s create button already
/// occupies.
class AppBottomExtensionBar extends StatelessWidget {
  const AppBottomExtensionBar({
    super.key,
    required this.leading,
    required this.onCreatePressed,
  });

  final Widget leading;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    // Part of the same floating unit as the bottom nav directly below,
    // not a slab welded to the screen edge: same `colorSurfaceOverlay`
    // fill, same `radiusXl` corners, rounded on ALL four sides. Requested
    // directly — "not just nav.. the entire pane 'nav + adjacent rounded
    // pane (with calendar)'". No border on either half, also per direct
    // request; in dark mode the overlay surface is already the lightest
    // step in the ramp, which is what separates it from the page without
    // one being drawn.
    return Padding(
      // The same side insets and inter-pane gap the nav below uses, owned
      // here rather than repeated at all three call sites (Timeline,
      // Inbox, Tracked) — so the two panes line up as one stacked unit on
      // every tab without each screen having to know the measurements.
      // No bottom gap: this pane and the nav directly below it are one
      // connected object, so nothing separates them. Requested directly —
      // "this should be connected visually as one connected pane, no gap
      // between."
      padding: EdgeInsets.symmetric(horizontal: theme.spacingMd),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorSurfaceOverlay,
          // TOP corners only — the nav below rounds its own bottom pair,
          // so the two halves meet on a shared square seam and read as a
          // single pane rather than two stacked pills.
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.radiusXl),
          ),
          // No shadow of its own: `shadowPane` offsets DOWNWARD (+2y), so
          // this half would cast onto the nav directly beneath it and draw
          // a visible seam through the middle of what is meant to read as
          // one object. The nav below carries the shadow for the whole
          // unit.
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.radiusXl),
          ),
          child: SafeArea(
            top: false,
            // The nav pane below now owns the bottom SafeArea inset for the
            // whole stacked unit — this half must not add a second one, or
            // the two panes separate by the inset's height.
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacingMd,
                vertical: theme.spacingSm,
              ),
              child: Row(
                children: [
                  Expanded(child: leading),
                  SizedBox(width: theme.spacingSm),
                  AppIconButton(
                    icon: Icons.add_rounded,
                    onPressed: onCreatePressed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
