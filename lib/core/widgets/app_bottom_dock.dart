import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import '../tokens/what_matters_tokens.dart';
import '../haptics.dart';
import 'app_context_dock.dart';
import 'app_shell_chrome.dart';

export 'app_dock_primitives.dart';

/// Which of the dock's four entries is currently active — List/Timeline are
/// mutually exclusive (they're the same `zoneViewEnabled` axis, just
/// surfaced here as two explicit buttons instead of one toggle); Edit opens
/// a separate screen rather than being a display state of this dock at
/// all, so it never appears "selected." What Matters is an independent
/// on/off lens layered on top of whichever of List/Timeline is active.
enum AppBottomDockView { list, timeline }

/// The Day screen's own contextual control dock — "List · Timeline · Edit ·
/// What Matters" — requested directly as part of the nav redesign's bottom
/// half: **"Bottom: choose how to work with your day."** A floating,
/// fully-rounded pane, deliberately separate from [AppFloatingCreateButton]
/// (which stays independently positioned, per that widget's own doc
/// comment) rather than welding the "+" back into this bar.
///
/// Reuses the SAME visual language the old bottom nav pill used before the
/// top-nav restructure (`colorSurfaceOverlay` fill, `shadowPane` in light
/// mode, a true stadium shape) — this dock inherits that pane's job of
/// being the floating, always-reachable control surface at the bottom of
/// the Day screen, just with different contents and confirmed scope
/// (Day-only; Tracked/Inbox/Settings have no dock of their own).
///
/// **List and Timeline are the existing `zoneViewEnabled` toggle**, not new
/// display modes — confirmed directly: "List is non-spatial zone view / the
/// other is spatial list." These two buttons are an explicit version of
/// what tap-again-on-Day and `AppCalendarHeader`'s own switcher button
/// already do; this dock doesn't introduce new rendering logic for them.
///
/// **Edit** pushes the same `ZoneGridScreen` route the calendar header's
/// pen icon already opens (confirmed directly — no new behavior).
///
/// **What Matters** is a persistent toggle (confirmed directly, over an
/// enter/exit mode like Edit) reaching [WhatMattersEnabledSetting] — see
/// that provider's own doc comment for what "hides" means here.
///
/// **2026-09-20 — three separate floating pills, not one group of four.**
/// Reported directly against a reference screenshot: "Grouped are first 2
/// (views switch exclusive select)... Edit and Favourite should be
/// separate buttons not all grouped." List/Timeline share ONE pane (an
/// exclusive-select pair, since they're two faces of the same
/// `zoneViewEnabled` toggle); Edit and What Matters each get their OWN
/// standalone pane — visually distinct from the exclusive-select pair,
/// since neither is part of that same either/or choice.
class AppBottomDock extends StatelessWidget {
  const AppBottomDock({
    super.key,
    required this.activeView,
    required this.onSelectView,
    required this.onEditTap,
    required this.whatMattersEnabled,
    required this.onWhatMattersTap,
    this.visible = true,
    this.configurationOverride,
  });

  final AppBottomDockView activeView;
  final ValueChanged<AppBottomDockView> onSelectView;
  final VoidCallback onEditTap;
  final bool whatMattersEnabled;
  final VoidCallback onWhatMattersTap;
  final bool visible;
  final AppContextDockConfiguration? configurationOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final chrome = AppShellChromeScope.maybeOf(context);
    // Inline creation sheets live below the shell in paint order. Suppress
    // chrome immediately; an animated empty configuration still paints exits.
    if (chrome?.dockObscured == true) return const SizedBox.shrink();
    final inheritedOverride = chrome?.configuration;
    final mattersBackground = whatMattersEnabled
        ? Color.alphaBlend(
            theme.colorAccent.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? WhatMattersTokens.buttonAlphaDark
                  : WhatMattersTokens.buttonAlphaLight,
            ),
            theme.colorSurfaceOverlay,
          )
        : null;

    return AppContextDock(
      theme: theme,
      configuration: configurationOverride ?? inheritedOverride ?? AppContextDockConfiguration(
        stateId: 'day',
        groups: visible
            ? [
                AppContextGroup(
                  id: 'context-navigation',
                  actions: [
                    AppContextAction(
                      id: 'day-list',
              icon: Icons.view_agenda_outlined,
              tooltip: 'List',
              selected: activeView == AppBottomDockView.list,
                      onPressed: () => onSelectView(AppBottomDockView.list),
            ),
                    AppContextAction(
                      id: 'day-timeline',
              icon: Icons.view_timeline_outlined,
              tooltip: 'Timeline',
              selected: activeView == AppBottomDockView.timeline,
                      onPressed: () => onSelectView(AppBottomDockView.timeline),
            ),
          ],
        ),
                AppContextGroup(
                  id: 'day-edit',
                  actions: [
                    AppContextAction(
                      id: 'day-edit',
              icon: Icons.edit_outlined,
              tooltip: 'Edit Day',
                      onPressed: onEditTap,
            ),
          ],
        ),
                AppContextGroup(
                  id: 'day-matters',
                  backgroundColor: mattersBackground,
                  actions: [
                    AppContextAction(
                      id: 'day-what-matters',
              icon: Icons.favorite_border_rounded,
              tooltip: 'What Matters',
              selected: whatMattersEnabled,
                      haptic: AmbleHaptic.lift,
                      onPressed: onWhatMattersTap,
            ),
          ],
        ),
              ]
            : const [],
      ),
    );
  }
}
