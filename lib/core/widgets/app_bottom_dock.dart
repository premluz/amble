import 'package:flutter/material.dart';

import '../tokens/semantic_theme.dart';
import 'app_button.dart';

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
  });

  final AppBottomDockView activeView;
  final ValueChanged<AppBottomDockView> onSelectView;
  final VoidCallback onEditTap;
  final bool whatMattersEnabled;
  final VoidCallback onWhatMattersTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppDockPane(
          theme: theme,
          children: [
            AppDockIconButton(
              theme: theme,
              icon: Icons.view_agenda_outlined,
              tooltip: 'List',
              selected: activeView == AppBottomDockView.list,
              onTap: () => onSelectView(AppBottomDockView.list),
            ),
            AppDockIconButton(
              theme: theme,
              icon: Icons.view_timeline_outlined,
              tooltip: 'Timeline',
              selected: activeView == AppBottomDockView.timeline,
              onTap: () => onSelectView(AppBottomDockView.timeline),
            ),
          ],
        ),
        SizedBox(width: theme.spacingSm),
        AppDockPane(
          theme: theme,
          children: [
            AppDockIconButton(
              theme: theme,
              icon: Icons.edit_outlined,
              // "Edit Day", not bare "Edit" — `AppCalendarHeader`'s own
              // pen icon already uses tooltip "Edit" for the identical
              // action (both open the same `ZoneGridScreen` route); two
              // simultaneously-mounted controls sharing one tooltip text
              // is ambiguous for screen readers and for `find.byTooltip`
              // in tests, so this one gets a distinct label even though
              // it does the same thing.
              tooltip: 'Edit Day',
              selected: false,
              onTap: onEditTap,
            ),
          ],
        ),
        SizedBox(width: theme.spacingSm),
        AppDockPane(
          theme: theme,
          children: [
            AppDockIconButton(
              theme: theme,
              icon: Icons.favorite_border_rounded,
              tooltip: 'What Matters',
              selected: whatMattersEnabled,
              onTap: onWhatMattersTap,
            ),
          ],
        ),
      ],
    );
  }
}

/// One floating, fully-rounded pane — the same visual language the old
/// bottom nav pill used before the top-nav restructure
/// (`colorSurfaceOverlay` fill, `shadowPane` in light mode, a true
/// stadium shape). [AppBottomDock] renders three of these side by side
/// rather than one pane holding all four buttons — see that widget's own
/// doc comment for why.
///
/// Promoted out of this file (2026-09-20, was private `_DockPane`) so
/// other screens' own bottom docks can share the identical pane styling
/// instead of each re-implementing it — the Tracked screen's own
/// view-mode switcher (`AppTrackedViewDock`) was the second call site
/// that prompted this, per docs/DECISIONS.md's "two duplicates accepted,
/// three gets promoted" rule (promoted ahead of a third copy appearing,
/// since the pattern was already about to be reused).
class AppDockPane extends StatelessWidget {
  const AppDockPane({super.key, required this.theme, required this.children});

  final AmbleTheme theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorSurfaceOverlay,
        borderRadius: BorderRadius.circular(999),
        boxShadow: isDark ? null : theme.shadowPane,
      ),
      // **2026-09-23 — equal padding on both axes.** This used to be
      // `horizontal: spacingSm` (8) against `vertical: spacingXs` (4),
      // which made a pane holding a SINGLE button 60x48 — a visible
      // ellipse rather than the round button it reads as. Reported
      // directly, twice: "single buttons should be perfect circle e.g.
      // edit and heart at the moment are ellipse." With both axes at
      // `spacingXs` a one-button pane is 48x48 (the button's own 40 plus
      // 4 either side), so the 999 radius renders a true circle; a
      // multi-button pane is unaffected in shape, just 8px narrower.
      child: Padding(
        padding: EdgeInsets.all(theme.spacingXs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: theme.spacingXs,
          children: children,
        ),
      ),
    );
  }
}

/// One icon button inside an [AppDockPane] — ghost-variant circle, accent
/// color when [selected]. Promoted alongside [AppDockPane] for the same
/// reason — see that widget's own doc comment.
class AppDockIconButton extends StatelessWidget {
  const AppDockIconButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final AmbleTheme theme;
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Horizontal only, and only BETWEEN buttons — a pane holding one
      // button must come out square so its 999 radius renders a true
      // circle rather than an ellipse (see [AppDockPane]'s own padding
      // comment). `EdgeInsets.zero` here would weld a multi-button pane's
      // icons together, so the separation is applied by the Row in
      // [AppDockPane] instead, where it can skip the outer edges.
      padding: EdgeInsets.zero,
      child: AppButton(
        icon: icon,
        shape: AppButtonShape.circle,
        variant: AppButtonVariant.ghost,
        tooltip: tooltip,
        onPressed: onTap,
        iconColor: selected ? theme.colorAccent : theme.colorTextSecondary,
      ),
    );
  }
}
