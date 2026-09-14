import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_icon_button.dart';

/// The "+" create button, floating independently above the bottom nav
/// pill — not sharing a pane with it. Replaces the old `AppBottomExtensionBar`
/// (2026-09-12, requested directly from a reference screenshot: "nav is
/// just 5 items + its outside"), which welded the "+" into its own bar
/// stacked directly on the nav. Positioned via a `Stack` at the bottom of
/// each screen's own body, same bottom-right spot on every tab that uses
/// it (Task view/Timeline, Manage, Tracked).
class AppFloatingCreateButton extends StatelessWidget {
  const AppFloatingCreateButton({
    super.key,
    required this.onPressed,
    this.opacity = 1,
  });

  final VoidCallback? onPressed;

  /// Fades the button's own icon without disturbing its `Positioned`
  /// ancestry — added for the Weekly Zone Authoring Grid's drag-to-delete,
  /// where the "+" needs to visually phase out while a zone is being
  /// dragged (mirroring the Timeline's own delete-target fade-in). Wrapping
  /// this WHOLE WIDGET in an external `AnimatedOpacity`/`IgnorePointer`
  /// breaks it — `Positioned` requires a direct `Stack` ancestor, and
  /// neither of those is one — so the fade is applied to the icon here
  /// instead, keeping `Positioned` a direct `Stack` child at all times.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Positioned(
      right: theme.spacingMd,
      bottom: theme.spacingMd,
      child: SafeArea(
        top: false,
        child: IgnorePointer(
          ignoring: onPressed == null,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: theme.motionFast,
            curve: theme.curveStandard,
            child: AppIconButton(
              icon: Icons.add_rounded,
              onPressed: onPressed ?? () {},
            ),
          ),
        ),
      ),
    );
  }
}
