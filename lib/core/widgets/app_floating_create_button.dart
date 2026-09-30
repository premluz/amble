import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_dock_primitives.dart';
import 'app_page_toolbar.dart';

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
    this.visible = true,
    this.toolbarOrder = 0,
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

  /// False submerges the button — it swells, then shrinks away while
  /// fading (e.g. while voice mode covers the page); true again springs it
  /// back: larger, smaller, actual.
  final bool visible;

  /// Its place among the page's toolbar buttons, for the stagger as the
  /// page changes (see `AppPageToolbarGate.order`).
  final int toolbarOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    return Positioned(
      right: theme.spacingMd,
      bottom: theme.spacingBottomClearance,
      child: SafeArea(
        top: false,
        child: IgnorePointer(
          ignoring: onPressed == null || !visible,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: theme.motionFast,
            curve: theme.curveStandard,
            // The same dock pane keeps this control aligned with the other
            // controls in [AppBottomDock]'s bottom row. The
            // shared pane and icon-button composition provide the same
            // neutral surface and sizing.
            // Held in place while its page slides: it submerges as the
            // page leaves and springs back in as it arrives, like the Day
            // dock's buttons.
            child: AppPageToolbarItem(
              visible: visible,
              order: toolbarOrder,
              child: AppDockPane(
                theme: theme,
                children: [
                  AppDockIconButton(
                    theme: theme,
                    icon: Icons.add_rounded,
                    tooltip: 'Add',
                    selected: false,
                    onTap: onPressed,
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
