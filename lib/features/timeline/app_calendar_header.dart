// The utility icon row (Today / Sync / zone-view switcher / Edit) is
// commented out rather than deleted — requested directly: "keep for now
// but remove from view / comment out," since `AppBottomDock` now carries
// equivalents. These ignores keep the analyzer quiet about the pieces
// that are consequently unreferenced BUT deliberately retained, so
// restoring the row stays a single uncomment. Remove this line if the
// row is ever genuinely deleted.
// ignore_for_file: unused_import, unused_element, unused_local_variable

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_date_accordion.dart';
import '../../shared/providers/preferences_providers.dart';
import '../zone_grid/zone_grid_screen.dart';
import 'date_accordion_expanded_provider.dart';
import 'edit_mode_provider.dart';
import 'selected_date_provider.dart';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Replaces the bottom day-strip entirely — requested directly, with a
/// reference screenshot: the calendar (date label, week-of-dates grid,
/// sync placeholder, "jump to today" button, Edit Mode toggle) moves to
/// the TOP of the screen, shared by both the Task-view and Timeline
/// (Zone-view) tabs, in place of the old bottom-nav-adjacent day strip and
/// its own separate Edit Mode link.
///
/// The date label/week-grid half is [AppDateAccordion] — requested
/// directly to extract as its own standalone, reusable component (see
/// that widget's own doc comment for the accordion behaviour: collapsed
/// by default, tap the chevron to reveal the week strip). This widget
/// just places it alongside the row of utility icons (Today/sync/
/// zone-switcher/Edit Mode).
///
/// Icons are "very subtle outline" per direct reference, not the app's
/// filled-accent primary circle style (that reads as a primary action;
/// these three are secondary utility controls) — `AppButton`'s circle
/// shape with `AppButtonVariant.secondary` (`core/widgets/app_button.dart`),
/// promoted out of this file 2026-09-12 (as the now-retired
/// `AppSubtleIconButton`) so the Tracked tab's own view-cycle switcher
/// could use the identical style.
///
/// **While Edit Mode is active**, this widget collapses to just the date
/// accordion plus the Edit Mode toggle itself (now showing a close/X
/// glyph) — the other utility icons (Today/sync/zone-switcher) hide, but
/// the date accordion stays reachable so the day being edited can still
/// be changed. Requested directly ("on edit task mode, we should still
/// have that comp"), reversing an earlier pass that hid this whole
/// header (including its date controls) the instant Edit Mode turned on.
class AppCalendarHeader extends ConsumerWidget {
  const AppCalendarHeader({super.key, this.showCloseButton = true});

  /// Whether the Edit-Mode-collapsed branch renders its own close (X)
  /// toggle. Defaults true (the Day screen's own usage, unaffected).
  /// `ZoneGridScreen`'s Tasks tab passes `false` — that screen has its
  /// OWN Close button in its bottom dock, and a second one here would be
  /// a duplicate close control. Has no effect outside Edit Mode (the
  /// normal-mode branch never rendered this button in the first place).
  final bool showCloseButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final editModeEnabled = ref.watch(editModeEnabledProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    // **2026-09-20 — shared across every AppCalendarHeader mount.**
    // Requested directly: "the calendar opened state should persist
    // across views... if days opened on timeline view they should
    // remain open on edit mode... and both spatial and non-spatial
    // view." See `DateAccordionExpanded`'s own doc comment for why this
    // moved off `AppDateAccordion`'s internal `State`.
    final accordionExpanded = ref.watch(dateAccordionExpandedProvider);

    // **2026-09-20 — the date accordion stays visible in Edit Mode too.**
    // Requested directly: "on edit task mode, we should still have that
    // comp" (the new [AppDateAccordion]). Reverses the 2026-09-12 rule
    // that collapsed this whole header down to JUST the Edit Mode toggle
    // — the accordion is compact enough now (one line collapsed) that
    // there's no longer a real reason to hide it, and being able to
    // change days while editing is worth keeping. The utility icon row
    // (Today/sync/zone-switcher) still hides — those are ordinary-mode
    // actions, not date navigation.
    if (editModeEnabled) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          theme.spacingScreenPadding,
          theme.spacingSm,
          theme.spacingScreenPadding,
          theme.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // **2026-09-20 — Today button removed from Edit Mode again.**
            // Requested directly: "on edit task we show button with
            // number 'today's day' that resets to current day, this
            // button should not be there." Reverses the immediately
            // prior "Today restored in Edit Mode" change from earlier
            // this same session. With no button left in this row and
            // `showCloseButton` now often false too (the merged Edit
            // screen's Tasks tab), the whole `Row` + its own trailing
            // gap would otherwise survive as an empty "larger pane"
            // above the accordion — also flagged directly — so both are
            // gone together, not just the button.
            if (showCloseButton) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  _EditModeIconButton(theme: theme),
                ],
              ),
              SizedBox(height: theme.spacingSm),
            ],
            // Full width, not squeezed beside the icon row above — see
            // this file's own class doc comment on why the accordion's
            // expanded week strip needs to be a full-width SIBLING of the
            // utility icons, not sharing their Row.
            AppDateAccordion(
              selectedDate: selectedDate,
              onDateSelected: (date) =>
                  ref.read(selectedDateProvider.notifier).goTo(date),
              expanded: accordionExpanded,
              onExpandedChanged: (_) =>
                  ref.read(dateAccordionExpandedProvider.notifier).toggle(),
            ),
          ],
        ),
      );
    }

    // Laid out so the date label lands on exactly the y and x every
    // other page's own title sits at — requested directly: "title of
    // page jumps... the calendar month dropdown should be positioned
    // same place as title of other pages."
    //
    // **2026-09-21 — `spacingMd`, was `spacingLg`.** Requested directly
    // against a side-by-side mock: "slightly less space between the main
    // menu and the calendar." This deliberately breaks the
    // same-y-as-other-page-titles rule above, for this screen only —
    // confirmed via AskUserQuestion over the alternative of moving
    // Inbox/Tracked/Settings up by the same amount to keep all four
    // aligned. Those pages are unchanged; the Day screen's date label now
    // sits slightly higher than their titles.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacingScreenPadding,
        theme.spacingMd,
        theme.spacingScreenPadding,
        theme.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // **2026-09-20 — the whole utility icon row is HIDDEN.**
          // Requested directly: "hide top buttons 20, edit sync, view
          // change, since added them at the bottom / keep for now but
          // remove from view / comment out." Every one of these now has
          // an equivalent in `AppBottomDock` (List/Timeline replace the
          // zone-view switcher, Edit replaces the pen icon) or is a
          // not-yet-wired placeholder (Sync), so showing them here as
          // well was a duplicate control surface. Kept commented rather
          // than deleted, per that same instruction, so restoring any
          // one of them is a single uncomment.
          //
          // Row(
          //   crossAxisAlignment: CrossAxisAlignment.start,
          //   children: [
          //     const Spacer(),
          //     _TodayButton(theme: theme, today: today),
          //     SizedBox(width: theme.spacingSm),
          //     // Sync — placeholder only per direct confirmation
          //     // (device-calendar pull/push is a separate future
          //     // task); tapping currently does nothing.
          //     const AppButton(
          //       icon: Icons.sync_rounded,
          //       shape: AppButtonShape.circle,
          //       variant: AppButtonVariant.secondary,
          //       tooltip: 'Sync',
          //       onPressed: null,
          //     ),
          //     if (FeatureFlags.zoneEnabled) ...[
          //       SizedBox(width: theme.spacingSm),
          //       const _SpatialZoneViewSwitcher(),
          //     ],
          //     SizedBox(width: theme.spacingSm),
          //     _EditModeIconButton(theme: theme),
          //   ],
          // ),
          // SizedBox(height: theme.spacingSm),
          //
          // The date label/chevron/week-strip accordion — extracted as
          // its own reusable widget (`core/widgets/app_date_accordion.dart`,
          // in the Widgetbook gallery), requested directly: "make it
          // actually a component inside our storybook... so we can
          // easily reuse it." Full width now (see this Column's own doc
          // comment above).
          AppDateAccordion(
            selectedDate: selectedDate,
            onDateSelected: (date) =>
                ref.read(selectedDateProvider.notifier).goTo(date),
            expanded: accordionExpanded,
            onExpandedChanged: (_) =>
                ref.read(dateAccordionExpandedProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }
}

/// "Jump to today" — always shows TODAY's own day-of-month (not a fixed
/// "12"; confirmed directly the reference screenshot's literal "12" was
/// just whatever day it was rendered on). Tapping navigates the selected
/// date back to today, regardless of which day is currently viewed.
class _TodayButton extends ConsumerWidget {
  const _TodayButton({required this.theme, required this.today});

  final AmbleTheme theme;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppButton(
      shape: AppButtonShape.circle,
      variant: AppButtonVariant.secondary,
      tooltip: 'Today',
      onPressed: () => ref.read(selectedDateProvider.notifier).goToToday(),
      child: Text(
        '${today.day}',
        // textCaptionMono — a day number, not a name.
        style: theme.textCaptionMono.copyWith(
          color: theme.colorTextPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Toggles [ZoneViewEnabledSetting] — the header half of "1 nav item, but
/// when tapped again it switches view... view switch on top similar like
/// Tracked page." Only two states (spatial/Zone), so this is a single
/// switcher button rather than Tracked's own 3-way `.next()` cycle, but
/// otherwise the same shape: one global, `keepAlive`, Hive-persisted
/// setting, an icon reflecting the CURRENT mode, tapped to flip it.
/// `main.dart`'s nav bar reaches the exact same provider when the
/// already-selected Timeline destination is tapped again — this button
/// and that nav-tap are two paths to one state, never two separate ones.
class _SpatialZoneViewSwitcher extends ConsumerWidget {
  const _SpatialZoneViewSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoneViewEnabled = ref.watch(zoneViewEnabledSettingProvider);
    return AppButton(
      // Icon shows the view a tap will switch TO — matching Tracked's own
      // `viewMode.icon` convention (the icon names the destination, not
      // the current state).
      icon: zoneViewEnabled
          ? Icons.view_timeline_outlined
          : Icons.grid_view_rounded,
      shape: AppButtonShape.circle,
      variant: AppButtonVariant.secondary,
      tooltip: zoneViewEnabled ? 'Switch to Task view' : 'Switch to Timeline',
      onPressed: () => ref
          .read(zoneViewEnabledSettingProvider.notifier)
          .set(!zoneViewEnabled),
    );
  }
}

class _EditModeIconButton extends ConsumerWidget {
  const _EditModeIconButton({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(editModeEnabledProvider);
    return AppButton(
      // Reported directly: while Edit Mode is active, the SAME control
      // that opened it becomes its close button — a close (X) glyph, not
      // the pen icon still sitting there with no visible way to exit —
      // styled identically to the other top-right icons (no separate
      // control, no different shape).
      icon: enabled ? Icons.close_rounded : Icons.edit_outlined,
      shape: AppButtonShape.circle,
      variant: AppButtonVariant.secondary,
      tooltip: enabled ? 'Done' : 'Edit',
      // **2026-09-17 — opens the merged Edit screen** (Tasks/Zones tabs)
      // rather than toggling `editModeEnabledProvider` in place. The
      // two-finger long-press gesture (`timeline_screen.dart`) is a
      // SEPARATE, still-unchanged entry point straight into in-place Edit
      // Mode on the plain Timeline — this button no longer duplicates
      // that path, it opens the dedicated screen instead. `enabled` can
      // still be true here from that gesture (or from a resumed
      // navigation), in which case tapping just closes it the same way
      // the long-press itself would.
      onPressed: () => enabled
          ? ref.read(editModeEnabledProvider.notifier).toggle()
          : showEditScreen(context),
      // Accent-colored while active, so the mode still has a persistent
      // visual signal now that it's an icon rather than literal "Done"
      // text — the accent selection border on the tasks themselves is
      // the other half of that signal, per CONSTITUTION.md's Edit Mode
      // section.
      iconColor: enabled ? theme.colorAccent : null,
      borderColor: enabled ? theme.colorAccent : null,
    );
  }
}
