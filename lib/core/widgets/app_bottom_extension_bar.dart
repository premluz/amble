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

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(theme.radiusModal),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorSurfacePrimary,
          // A subtle shadow on the TOP edge only, separating this bar
          // from the content scrolling underneath it — mirrors the bottom
          // nav bar's own relationship with the screen above it, just
          // flipped to the top of this bar. Same shape [DayStrip]
          // originated this from.
          boxShadow: [
            BoxShadow(
              color: theme.shadowPane.first.color,
              blurRadius: theme.shadowPane.first.blurRadius,
              offset: Offset(
                theme.shadowPane.first.offset.dx,
                -theme.shadowPane.first.offset.dy,
              ),
              spreadRadius: theme.shadowPane.first.spreadRadius,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
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
    );
  }
}
