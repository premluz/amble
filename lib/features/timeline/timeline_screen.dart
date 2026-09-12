import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/feature_flags.dart';
import '../../core/haptics.dart';
import '../../core/haptics_provider.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_floating_create_button.dart';
import '../../core/widgets/app_top_scroll_fade.dart';
import '../../shared/models/category.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/scheduled_block.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/models/zone.dart';
import '../../shared/providers/calendar_providers.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/providers/zone_providers.dart';
import '../../shared/services/cascade_reschedule.dart';
import '../../shared/services/group_reschedule.dart';
import '../../shared/services/overlap_checker.dart';
import '../../shared/services/overlap_cluster.dart';
import '../../shared/services/zone_cascade_reschedule.dart';
import '../../shared/services/zone_containment.dart';
import '../tracked_behavior/behavior_outcome_prompt.dart';
import '../task_detail/task_detail_sheet.dart';
import '../task_detail/task_remove.dart';
import 'app_calendar_header.dart';
import 'collapsed_stack_layout.dart';
import 'current_time_indicator.dart';
import 'armed_edit_task_provider.dart';
import 'edit_mode_delete_target.dart';
import 'edit_mode_provider.dart';
import 'edit_mode_wiggle.dart';
import 'edit_selection_provider.dart';
import 'external_event_block.dart';
import 'external_event_capsule_block.dart';
import 'free_window_block.dart';
import 'overlap_cluster_block.dart';
import '../task_detail/quick_create_sheet_shell.dart';
import 'pending_task_draft_provider.dart';
import 'quick_create_overlay.dart';
import 'pending_task_pill.dart';
import 'place_task_line.dart';
import 'timeline_drag_math.dart';
import 'recently_saved_task_provider.dart';
import 'selected_date_provider.dart';
import 'viewed_time_provider.dart';
import 'task_boundary_markers.dart';
import 'task_capsule_block.dart';
import 'task_edge_time_label.dart';
import 'task_overlap_layout.dart';
import 'two_finger_long_press.dart';
import 'tasks_for_selected_day_provider.dart';
import 'zone_background_block.dart';
import 'zone_day_timeline.dart';
import '../zones/zone_form_screen.dart';

// The visible scroll range used to be a fixed calendar-day window
// (0-24h, previously 6-22h — see docs/ERROR_LOG.md for why that was
// widened). Now computed dynamically per day from the tasks actually
// scheduled, in _DayTimelineState._visibleRange — requested directly, so
// the day only scrolls through the range it actually has content for.
/// The left hour-label column, from the screen padding to where task
/// pills start. Widened from 56 after the labels were reported running
/// under the pills: the widest label ("11:00 AM"/"12:00 PM") measures
/// 57.6 at `textCaption` in JetBrains Mono, so at 56 it overflowed its
/// own right-aligned column and painted straight into the pill column,
/// which begins at exactly this offset. Single-digit hours ("1:00 PM",
/// 50.4) fit at either width, which is why only the 10-12 o'clock labels
/// collided.
const _hourGutterWidth = 72.0;

/// Vertical scale used when the hour gutter is hidden ("Show hour labels"
/// off). Requested directly: with no hour scale on screen, the gaps
/// between tasks reference nothing — they just push a sparse day into a
/// lot of empty scrolling. Collapsed mode drops the gaps entirely and
/// stacks tasks one after another.
///
/// Pill height stays strictly proportional to duration (confirmed via
/// AskUserQuestion over stepped buckets and a dampened curve).
///
/// Derived rather than hand-picked: [TaskCapsuleBlock] floors a pill at
/// its badge size, and the requested anchor is "30 minutes is the circle,
/// an hour is twice that, two hours four times." That fixes the rate at
/// exactly badge ÷ 30. A first pass guessed 0.45 instead, which put the
/// floor at 75 minutes — 30m and 1h rendered identically, defeating the
/// point. Caught by rendering the range and measuring it, not by reading
/// the code.
double _collapsedPixelsPerMinute(AmbleTheme theme) => _pillWidth(theme) / 30;

/// Vertical gap between stacked blocks in collapsed mode. Purely visual
/// separation — it deliberately carries no time meaning, unlike the real
/// timeline's gaps.
///
/// Reduced from `spacingMd` (16) to `spacingXs` (4) — requested directly,
/// from a screenshot: "gap between tasks still too big." Matches
/// `zoneBackgroundOffset`'s own value, so a zone band's padding and the
/// plain inter-row gap read as the same size of visual beat.
double _collapsedBlockGap(AmbleTheme theme) => theme.spacingXs;

/// [TaskCapsuleBlock]'s pill width, mirrored here (not imported — it's an
/// internal layout detail of that component, not part of its public API)
/// so overlapping tasks can be offset by exactly one pill per column. See
/// docs/DECISIONS.md. theme.sizeTaskBadge (20px) — requested directly
/// ("pill size and icon same as on zone view so smaller"), matching
/// ZoneContainerBlock's own row badge; must stay in sync with
/// [TaskCapsuleBlock]'s own `badgeSize`.
double _pillWidth(AmbleTheme theme) => theme.sizeTaskBadge;

/// The "back ease" overshoot constant `Curves.easeOutBack` itself uses
/// (`1.70158`, a widely-used default in easing libraries) — but that
/// constant produces a peak of only ~1.087 (confirmed by direct sampling
/// of `Curves.easeOutBack.transform`), not the requested 120%. Solved
/// numerically (binary search over the same "back ease" cubic family
/// `Curves.easeOutBack` uses — `f(t) = 1 + (c1+1)(t-1)^3 + c1(t-1)^2` —
/// for the `c1` whose overshoot peaks at exactly 1.2) rather than
/// hand-picking a value: `entranceScaleFor`'s own tests pin the resulting
/// peak/start/end to exact values, so this constant is verified indirectly
/// through them, not just asserted here.
const double _entranceOvershootConstant = 2.5923889040645722;

/// A just-created task's pill entrance scale at raw (linear) entrance
/// [progress] (0 at the moment it's revealed, 1 once the entrance is
/// complete) — requested directly: the pill should pop in larger than its
/// resting size (120%) and spring/bounce back down to 100%, "kind of
/// spring easing," not just fade in at a fixed size.
///
/// The same cubic "back ease" family `Curves.easeOutBack` is built from
/// (see [_entranceOvershootConstant]'s own doc comment), tuned so its
/// overshoot peaks at exactly 1.2 (120%) rather than that curve's own
/// ~1.087 — `Curves.easeOutBack` itself can't be rescaled to hit an
/// arbitrary peak since its overshoot isn't a fixed fraction of its 0→1
/// span. `progress == 0` gives 0 (the pill pops in from nothing, not from
/// its own resting size), `progress == 1` gives exactly 1.0 (settled at
/// its real size) — see the curve family's own math for why those two
/// endpoints hold regardless of the overshoot constant.
double entranceScaleFor(double progress) {
  final x = progress - 1;
  const c1 = _entranceOvershootConstant;
  const c3 = c1 + 1;
  return 1 + c3 * x * x * x + c1 * x * x;
}

/// Horizontal gap between the pills of two overlapping tasks. `spacingSm`
/// (8), one rung up from the `spacingXs` (4) it used to be — requested
/// directly: "slight larger gap between lanes".
double _columnGap(AmbleTheme theme) => theme.spacingSm;

/// Minimum VERTICAL gap this session guarantees between one task's pill
/// and the next same-column task's own top, when both would otherwise be
/// floored to `badgeSize` and collide despite not actually overlapping in
/// time (5- and 15-minute examples given directly). See
/// [_DayTimelineState._maxPillHeight], the one place that enforces it.
const double _minPillGap = 2;

/// Where every task's time/title row starts, measured from the day
/// column's own left edge — ONE x for every task in the day, whatever
/// overlap lane its own pill sits in.
///
/// Requested directly ("all task names ... should be lined up even items
/// not stacked line up with those stacked"). Derived from the day's
/// DEEPEST stack ([dayPillLanes]) rather than a single pill width, so the
/// column clears the widest pill run on screen and an unstacked task's
/// name still lines up with a stacked one's.
///
/// Includes the same one-pill widening the zone band gets (see
/// `_zoneBackgroundWidth`), so text always starts clear of the band rather
/// than on top of it — the two are derived from one lane count precisely
/// so they can't disagree.
double _textColumnLeft(AmbleTheme theme, List<TaskLayoutSlot> slots) =>
    zoneBackgroundPillWidth(
      lanes: dayPillLanes(slots),
      pillWidth: _pillWidth(theme),
      columnGap: _columnGap(theme),
    ) +
    _pillWidth(theme) +
    theme.spacingSm;

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Shared commit path for both [ZoneDayTimeline.onZoneResize] and
/// [ZoneDayTimeline.onZoneMove] — the two gestures differ only in HOW
/// [newStartMinutes]/[newEndMinutes] were derived (one edge grown vs.
/// both shifted together), not in what happens once a candidate window
/// exists. Requested directly: "zones should never overlap... perhaps
/// cascading... that doesn't block user intention" — computes the full
/// zone-to-zone cascade (`computeZoneCascadeMoves`,
/// `shared/services/zone_cascade_reschedule.dart`) and, if satisfiable,
/// commits every affected zone (and its own assigned tasks) in one write
/// via `ZoneList.commitZoneCascade`. A cascade that can't be satisfied
/// (the day genuinely has no room) is silently dropped — the container
/// snaps back to its real position on the next frame, same "no form/field
/// here for an error message to attach to" reasoning the original
/// silent-drop behavior already established.
///
/// [day] scopes the candidate zone set to whichever instances actually
/// apply on the day being viewed — per the Zone materialization session
/// (see docs/DECISIONS.md): a recurring zone is now real per-day rows
/// sharing a `recurrenceId`, each with its own id, so resizing/moving
/// Monday's instance must only ever compete against zones that ALSO apply
/// on Monday, never a sibling instance on a different day. This is the
/// change that makes editing one occurrence leave every other occurrence
/// in its series untouched — `computeZoneCascadeMoves` itself needed no
/// change, only which rows are fed into it.
void _commitZoneCascade(
  WidgetRef ref, {
  required String zoneId,
  required int originalStartMinutes,
  required int newStartMinutes,
  required int newEndMinutes,
  required DateTime day,
}) {
  final allZones = ref.read(zoneListProvider);
  final allTasks = ref.read(taskListProvider);
  final otherZones = allZones
      .where((z) => z.id != zoneId)
      .where((z) => z.anchorDate == null || _isSameDay(z.anchorDate!, day))
      .toList();
  final tasksByZoneId = <String, List<Task>>{};
  for (final task in allTasks) {
    final taskZoneId = task.zoneId;
    if (taskZoneId == null) continue;
    (tasksByZoneId[taskZoneId] ??= []).add(task);
  }

  final moves = computeZoneCascadeMoves(
    draggedZoneId: zoneId,
    draggedZoneOriginalStartMinutes: originalStartMinutes,
    zoneStartOverride: newStartMinutes,
    zoneEndOverride: newEndMinutes,
    otherZones: otherZones,
    tasksByZoneId: tasksByZoneId,
  );
  if (moves == null) return;

  ref.read(zoneListProvider.notifier).commitZoneCascade(moves);
}

/// [TaskCapsuleBlock]'s pill height for a given task, mirrored here for the
/// same reason as [_pillWidth] — needed to find where one task's pill ends
/// so the connector line (see [_TimelineConnectors]) can start there.
double _pillHeight(AmbleTheme theme, Task task, double pixelsPerMinute) =>
    math.max(task.durationMinutes! * pixelsPerMinute, _pillWidth(theme));

/// Which of this screen's two spatial layouts to render — see
/// [TimelineScreen.mode]'s own doc comment for the nav split this exists
/// for.
enum TimelineDisplayMode {
  /// The original spatial Timeline — tasks positioned against a real time
  /// axis. Nav destination "Task view".
  spatial,

  /// The Zone-organized, non-spatial list of zones/tasks. Nav destination
  /// "Timeline".
  zone,
}

/// The Timeline day view — hour markers, tasks for the selected day
/// positioned by [Task.scheduledAt]/[Task.durationMinutes], a live
/// current-time indicator, and simple day navigation. Wired to
/// [tasksForSelectedDayProvider] (real provider data, Phase 1 + this
/// session), not seeded data — see timeline_capsule_preview.dart for the
/// separate dev-scaffold preview.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key, required this.mode});

  /// **2026-09-12 — no longer read from `ZoneViewEnabledSetting`.**
  /// Requested directly: Task view and Zone view become two separate,
  /// permanent nav destinations rather than one screen with an in-screen
  /// switcher (`DayStrip`'s own cycle button, removed alongside this) —
  /// each caller now forces the mode outright, matching which nav tab
  /// it's mounted under. `ZoneViewEnabledSetting`/`ShowHourLabelsSetting`
  /// remain as persisted Hive fields (harmless if unread) rather than
  /// migrated away, since removing a Hive field outright risks breaking
  /// existing installs' stored preferences for no functional gain.
  final TimelineDisplayMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).extension<AmbleTheme>()!;
    final tasks = ref.watch(tasksForSelectedDayProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    // Resolved once here (the ConsumerWidget root) and threaded down as a
    // plain field, same pattern as showHourLabels/disableClustering below
    // — TaskCapsuleBlock and its StatefulWidget ancestors aren't
    // Riverpod-aware.
    // Display-only, per CONSTITUTION.md's Zone section: rendered as a
    // background block on this (Spatial Task) view regardless of whether
    // any task actually references it via zoneId — that filtering would be
    // Zone/spatial-zone-VIEW behavior, explicitly out of scope here.
    // Gated behind the same feature flag every other Zone UI surface uses.
    //
    // Filtered to zones that actually APPLY on `selectedDate` — per the
    // Zone materialization session (see docs/DECISIONS.md): a recurring
    // zone is now real per-day rows sharing a `recurrenceId`, so without
    // this filter every materialized instance of a series (up to ~56 for
    // an 8-week daily series) would render simultaneously on top of each
    // other on any single day, since they all share the same time-of-day
    // window. Same day-membership rule `_commitZoneCascade` and
    // `resolveZoneContainment` already use — a non-recurring zone
    // (`anchorDate == null`) still applies to every day, unaffected.
    final zones = FeatureFlags.zoneEnabled
        ? ref
              .watch(zoneListProvider)
              .where(
                (zone) =>
                    zone.anchorDate == null ||
                    _isSameDay(zone.anchorDate!, selectedDate),
              )
              .toList()
        : const <Zone>[];
    final categoryById = {
      for (final category in ref.watch(categoryListProvider))
        category.id: category,
    };
    // **2026-09-12 — driven by `mode`, not a setting.** Still gated on the
    // Zone feature flag: with it off, the "Timeline" nav tab that requests
    // `TimelineDisplayMode.zone` would otherwise render a Zone view no
    // other Zone UI surface in the app is reachable from — this keeps that
    // one tab falling back to the spatial layout instead, matching every
    // other Zone surface's own flag gating.
    final zoneViewEnabled =
        FeatureFlags.zoneEnabled && mode == TimelineDisplayMode.zone;
    // Feature 1 (read-only external calendar events) — see CONSTITUTION.md's
    // "Calendar" section. A day-bounded range is generous enough for both
    // Timeline modes' own (possibly slightly wider) rangeStart/rangeEnd to
    // still find every relevant event when rendering. `.valueOrNull ?? []`
    // means a still-loading fetch or any failure (permission denied, no
    // calendars selected, device error) simply shows no external events
    // this frame — matches the explicit "never block or degrade the normal
    // Amble task display" contract; nothing here awaits or surfaces an
    // error state.
    final dayStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final externalEvents =
        ref
            .watch(
              externalCalendarEventsForRangeProvider(
                dayStart,
                dayStart.add(const Duration(days: 1)),
              ),
            )
            .value ??
        const <ExternalCalendarEvent>[];
    // Only used by the whole-screen swipe-to-change-day gesture, commented
    // out below per direct request — uncomment alongside it if that
    // gesture is reinstated.
    // final dayNotifier = ref.read(selectedDateProvider.notifier);
    final taskNotifier = ref.read(taskListProvider.notifier);
    // Watched here (the ConsumerWidget root) and threaded down as a plain
    // field, same pattern as every other setting/flag this screen already
    // resolves once and passes to its non-Riverpod-aware descendants
    // (_DayTimeline, ZoneDayTimeline, TaskCapsuleBlock).
    final editModeEnabled = ref.watch(editModeEnabledProvider);

    // Clears any leftover multi-task selection the moment either toggle
    // that made it meaningful goes away — Edit Mode itself exiting, or
    // multi-task mode being switched off while Edit Mode stays on. Without
    // this a stale selection would silently reappear (still wiggling,
    // still armed for a group gesture) the next time either was switched
    // back on, which reads as a bug rather than the deliberately ephemeral
    // state `edit_selection_provider.dart` documents itself as. Listened
    // here (not inside `EditSelection` itself) since a provider clearing
    // itself in reaction to two OTHER providers is backwards coupling —
    // this screen already watches both and is where they're meant to
    // compose.
    ref.listen(editModeEnabledProvider, (previous, next) {
      // Hooked to the state CHANGE rather than to either toggle call site,
      // because Edit Mode has two of them (the two-finger long-press and
      // `AppCalendarHeader`'s own pen icon) and both deserve the same
      // confirmation. Entering gets `lift` (a mode is now being held),
      // leaving gets the lighter `selection` — the same asymmetry the
      // completion checkbox uses.
      ref
          .read(hapticsProvider)
          .play(next ? AmbleHaptic.lift : AmbleHaptic.selection);
      if (!next) ref.read(editSelectionProvider.notifier).clear();
      if (!next) ref.read(zoneEditSelectionProvider.notifier).clear();
    });
    ref.listen(devMultiTaskEditModeProvider, (previous, next) {
      if (!next) ref.read(editSelectionProvider.notifier).clear();
      if (!next) ref.read(zoneEditSelectionProvider.notifier).clear();
    });

    // **2026-09-12 — anything that navigates away disarms a long-pressed
    // task.** Reported directly: "changing day, page, or navigating
    // elsewhere basically or activating sheet would exit edit mode."
    // Previously only a tap on the Timeline itself cleared the arm, so a
    // task kept wiggling behind an open sheet, and switching day left it
    // armed on a day it isn't even visible on — its resize handles then
    // belonged to a task the user could no longer see.
    //
    // Listened here rather than added to each navigation call site: the
    // arm is Timeline-local state, the transitions are all observable as
    // provider changes, and wiring N call sites would guarantee the N+1th
    // gets missed. `selectedDate` covers the day strip, the month
    // stepper, the today button and swipes; `pendingTaskDraft` covers the
    // quick-create mini sheet. A pushed route (the detail sheet, any
    // Settings page) disarms via `_effectiveOnTap`'s own clear before it
    // pushes, and the tab bar rebuilds this screen with the provider
    // already reset by its autoDispose.
    ref.listen(selectedDateProvider, (previous, next) {
      if (previous != next) ref.read(armedEditTaskProvider.notifier).clear();
    });
    ref.listen(pendingTaskDraftProvider, (previous, next) {
      if (next != null) ref.read(armedEditTaskProvider.notifier).clear();
    });

    return Container(
      color: theme.colorSurfaceTimeline,
      child: SafeArea(
        // The floating "+" (AppFloatingCreateButton, in the outer Stack
        // below) owns the bottom edge itself via its own SafeArea, so this
        // outer SafeArea only needs to guard the top/sides.
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // **2026-09-12 — the calendar moved to the top**, shared by
                // both this screen's modes (and Timeline's own "Task view"
                // tab — see main.dart), replacing the old bottom day-strip's
                // own day-navigation UI entirely. Requested directly, with a
                // reference screenshot.
                //
                // Hidden ENTIRELY only for the quick-create-draft case (see
                // the matching `if` further down for the "+" button's own
                // half of that same rule) — NOT for Edit Mode any more.
                // Reported directly as a real gap: hiding the whole header
                // while Edit Mode is on took its own close control down with
                // it, leaving no visible way back out. `AppCalendarHeader`
                // itself now collapses to just that close button when Edit
                // Mode is active, so it's never removed from the tree here.
                if (ref.watch(pendingTaskDraftProvider) == null)
                  const AppCalendarHeader(),
                Expanded(
                  // Whole-screen swipe-to-change-day REMOVED (requested
                  // directly) — day navigation now happens only through the
                  // strip below, either by tapping a chip or scrolling it.
                  // Previously this Expanded's child was wrapped in a
                  // GestureDetector(onHorizontalDragEnd: ...) calling
                  // dayNotifier.goToNextDay()/goToPreviousDay(); kept as a
                  // comment rather than deleted outright, since "comment out"
                  // was the explicit instruction:
                  //
                  // GestureDetector(
                  //   onHorizontalDragEnd: (details) {
                  //     final velocity = details.primaryVelocity ?? 0;
                  //     if (velocity < 0) {
                  //       dayNotifier.goToNextDay();
                  //     } else if (velocity > 0) {
                  //       dayNotifier.goToPreviousDay();
                  //     }
                  //   },
                  //   child: ...,
                  // ),
                  child: TwoFingerLongPress(
                    onTwoFingerLongPress: () =>
                        ref.read(editModeEnabledProvider.notifier).toggle(),
                    child: Stack(
                      children: [
                        AnimatedSwitcher(
                          // Task<->Zone view switch: outgoing view slides left+fades
                          // out, incoming view slides in from the right+fades in —
                          // requested directly. motionRouteSettle/curveStandard
                          // (500ms, Material standard ease) since this is a
                          // route-level view change, not a small in-place UI tweak.
                          duration: theme.motionRouteSettle,
                          switchInCurve: theme.curveStandard,
                          switchOutCurve: theme.curveStandard,
                          transitionBuilder: (child, animation) {
                            // Every view switch must read right-to-left, both
                            // directions — reported directly, twice: first that the
                            // outgoing view slid right instead of left, then (after
                            // an attempted fix using animation.status) that the
                            // Task view stopped animating in at all, plus real
                            // clipping ("left side cut off").
                            //
                            // Root cause of the SECOND attempt's failure:
                            // AnimatedSwitcher calls transitionBuilder(child,
                            // animation) ONCE, synchronously, at the moment an entry
                            // is CREATED — before its controller.forward()/.reverse()
                            // has actually been called (see _addEntryForNewChild in
                            // the framework source: _newEntry builds the transition
                            // BEFORE forward()/reverse() runs). So `animation.status`
                            // read at that instant is always still `dismissed`, for
                            // BOTH the incoming and outgoing entry — never `forward`.
                            // That's why the Task view (whichever entry happened to
                            // build second) silently took the wrong branch and never
                            // animated in.
                            //
                            // The reliable signal instead: `child` is the ACTUAL
                            // widget passed in for THIS entry, and its `key` is
                            // known — compare it against which view is CURRENTLY
                            // selected (the enclosing build's own `zoneViewEnabled`,
                            // captured by this closure) rather than the animation's
                            // own transient status. This entry is "entering" if and
                            // only if its key matches the view that's actually
                            // selected right now.
                            final isEntering =
                                child.key ==
                                (zoneViewEnabled
                                    ? const ValueKey('zone-view')
                                    : const ValueKey('task-view'));
                            final slide = Tween<Offset>(
                              begin: isEntering
                                  ? const Offset(0.15, 0)
                                  : Offset.zero,
                              end: isEntering
                                  ? Offset.zero
                                  : const Offset(-0.15, 0),
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          // clipBehavior: Clip.none — real bug, reported directly
                          // ("list and zone screens are positioned off screen, left
                          // side is cut off"): Stack's OWN default is
                          // Clip.hardEdge, and the custom layoutBuilder below
                          // (needed so both the outgoing and incoming full-width
                          // views can slide past the Stack's own bounds mid-
                          // transition) inherited that default silently. Also
                          // switched alignment to center, matching
                          // AnimatedSwitcher.defaultLayoutBuilder's own choice —
                          // topLeft mis-aligned a translated child against a
                          // Stack that isn't naturally sized to its own top-left
                          // corner once children can slide outside its bounds.
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [...previousChildren, ?currentChild],
                              ),
                          child: zoneViewEnabled
                              // Same empty-day treatment as the Task view below: the
                              // timeline still renders and scrolls, with the message
                              // floating over it.
                              ? Stack(
                                  key: const ValueKey('zone-view'),
                                  children: [
                                    ZoneDayTimeline(
                                      tasks: tasks,
                                      zones: zones,
                                      // "hide imported tasks" now also affects
                                      // Zone view, not just List view —
                                      // requested directly, replacing the old
                                      // "Only Amble tasks" toggle. Mirrors the
                                      // List-view `filteredExternalEvents`
                                      // pattern below exactly.
                                      // "hide imported tasks" now also affects
                                      // Zone view, not just List view —
                                      // requested directly, replacing the old
                                      // "Only Amble tasks" toggle. Mirrors the
                                      // List-view `filteredExternalEvents`
                                      // pattern below exactly.
                                      externalEvents:
                                          ref.watch(
                                            devHideImportedTasksProvider,
                                          )
                                          ? const <ExternalCalendarEvent>[]
                                          : externalEvents,
                                      theme: theme,
                                      categoryById: categoryById,
                                      selectedDate: selectedDate,
                                      // Dev-only capsule display toggles (Settings'
                                      // "Developer" section) — read once here, same
                                      // as showHourLabels/disableClustering, and
                                      // threaded down as plain fields since
                                      // ZoneDayTimeline isn't Riverpod-aware.
                                      devTextLayout: ref.watch(
                                        devTimelineTaskTextLayoutProvider,
                                      ),
                                      // A real user setting (not a dev toggle) —
                                      // one toggle across all three views.
                                      showCompletionCheckbox: ref.watch(
                                        showCompletionCheckboxSettingProvider,
                                      ),
                                      devIconsVisible: ref.watch(
                                        devTimelineTaskIconsVisibleProvider,
                                      ),
                                      devDurationVisible: ref.watch(
                                        devTimelineTaskDurationVisibleProvider,
                                      ),
                                      // Same threading, same reason — List
                                      // view's own "Show time (from-to)"
                                      // toggle now also applies to Zone view,
                                      // requested directly: "Hide/show start
                                      // end should also affect zone view."
                                      devTimeRangeVisible: ref.watch(
                                        devTimelineTaskTimeRangeVisibleProvider,
                                      ),
                                      // Strips each zone's own card
                                      // background/padding, leaving just its
                                      // title/duration header above a bare row
                                      // list — requested directly, Developer
                                      // section only.
                                      devZoneCardFlat: ref.watch(
                                        devZoneCardFlatProvider,
                                      ),
                                      // Opens Edit directly, skipping the action
                                      // sheet (Edit/Duplicate/Remove) — requested
                                      // directly. The sheet stays in the codebase,
                                      // unused for now, in case it's wanted again.
                                      onTaskTap: (task) => showTaskDetailSheet(
                                        context,
                                        task: task,
                                      ),
                                      onToggleComplete: (task) =>
                                          _completeTask(context, ref, task),
                                      // Non-spatial list — requested directly
                                      // ("current zone view make non spatial..
                                      // just list of zones one by one"). No more
                                      // drag-to-move/resize or drag-and-drop task
                                      // reassignment; a zone's own header now
                                      // opens the same edit form Settings' plain
                                      // Zones list already uses.
                                      onZoneHeaderTap: (zone) =>
                                          showZoneFormScreen(
                                            context,
                                            zone: zone,
                                          ),
                                    ),
                                    if (tasks.isEmpty && zones.isEmpty)
                                      IgnorePointer(
                                        child: _EmptyDayState(theme: theme),
                                      ),
                                  ],
                                )
                              // An empty day still renders the full scrollable
                              // timeline — the "nothing scheduled" message floats
                              // OVER it rather than replacing it, confirmed directly.
                              // Previously an empty day short-circuited to a centered
                              // message with nothing to scroll at all.
                              : Stack(
                                  key: const ValueKey('task-view'),
                                  children: [
                                    _DayTimeline(
                                      tasks: tasks,
                                      theme: theme,
                                      categoryById: categoryById,
                                      zones: zones,
                                      externalEvents: externalEvents,
                                      selectedDate: selectedDate,
                                      // **2026-09-12 — no longer read from the
                                      // setting.** List view (this being
                                      // `false`) is dropped from user reach
                                      // entirely per direct request: Task view
                                      // is now its own permanent nav tab, and
                                      // always renders the spatial layout. The
                                      // underlying `ShowHourLabelsSetting`
                                      // Hive field is left in place rather
                                      // than migrated away (a prior install's
                                      // stored `false`, from when List view
                                      // was still reachable, must not silently
                                      // resurface it) — this call site simply
                                      // stops reading it.
                                      showHourLabels: true,
                                      showTimelineConnectors: ref.watch(
                                        showTimelineConnectorsSettingProvider,
                                      ),
                                      // Opens Edit directly, skipping the action sheet
                                      // (Edit/Duplicate/Remove) — requested directly.
                                      // The sheet stays in the codebase, unused for
                                      // now, in case it's wanted again.
                                      onTaskTap: (task) => showTaskDetailSheet(
                                        context,
                                        task: task,
                                      ),
                                      onToggleComplete: (task) =>
                                          _completeTask(context, ref, task),
                                      onReschedule: (task, newScheduledAt) =>
                                          taskNotifier.rescheduleTask(
                                            task,
                                            newScheduledAt,
                                          ),
                                      onCreateAt: (startAt) =>
                                          showTaskDetailSheet(
                                            context,
                                            initialScheduledAt: startAt,
                                            initialTimeOfDay:
                                                TimeOfDay.fromDateTime(startAt),
                                          ),
                                      // Tap-empty-space quick-create, requested
                                      // directly: drops the wiggly placeholder
                                      // pill immediately (so it's visible the
                                      // instant the tap lands). QuickCreateOverlay
                                      // (rendered below, gated on pendingDraft)
                                      // owns the small sheet AND the eventual
                                      // promotion to the real showTaskDetailSheet
                                      // route once the user expands it — nothing
                                      // pushed from here.
                                      onEmptyTap: (tappedAt) {
                                        // Tapping outside a long-press-armed
                                        // task closes its edit/wiggle state —
                                        // requested directly, the other half of
                                        // "long press on task should enable its
                                        // edit mode... tapping outside closes
                                        // that mode." See _effectiveOnLongPress
                                        // for the arming side.
                                        //
                                        // **2026-09-12 — a tap while a task IS
                                        // armed now ONLY closes the arm.**
                                        // Reported directly: "tap anywhere on
                                        // the screen [while a task is
                                        // wiggling]... its not triggering
                                        // (task creation if tapped on
                                        // timeline) but stopping wiggling."
                                        // The original behavior started a
                                        // quick-create draft on the SAME tap
                                        // that closed the arm — a tap meant
                                        // only to dismiss the wiggle was
                                        // silently also creating a task.
                                        final wasArmed =
                                            ref.read(armedEditTaskProvider) !=
                                            null;
                                        ref
                                            .read(
                                              armedEditTaskProvider.notifier,
                                            )
                                            .clear();
                                        if (wasArmed) return;
                                        ref
                                            .read(
                                              pendingTaskDraftProvider.notifier,
                                            )
                                            .start(
                                              scheduledAt: tappedAt,
                                              durationMinutes:
                                                  quickAddDefaultMinutes,
                                            );
                                      },
                                      pendingDraft: ref.watch(
                                        pendingTaskDraftProvider,
                                      ),
                                      recentlySaved: ref.watch(
                                        recentlySavedTaskProvider,
                                      ),
                                      onSavedTaskConsumed: () => ref
                                          .read(
                                            recentlySavedTaskProvider.notifier,
                                          )
                                          .clear(),
                                      disableClustering: ref.watch(
                                        disableOverlapClusteringSettingProvider,
                                      ),
                                      // Independently configurable from the Zone
                                      // view's own scale above — see
                                      // DevZoneViewPixelsPerMinute's doc comment.
                                      pixelsPerMinute: ref.watch(
                                        devTaskViewPixelsPerMinuteProvider,
                                      ),
                                      showFreeWindowPrompt: ref.watch(
                                        devShowFreeWindowPromptProvider,
                                      ),
                                      // Read here (not just inside
                                      // _DraggableTaskBlockState, which independently
                                      // watches its own copy for TaskCapsuleBlock) so
                                      // OverlapClusterBlock's cluster rows — built by
                                      // this plain (non-Riverpod) _DayTimelineState —
                                      // can respect the same setting. Real parity gap,
                                      // fixed here: a clustered task's row previously
                                      // never showed the duration suffix at all.
                                      devDurationVisible: ref.watch(
                                        devTimelineTaskDurationVisibleProvider,
                                      ),
                                      // Same threading, same reason — List
                                      // view's own from-to time range,
                                      // independent of duration. See
                                      // DevTimelineTaskTimeRangeVisible's own
                                      // doc comment.
                                      devTimeRangeVisible: ref.watch(
                                        devTimelineTaskTimeRangeVisibleProvider,
                                      ),
                                      // Same threading, same reason — List
                                      // view here (Zone view has its own
                                      // separate call site below), hides
                                      // imported calendar events entirely.
                                      // See DevHideImportedTasks's own doc
                                      // comment.
                                      devHideImportedTasks: ref.watch(
                                        devHideImportedTasksProvider,
                                      ),
                                      // Same threading, same reason — List
                                      // view only, hides non-important tasks.
                                      // See DevTimelineListOnlyImportant's own
                                      // doc comment.
                                      devListOnlyImportant: ref.watch(
                                        devTimelineListOnlyImportantProvider,
                                      ),
                                      // Same threading, same reason — see
                                      // _DayTimeline.devTextLayout's own doc comment.
                                      devTextLayout: ref.watch(
                                        devTimelineTaskTextLayoutProvider,
                                      ),
                                      // A real user setting (not a dev toggle) —
                                      // one toggle across all three views.
                                      showCompletionCheckbox: ref.watch(
                                        showCompletionCheckboxSettingProvider,
                                      ),
                                      // Shared with Zone view above via
                                      // viewed_time_provider.dart. `read`, not `watch`
                                      // — see the Zone view's own copy of this above
                                      // for why watching it was a feedback loop.
                                      readViewedMinutes: () =>
                                          ref.read(viewedTimeProvider),
                                      onViewedMinutesChanged: (minutes) => ref
                                          .read(viewedTimeProvider.notifier)
                                          .set(minutes),
                                      editModeEnabled: editModeEnabled,
                                      onDeleteTask: (task) => removeTask(
                                        context,
                                        taskNotifier,
                                        task,
                                      ),
                                      // Same shared commit path Zone view's own
                                      // resize/move already use — see
                                      // `_commitZoneCascade`'s own doc comment.
                                      onZoneResize:
                                          (
                                            zoneId,
                                            originalStartMinutes,
                                            newStartMinutes,
                                            newEndMinutes,
                                          ) => _commitZoneCascade(
                                            ref,
                                            zoneId: zoneId,
                                            originalStartMinutes:
                                                originalStartMinutes,
                                            newStartMinutes: newStartMinutes,
                                            newEndMinutes: newEndMinutes,
                                            day: selectedDate,
                                          ),
                                      onZoneMove:
                                          (
                                            zoneId,
                                            originalStartMinutes,
                                            newStartMinutes,
                                            newEndMinutes,
                                          ) => _commitZoneCascade(
                                            ref,
                                            zoneId: zoneId,
                                            originalStartMinutes:
                                                originalStartMinutes,
                                            newStartMinutes: newStartMinutes,
                                            newEndMinutes: newEndMinutes,
                                            day: selectedDate,
                                          ),
                                      // Reported directly: "zones cant see
                                      // remove... when in edt move dragging
                                      // zone should remove zone appear like
                                      // with tasks." No recurring-scope
                                      // disambiguation (unlike removeTask
                                      // above) — deleteZone has no series
                                      // concept to ask about; a materialized
                                      // recurring instance is deleted the same
                                      // way a plain one is.
                                      onDeleteZone: (zone) => ref
                                          .read(zoneListProvider.notifier)
                                          .deleteZone(zone.id),
                                    ),
                                    // IgnorePointer so the message never blocks a tap
                                    // on the timeline underneath (creating a task by
                                    // tapping a free window still works through it).
                                    if (tasks.isEmpty)
                                      IgnorePointer(
                                        child: _EmptyDayState(theme: theme),
                                      ),
                                  ],
                                ),
                        ),
                        // Edit Mode's second entry point moved OUT of this
                        // Stack — 2026-09-12, it now lives in the new
                        // `AppCalendarHeader` above (the pen icon), not
                        // positioned over the scrollable day any more. See
                        // that widget's own doc comment for the restyle.
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Floating independently above the bottom nav pill now
            // (2026-09-12, requested directly from a reference
            // screenshot: "nav is just 5 items + its outside") rather
            // than welded into its own bar stacked on top of it — see
            // `AppFloatingCreateButton`'s own doc comment.
            //
            // Hidden entirely while Edit Mode is active — requested
            // directly: "in edit mode we don't see main menu and days and
            // view switching... let's skip Plus." The day chips/view-cycle
            // button are gone now (2026-09-12, see AppCalendarHeader and
            // the mode split above), so only the "+" create button is left
            // to suppress here.
            //
            // Hidden for the same reason while a quick-create draft is
            // live (the tap-empty-space mini sheet) — requested directly:
            // "we don't show main nav, we should not show also the days
            // with view switch and + button section, only the minisheet
            // is visible in this scenario." The bottom NavigationBar is
            // already suppressed for this case in `main.dart`'s own
            // `hideBottomNav`; this is the other half of that same
            // "only the mini sheet" rule.
            if (!editModeEnabled && ref.watch(pendingTaskDraftProvider) == null)
              AppFloatingCreateButton(
                onPressed: () {
                  // Defaults to whatever time is vertically centered in
                  // the current scroll position, not real "now" —
                  // requested directly. `viewedTimeProvider` already
                  // tracks this (kept in sync by both spatial views as the
                  // user scrolls); null only for a fresh, never-scrolled
                  // session, where "now" is still the right fallback.
                  final viewedMinutes =
                      ref.read(viewedTimeProvider) ??
                      (DateTime.now().hour * 60 + DateTime.now().minute);
                  showTaskDetailSheet(
                    context,
                    initialScheduledAt: DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                    ).add(Duration(minutes: viewedMinutes)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Completes (or un-completes) [task], asking for an outcome amount first
/// when it's linked to a tracked behavior.
///
/// **Ordinary tasks are untouched.** Every guard below fails fast for a
/// task with no `behaviorId`, so the ordinary path is exactly the single
/// `toggleComplete(task)` call it has always been — no prompt, no extra
/// await, no added friction (design principle 2). The prompt also never
/// appears when *un*-completing, or for a binary behavior, which has
/// nothing to quantify.
Future<void> _completeTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
) async {
  final notifier = ref.read(taskListProvider.notifier);

  final isCompleting = task.status != TaskStatus.completed;
  final behaviorId = task.behaviorId;
  if (!FeatureFlags.trackedBehaviorEnabled ||
      !isCompleting ||
      behaviorId == null) {
    await notifier.toggleComplete(task);
    return;
  }

  final behavior = ref
      .read(trackedBehaviorListProvider)
      .where((candidate) => candidate.id == behaviorId)
      .firstOrNull;
  // A dangling link (behavior deleted) must not block completing the task.
  if (behavior == null || !behaviorNeedsOutcomePrompt(behavior)) {
    await notifier.toggleComplete(task);
    return;
  }

  final amount = await showBehaviorOutcomePrompt(context, behavior: behavior);
  // A dismissed prompt still completes the task — `actualAmount` just stays
  // null. Declining to quantify is not declining to finish.
  await notifier.toggleComplete(task, actualAmount: amount);
}

typedef _TaskCallback = void Function(Task task);
typedef _RescheduleCallback = Future<void> Function(
  Task task,
  DateTime newScheduledAt,
);

class _DayTimeline extends StatefulWidget {
  const _DayTimeline({
    required this.tasks,
    required this.theme,
    required this.categoryById,
    required this.zones,
    this.externalEvents = const [],
    required this.selectedDate,
    required this.showHourLabels,
    this.showTimelineConnectors = true,
    required this.onTaskTap,
    required this.onToggleComplete,
    required this.onReschedule,
    required this.onCreateAt,
    required this.onEmptyTap,
    this.pendingDraft,
    required this.recentlySaved,
    required this.onSavedTaskConsumed,
    required this.disableClustering,
    this.pixelsPerMinute = 1.5,
    this.showFreeWindowPrompt = true,
    this.devDurationVisible = true,
    this.devTimeRangeVisible = true,
    this.devHideImportedTasks = false,
    this.devListOnlyImportant = false,
    this.devTextLayout = TimelineTaskTextLayout.stacked,
    this.showCompletionCheckbox = true,
    this.readViewedMinutes,
    this.onViewedMinutesChanged,
    this.editModeEnabled = false,
    this.onDeleteTask,
    this.onZoneResize,
    this.onZoneMove,
    this.onDeleteZone,
  });

  final List<Task> tasks;
  final AmbleTheme theme;

  /// Every persisted [Zone] (already filtered to empty when the feature
  /// flag is off) — rendered as a background block per CONSTITUTION.md's
  /// Zone section, purely decorative on this (Spatial Task) view.
  final List<Zone> zones;

  /// Read-only events fetched fresh from whichever device calendars the
  /// user selected to display (Settings' Calendar section, Feature 1) —
  /// see CONSTITUTION.md's "Calendar" section and `ExternalEventBlock`'s
  /// own doc comment. Empty when the feature hasn't been set up, or a
  /// fetch is still loading/failed — [TimelineScreen] resolves that
  /// degradation before this widget ever sees the list.
  final List<ExternalCalendarEvent> externalEvents;

  /// The calendar day currently being viewed — [Zone.startMinutes]/
  /// [endMinutes] are time-of-day only, so this is what resolves them onto
  /// a real [DateTime] for positioning against [rangeStart].
  final DateTime selectedDate;

  /// Live `Category` rows keyed by id, resolved once by [TimelineScreen]
  /// (the `ConsumerWidget` root) and threaded down — same reasoning as
  /// [showHourLabels]/[disableClustering] below.
  final Map<String, Category> categoryById;

  /// Whether the left-side hour gutter renders at all — the Settings
  /// toggle (`ShowHourLabelsSetting`), read once by [TimelineScreen] (the
  /// `ConsumerWidget` parent) and threaded down as a plain field, same as
  /// [theme]/[tasks], rather than making this `StatefulWidget` itself
  /// Riverpod-aware.
  final bool showHourLabels;

  /// The Settings toggle (`ShowTimelineConnectorsSetting`) for the gray
  /// thread connecting consecutive tasks — Task view only, further gated
  /// by [showHourLabels] itself at the call site. Threaded down the same
  /// way as [showHourLabels]. Defaults to true so a caller that doesn't
  /// wire it up (a dev scaffold, a test) renders unchanged.
  final bool showTimelineConnectors;
  final _TaskCallback onTaskTap;
  final _TaskCallback onToggleComplete;
  final _RescheduleCallback onReschedule;

  /// The task the create/edit modal just saved, if any — the Timeline
  /// scrolls it into view and animates it in, then calls
  /// [onSavedTaskConsumed] so the same animation can't replay. Threaded
  /// down as a plain field (like [showHourLabels]) rather than making this
  /// StatefulWidget itself Riverpod-aware.
  final RecentlySavedTask? recentlySaved;
  final VoidCallback onSavedTaskConsumed;

  /// Opens the create-task flow seeded to start at the given instant —
  /// used by a free window's block (start of that gap) and the
  /// hold-and-drag placement line (wherever it's released).
  final ValueChanged<DateTime> onCreateAt;

  /// A plain TAP (not hold-and-drag) on empty Timeline background —
  /// requested directly: drops the wiggly placeholder pill and opens the
  /// small quick-create sheet. See `PlaceTaskLineLayer.onTapAt`.
  final ValueChanged<DateTime> onEmptyTap;

  /// The in-progress, not-yet-persisted task created by [onEmptyTap], if
  /// any — null whenever nothing is being quick-created. Threaded down as
  /// a plain field (like [recentlySaved]) rather than making this
  /// StatefulWidget itself Riverpod-aware.
  final PendingTaskDraft? pendingDraft;

  /// The Settings opt-out (`DisableOverlapClusteringSetting`) — when true,
  /// Overlapping tasks stay individual capsules (naive spatial
  /// overlap) instead of collapsing into one `OverlapClusterBlock`.
  /// Threaded down as a plain field for the same reason as
  /// [showHourLabels].
  final bool disableClustering;

  /// Vertical scale in timeline (`showHourLabels` on) mode — the Settings/
  /// dev scratch config `DevTaskViewPixelsPerMinute`, threaded down the
  /// same way as [showHourLabels]. Defaults to the shipped 1.5 so a caller
  /// that doesn't wire it up (a dev scaffold, a test) renders unchanged.
  /// Independently configurable from the Zone view's own scale — see
  /// `DevZoneViewPixelsPerMinute`'s doc comment for why the two split.
  final double pixelsPerMinute;

  /// The dev scratch toggle (`DevShowFreeWindowPrompt`) for whether
  /// [FreeWindowBlock] renders at all — threaded down the same way as
  /// [showHourLabels], read once by [TimelineScreen]. Defaults to true so a
  /// caller that doesn't wire it up (a dev scaffold, a test) renders
  /// unchanged.
  final bool showFreeWindowPrompt;

  /// The dev scratch toggle (`DevTimelineTaskDurationVisibleProvider`) for
  /// the `(45m)`-style duration suffix — threaded down here (in addition
  /// to `_DraggableTaskBlockState`'s own independent watch, used for
  /// ordinary capsules) so `OverlapClusterBlock`'s cluster rows can
  /// respect the same setting; `_DayTimelineState` isn't Riverpod-aware,
  /// so it can't watch the provider itself. Defaults to true (current
  /// shipped behavior).
  final bool devDurationVisible;

  /// The dev scratch toggle (`DevTimelineTaskTimeRangeVisibleProvider`) —
  /// List view's own from-to time range, threaded down for the same
  /// reason as [devDurationVisible]. The two are independent settings —
  /// see that provider's own doc comment. Defaults to true (current
  /// shipped behavior: List view always showed its time range).
  final bool devTimeRangeVisible;

  /// The dev scratch toggle (`DevHideImportedTasksProvider`) — List view
  /// (and, at its own separate call site, Zone view) only, hides imported
  /// calendar events from the row list entirely, showing only native
  /// Amble tasks. Threaded down for the same reason as
  /// [devDurationVisible]: `_DayTimelineState` isn't Riverpod-aware, and
  /// this filters the single shared `blocks` list consumed by BOTH Task
  /// and List mode, so the flag has to reach `build()` itself, gated
  /// there behind `!showHourLabels`. Defaults to false (current shipped
  /// behavior: events already appear in List view).
  final bool devHideImportedTasks;

  /// The dev scratch toggle (`DevTimelineListOnlyImportantProvider`) —
  /// List view only, hides every [Task] with `isImportant == false`.
  /// Independent of [devHideImportedTasks]; same threading reason.
  /// Defaults to false (current shipped behavior).
  final bool devListOnlyImportant;

  /// The dev scratch toggle (`DevTimelineTaskTextLayoutProvider`) — threaded
  /// down for the same reason as [devDurationVisible]: `_DayTimelineState`
  /// isn't Riverpod-aware, and both `OverlapClusterBlock`'s cluster rows and
  /// `ExternalEventBlock` need it. Real gap, reported directly ("still time
  /// and name of important tasks are not in the same line (if inline is
  /// set) and also clustered tasks ... in task view render in 2 lines"):
  /// only `TaskCapsuleBlock` ever received this setting, so an ordinary
  /// capsule went inline while a clustered row and an external event stayed
  /// stacked beside it. Defaults to `stacked` (current shipped behavior).
  final TimelineTaskTextLayout devTextLayout;

  /// Whether a task's trailing completion checkbox renders
  /// (`ShowCompletionCheckboxSetting`) — a real user setting, not a dev
  /// toggle, and deliberately one setting across all three views.
  /// Threaded down as a plain field for the same reason as
  /// [devDurationVisible]: `_DayTimelineState` isn't Riverpod-aware, and
  /// both the ordinary capsules and `OverlapClusterBlock`'s rows need it.
  final bool showCompletionCheckbox;

  /// Reads the minutes-since-midnight last centered in EITHER spatial view
  /// (Task or Zone) — see `viewed_time_provider.dart`. Returns null only
  /// when nothing has been recorded yet this session, in which case the
  /// view falls back to centering on "now".
  ///
  /// A CALLBACK rather than a plain value, deliberately: passing the value
  /// itself meant `TimelineScreen` had to `ref.watch` the provider, so
  /// every scroll rebuilt the whole screen (see that call site's own
  /// comment for the loop this caused). Reading it lazily, only at the
  /// moment a restore actually happens, keeps the provider out of the
  /// build graph entirely.
  final int? Function()? readViewedMinutes;

  /// Reports this view's own center position (minutes-since-midnight)
  /// whenever it scrolls, so the OTHER view (and a future switch back to
  /// this one) can resume from it. Threaded down as a plain callback,
  /// matching every other `TimelineScreen`-owned piece of state here —
  /// `_DayTimelineState` isn't Riverpod-aware.
  final ValueChanged<int>? onViewedMinutesChanged;

  /// Whether Edit Mode is active — resolved once by [TimelineScreen] (the
  /// `ConsumerWidget` root) via `editModeEnabledProvider` and threaded
  /// down as a plain field, same pattern as [showHourLabels]/
  /// [disableClustering] above. Gates the resize handles and the
  /// drag-to-delete target on every [_DraggableTaskBlock] this view
  /// builds.
  final bool editModeEnabled;

  /// Deletes a task via drag-to-delete-target — see
  /// `edit_mode_delete_target.dart`. Deliberately a SEPARATE callback from
  /// [onReschedule], not a special case inside it: a delete-drop is a
  /// genuinely different outcome (bypassing the cascade-push algorithm
  /// entirely, per CONSTITUTION.md), not a reschedule to a particular
  /// place.
  final Future<void> Function(Task task)? onDeleteTask;

  /// Commits a zone resize on this (Spatial Task) view — same shape and
  /// same cascade-computing caller (`_commitZoneCascade`) as
  /// `ZoneDayTimeline.onZoneResize`. **New 2026-09-06** (confirmed
  /// directly — "we should be able to edit zones in any view ... in
  /// spatial task view also"), reversing the earlier "Task view zones are
  /// purely decorative" scope. A callback rather than `_DayTimelineState`
  /// writing through `zoneListProvider` itself: this widget isn't
  /// Riverpod-aware, same reason `onReschedule`/`onDeleteTask` are
  /// callbacks too.
  final void Function(
    String zoneId,
    int originalStartMinutes,
    int newStartMinutes,
    int newEndMinutes,
  )?
  onZoneResize;

  /// Commits a zone MOVE (whole block repositioned, duration unchanged) —
  /// same shape and same cascade-computing caller as [onZoneResize]. See
  /// `ZoneDayTimeline.onZoneMove`'s own doc comment.
  final void Function(
    String zoneId,
    int originalStartMinutes,
    int newStartMinutes,
    int newEndMinutes,
  )?
  onZoneMove;

  /// Deletes a zone via drag-to-delete-target — same shape as
  /// [onDeleteTask], requested directly: "zones cant see remove... when
  /// in edt move dragging zone should remove zone appear like with
  /// tasks." Reuses the identical shared delete target every task drag
  /// already renders (see `_DraggableZoneBlock.deleteTargetKey`'s own doc
  /// comment) rather than a second, zone-only target.
  final Future<void> Function(Zone zone)? onDeleteZone;

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  final _scrollController = ScrollController();

  /// Shared between the placement gesture's press surface (the Stack's
  /// FIRST child, so task pills win presses over it) and the line it
  /// draws (the LAST child, so the line paints above every task) — see
  /// PlaceTaskLineLayer's own doc comment for why those can't be the same
  /// widget.
  final _placeLineController = PlaceTaskLineController(null);

  /// Ticks once a minute so the hour labels can keep hiding whichever one
  /// [CurrentTimeIndicator]'s bold "now" label would sit on top of. The
  /// indicator keeps its own timer for its own position — this one exists
  /// solely for the label-collision rule, which changes at most hourly.
  Timer? _minuteTimer;
  DateTime _now = DateTime.now();

  /// Which task (if any) is currently being dragged. Lifted up from
  /// [_DraggableTaskBlock] so its faded "ghost" — a copy left behind at the
  /// original slot for the duration of the drag — can be rendered as a
  /// direct sibling in this Stack, rather than nested inside a second Stack
  /// local to the dragged block. That nested-Stack version worked visually
  /// but inflated the dragged block's own hit-testable footprint to the
  /// full day-column height (Positioned.fill sizes to the ambient Stack's
  /// full bounds), which caused a real bug: the first drag attempt on a
  /// fresh install would arm (_isDragging flips true, shadow/labels show)
  /// but not visibly move, and only a second drag actually worked — a
  /// gesture-arena artifact from every task block's oversized hit region
  /// stacking on top of its neighbours. See docs/DECISIONS.md.
  String? _draggingTaskId;

  /// The delete-drag-target's own hit-testable `GlobalKey` — one shared
  /// instance for the whole day view, since only one target is ever
  /// rendered on screen (see `_DraggableTaskBlock.deleteTargetKey`'s own
  /// doc comment).
  final _deleteTargetKey = GlobalKey();

  /// True while ANY task is being dragged with Edit Mode active — drives
  /// the delete target's fade-in/out. A count rather than a bool so two
  /// blocks reporting drag-start/drag-end slightly out of order (which
  /// shouldn't happen — only one drag is ever active — but costs nothing
  /// to guard against) can't leave this stuck open or closed.
  int _deleteTargetVisibleCount = 0;
  bool _deleteTargetArmed = false;

  /// The task most recently dragged, kept until its drop has fully settled
  /// (the block clears it via `onDraggingChanged` only after its own
  /// settle animation finishes). Used ONLY for Stack ordering, never for
  /// the ghost — the ghost must vanish the instant the finger lifts,
  /// while the block's paint order has to stay stable a moment longer.
  ///
  /// Without this, releasing a drag moved the block back to its natural
  /// index mid-animation, which reset its AnimatedPositioned and made it
  /// animate from the wrong position — reported as a jump to a higher
  /// spot followed by an ease back down to the real drop.
  String? _settlingTaskId;

  /// Half an hour of scrollable space kept past a task that runs beyond
  /// the calendar day's own edges (see [_visibleRange]), so such a task
  /// isn't clipped right at the scroll boundary — its full pill (and time
  /// label) stays comfortably visible when scrolled all the way to that
  /// end.
  static const _rangePadding = Duration(minutes: 30);

  /// The day view's visible top/bottom edges: the FULL calendar day
  /// (midnight to midnight), always.
  ///
  /// Reverses an earlier decision that clamped this to the day's own
  /// earliest/latest task (±30min) so the view never scrolled into empty
  /// pre-dawn/late-night space. Reported directly: that made whole
  /// stretches of the day unreachable — a day whose only task ran
  /// 10:00–11:00 could only scroll 09:30–11:30, and an empty day couldn't
  /// scroll at all. Confirmed directly to switch to a plain 24h window.
  ///
  /// Still widened by [_rangePadding] past any task that genuinely falls
  /// outside the calendar day (a block running past midnight), so such a
  /// task stays reachable rather than being clipped at the boundary.
  (DateTime start, DateTime end) _visibleRange(List<Task> tasks) {
    final day = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    var earliest = day;
    var latest = day.add(const Duration(days: 1));
    for (final task in tasks) {
      final start = task.scheduledAt;
      final duration = task.durationMinutes;
      if (start == null || duration == null) continue;
      final end = start.add(Duration(minutes: duration));
      if (start.isBefore(earliest)) {
        earliest = start.subtract(_rangePadding);
      }
      if (end.isAfter(latest)) latest = end.add(_rangePadding);
    }
    return (earliest, latest);
  }

  @override
  void initState() {
    super.initState();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _scrollController.addListener(_reportViewedMinutes);
    // The day's FIRST task doesn't reach didUpdateWidget: the screen was
    // showing _EmptyDayState until a moment ago, so this widget mounts
    // fresh rather than updating. Handled here so saving the first task
    // of a day scrolls to it and clears the flag exactly like every
    // subsequent one does.
    if (widget.recentlySaved != null) {
      _revealSavedTask(widget.recentlySaved!);
      return;
    }
    _scrollToCurrentHourCentered();
  }

  /// Reports this view's own center position (minutes-since-midnight,
  /// projected onto whichever day is being viewed) up to `TimelineScreen`
  /// via [_DayTimeline.onViewedMinutesChanged] on every scroll, so a
  /// switch to Zone view (or back) can resume from here instead of always
  /// re-centering on "now". Mirrors the math [_scrollToCurrentHourCentered]
  /// uses to GO to a position, just inverted.
  void _reportViewedMinutes() {
    if (widget.onViewedMinutesChanged == null) return;
    if (!widget.showHourLabels) return;
    if (!_scrollController.hasClients) return;
    final (rangeStart, _) = _visibleRange(widget.tasks);
    // Subtract the scroll view's own top padding: at offset 0 the PADDING
    // sits at the viewport top, so the time axis itself starts one
    // padding-height further down, and the reported minute would otherwise
    // be `padding / pixelsPerMinute` off from what's actually centered.
    final centerOffset =
        _scrollController.offset +
        (_scrollController.position.viewportDimension / 2) -
        widget.theme.spacingLg;
    // Minutes from the START OF THE VIEWED DAY, not from `rangeStart`'s
    // own wall-clock time. Real bug behind "the spatial views go out of
    // sync": `rangeStart` is normally midnight (0), but a task or zone
    // crossing midnight widens it into the PREVIOUS day, at which point
    // `rangeStart.hour * 60 + rangeStart.minute` reads 1410 (23:30)
    // instead of -30 — a 24-hour error injected into the shared value.
    // The two views widen their ranges from different inputs (Task view
    // from tasks only, Zone view from zones AND tasks), so they could
    // disagree about `rangeStart` and therefore about what the same
    // shared number means. Anchoring on the day itself removes that
    // coupling entirely.
    final day = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final minutes =
        rangeStart.difference(day).inMinutes +
        (centerOffset / widget.pixelsPerMinute).round();
    widget.onViewedMinutesChanged!(minutes.clamp(0, 24 * 60));
  }

  /// Scrolls so a remembered time-of-day sits in the MIDDLE of the
  /// viewport — the position last centered in EITHER spatial view (see
  /// [_DayTimeline.readViewedMinutes]/`viewed_time_provider.dart`), or
  /// "now" when there's nothing remembered yet (a fresh app open). Falls
  /// back to the nearer range edge when the target isn't inside it at all
  /// (every day but today, for the "now" fallback, since the range is a
  /// full calendar day).
  ///
  /// Re-run (not just on first mount) when the day being viewed changes —
  /// requested directly ("should always lead to the current hour being in
  /// the center" for a fresh day). Switching view mode (hour labels on/off,
  /// or the separate Zone/Task widget swap) deliberately does NOT re-run
  /// this any more — reversed per direct follow-up request: scroll
  /// position should be REMEMBERED across view switches, not reset to
  /// "now" every time.
  void _scrollToCurrentHourCentered() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Deliberately NOT skipped for an empty day any more: the range is
      // now the full 24h calendar day, so opening at its top would land
      // on midnight. An empty day should open at "now" like any other.
      // Collapsed mode has no time axis to scroll "to now" against, and
      // its stack is short enough that opening at the top is right.
      if (!widget.showHourLabels) return;
      if (!_scrollController.hasClients) return;
      final (rangeStart, rangeEnd) = _visibleRange(widget.tasks);
      final remembered = widget.readViewedMinutes?.call();
      // Anchors on a TIME OF DAY projected onto the day being viewed, not
      // on `now` itself — with the range now a full 24h calendar day,
      // `now` falls outside it for every day but today, and the old
      // fallback (`rangeStart`) would open those days scrolled to
      // midnight. Same current-hour (or remembered) position on any day.
      final now = DateTime.now();
      final anchorMinutes = remembered ?? (now.hour * 60 + now.minute);
      final anchor = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      ).add(Duration(minutes: anchorMinutes));
      final minutesSinceStart = anchor.isBefore(rangeStart)
          ? 0
          : anchor.isAfter(rangeEnd)
          ? rangeEnd.difference(rangeStart).inMinutes
          : anchor.difference(rangeStart).inMinutes;
      // + spacingLg mirrors _reportViewedMinutes' own subtraction of it —
      // the two must stay exact inverses or a round trip drifts.
      final target =
          (minutesSinceStart * widget.pixelsPerMinute) +
          widget.theme.spacingLg -
          (_scrollController.position.viewportDimension / 2);
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
    });
  }

  @override
  void didUpdateWidget(_DayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    final saved = widget.recentlySaved;
    if (saved != null && saved.taskId != oldWidget.recentlySaved?.taskId) {
      _revealSavedTask(saved);
      return;
    }
    // A fresh quick-create draft needs the SAME "scroll it into view"
    // treatment a saved task gets — reported directly: tapping empty
    // space after 20:00 dropped the draft and opened the mini sheet
    // right on top of it, with the sheet's own bottom ~34% of the screen
    // (`quickCreateSheetMinFraction`) covering exactly the hour range the
    // user just tapped. Keyed on the draft's id (like `saved.taskId`
    // above) so this fires once per NEW draft, not on every rebuild while
    // one is being dragged/resized.
    final draft = widget.pendingDraft;
    if (draft != null && draft.id != oldWidget.pendingDraft?.id) {
      _revealPendingDraft(draft);
    }
    // Re-centers when the day being viewed changes (fresh day -> open on
    // "now"), and when hour labels come back ON — i.e. a List -> Task
    // switch.
    //
    // That second case is NOT the "reset to now on every view switch"
    // behavior that was previously reversed out: this widget is SHARED by
    // List view and Task view (only `showHourLabels` differs), so the two
    // never remount across that switch and `initState` never re-runs.
    // Scrolling in List view therefore moves this same controller's raw
    // pixel offset, and — because both the report and restore paths bail
    // out early while `showHourLabels` is false — nothing recorded or
    // restored the shared time. Coming back to Task view simply inherited
    // whatever offset List view had left behind. Reported directly:
    // "scroll level resets after list." Restoring from
    // the shared time here is what makes List view a genuine no-op
    // on the shared spatial position, rather than silently corrupting it.
    if (widget.selectedDate != oldWidget.selectedDate ||
        (widget.showHourLabels && !oldWidget.showHourLabels)) {
      _scrollToCurrentHourCentered();
    }
  }

  /// Scrolls the just-saved task into view, then releases the flag once
  /// its entrance has had time to play — requested directly: "should also
  /// upon closing scroll to the timeline point of start hour so the new
  /// created task or updated is in view."
  void _revealSavedTask(RecentlySavedTask saved) {
    // Post-frame because the task may only have just been added to this
    // build's task list, so its position isn't laid out yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Deliberately NOT delayed like the block's own entrance is: the
      // scroll has to be FINISHED by the time the entrance starts, or the
      // task animates in off-screen. It runs for motionNormal (250ms)
      // inside the entrance's own motionRouteSettle (500ms) wait, so it
      // lands with room to spare — keep that ordering if either changes.
      _scrollToSavedTask(saved.taskId);
      // Cleared only AFTER the entrance has had time to play — the block
      // reads `recentlySaved` on its first build to decide whether to
      // fade, so clearing it any earlier would rebuild the block without
      // the flag before it ever animated. The wait covers the modal's own
      // dismissal (motionRouteSettle, which the block waits out before
      // starting) PLUS the animation itself.
      Future<void>.delayed(
        widget.theme.motionRouteSettle + widget.theme.motionSlow,
        () {
          if (mounted) widget.onSavedTaskConsumed();
        },
      );
    });
  }

  void _scrollToSavedTask(String taskId) {
    if (!widget.showHourLabels) return;
    if (!_scrollController.hasClients) return;
    final task = widget.tasks
        .where((candidate) => candidate.id == taskId)
        .firstOrNull;
    // Saved onto a different day than the one on screen — nothing to
    // scroll to here, and the animation simply won't play either.
    if (task == null) return;

    final (rangeStart, _) = _visibleRange(widget.tasks);
    final minutesSinceStart = task.scheduledAt!
        .difference(rangeStart)
        .inMinutes;
    // Centred rather than pinned to the top, matching how the view already
    // opens on "now" — a task flush against the viewport edge reads as
    // cut off rather than as the thing being shown.
    final target =
        (minutesSinceStart * widget.pixelsPerMinute) -
        (_scrollController.position.viewportDimension / 2);
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: widget.theme.motionNormal,
      curve: Curves.easeOut,
    );
  }

  /// Scrolls a freshly-tapped quick-create draft into the space ABOVE the
  /// mini sheet, not the whole viewport — the bug this exists to fix.
  /// [_scrollToSavedTask] centres in the FULL screen height because
  /// nothing else is covering it once the sheet that created that task
  /// has closed; the quick-create sheet is still open and pinned to the
  /// bottom `quickCreateSheetMinFraction` of the screen the whole time
  /// its own pill is meant to stay visible, so centring against the full
  /// height still hides anything tapped in roughly the bottom third
  /// (reported directly: tapping after 20:00 put the draft under the
  /// sheet with "can't see").
  void _revealPendingDraft(PendingTaskDraft draft) {
    // Post-frame, like `_revealSavedTask` — and load-bearing here for a
    // second reason beyond that method's own (layout not being ready
    // yet): the SCROLLABLE'S OWN CONTENT HEIGHT changes in this same
    // rebuild (the bottom padding reserved for the mini sheet, see the
    // SingleChildScrollView above), so `maxScrollExtent` read
    // synchronously here — mid-`didUpdateWidget`, before that new padding
    // has been laid out — is still the OLD, smaller value. Reading it
    // clamped the target back down to roughly where it started, which is
    // exactly the bug this method exists to fix: confirmed by a failing
    // test that only started passing once this moved past a frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToPendingDraft(draft);
    });
  }

  void _scrollToPendingDraft(PendingTaskDraft draft) {
    if (!widget.showHourLabels) return;
    if (!_scrollController.hasClients) return;

    final (rangeStart, _) = _visibleRange(widget.tasks);
    final minutesSinceStart = draft.scheduledAt
        .difference(rangeStart)
        .inMinutes;
    // The sheet's own height is `quickCreateSheetMinFraction` of the
    // PHYSICAL SCREEN (see QuickCreateOverlay/quick_create_sheet_shell.dart),
    // not of this scroll viewport — the two differ by whatever chrome
    // (day header, nav bar) sits outside the scrollable. Computing the
    // sheet's pixel height against the wrong dimension undershoots it,
    // which is exactly why an earlier version of this method left the
    // pill just a few pixels short of clearing the sheet instead of
    // clearly above it.
    final sheetHeight =
        MediaQuery.sizeOf(context).height * quickCreateSheetMinFraction;
    final visibleHeight =
        _scrollController.position.viewportDimension - sheetHeight;
    final target =
        (minutesSinceStart * widget.pixelsPerMinute) - (visibleHeight / 2);
    _scrollController.animateTo(
      target.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: widget.theme.motionNormal,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _scrollController.dispose();
    _placeLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tasks = widget.tasks;
    // tasks CAN be empty here: an empty day now renders this timeline
    // (so it still scrolls) with _EmptyDayState floating over it, rather
    // than replacing it — see TimelineScreen's own build. _visibleRange
    // no longer derives from the task list, so an empty list is fine.
    final (rangeStart, rangeEnd) = _visibleRange(tasks);
    // Every task AND every imported calendar event, as one list of
    // [ScheduledBlock]s — **2026-09-07** (confirmed directly: "the
    // imported tasks should also stack in the same way as native
    // tasks... otherwise exactly the same, with different styling"),
    // reversing the earlier "events position independently, no lane/
    // cluster awareness" design. Feeding both into the SAME
    // `layoutOverlappingTasks`/`detectOverlapClusters` calls below is
    // what lets an event share a lane with a task, or join a cluster's
    // row list — a separate parallel computation for events (the
    // previous design) could never make the two agree on who's
    // colliding with whom.
    //
    // The quick-add placeholder joins this list too — **2026-09-08**,
    // reversing its original "positioned absolutely, invisible to the
    // layout" treatment after that was questioned directly. Same
    // precedent as events: a block positioning itself outside this
    // pipeline can never agree with it about who is colliding with whom,
    // and the draft was painting over tasks in positions the Schedule
    // button would then refuse to save. Cascade remains save-time only —
    // sharing a lane is layout, not cascade.
    // List view only ("affects list view only", requested directly) —
    // Task view's `blocks` list is untouched regardless of either toggle.
    final isListMode = !widget.showHourLabels;
    final filteredTasks = isListMode && widget.devListOnlyImportant
        ? tasks.where((t) => t.isImportant).toList()
        : tasks;
    final filteredExternalEvents = isListMode && widget.devHideImportedTasks
        ? const <ExternalCalendarEvent>[]
        : widget.externalEvents;
    final blocks = <ScheduledBlock>[
      ...filteredTasks,
      ...filteredExternalEvents,
      if (widget.showHourLabels && widget.pendingDraft != null)
        widget.pendingDraft!,
    ];
    // Applies in BOTH Timeline mode and collapsed (List) mode — requested
    // directly: List mode should follow the same overlap-clustering
    // behavior Task view already has, not just its own plain
    // `layoutOverlappingTasks` side-by-side column split. Detection re-runs
    // from the CURRENT task list on every build, so a drop that
    // creates/dissolves a cluster (task 5/6 of the work order this
    // clustering feature originally shipped under) is picked up
    // automatically on the very next rebuild after the reschedule write
    // lands — no separate "recompute clusters" step is needed. (Dragging
    // itself stays Timeline-mode-only — see `isDraggable` below — so the
    // `_draggingTaskId` exclusion here is simply always null in List mode,
    // not a separate branch.)
    //
    // The task actively being dragged is excluded from the set clusters
    // are computed FROM: per direct requirement, a dragged task renders
    // completely normally — its own full capsule — regardless of what's
    // underneath it, and the blocks it would otherwise cluster with must
    // likewise stay as their own ordinary capsules while it's away, not
    // silently form a smaller cluster among themselves mid-drag. An
    // event's id never matches `_draggingTaskId` (events are never
    // draggable), so this exclusion is a no-op for them, same as always.
    final clusters = widget.disableClustering
        ? const <OverlapCluster>[]
        : detectOverlapClusters(
            _draggingTaskId == null
                ? blocks
                : blocks.where((b) => b.id != _draggingTaskId).toList(),
          );
    final clusteredIds = clusteredTaskIds(clusters);
    // The dragged block's ghost (left behind at its ORIGINAL slot, see the
    // loop below) needs the lane it held as a resting cluster member, not
    // an ordinary layoutOverlappingTasks column — those two schemes don't
    // agree, and mixing them made the ghost land in a lane that visually
    // collided with the remaining members' now-recomputed fixed lanes,
    // reported directly as "items go in 2 lanes and a transparent one."
    // Computed WITHOUT the drag exclusion above, purely for this purpose.
    final restingClusters = widget.disableClustering
        ? const <OverlapCluster>[]
        : detectOverlapClusters(blocks);
    final slots = _dragLastOrder(
      _withClusterLanes(layoutOverlappingTasks(blocks), clusters),
    );
    // The RESTING lane layout — computed from `restingClusters`, i.e.
    // WITHOUT the drag exclusion above, so it is stable for the whole
    // duration of a drag.
    //
    // Used for the ghost's own lane (see `_ghostSlotFor`) and, just as
    // importantly, for every width measured off lane depth: the zone band
    // and the shared text column. Real bug, reported directly — "when one
    // of stacked items is lifted the zones shrink and titles shift left,
    // as if ghost not holding physical space." Measuring those off `slots`
    // meant lifting one member of a stack dropped the day's deepest lane
    // count by one, so the band narrowed and every name jumped left for
    // the duration of the drag. The ghost occupies its lane visually, so
    // the layout has to reserve it too.
    final ghostSlots = _withClusterLanes(
      layoutOverlappingTasks(blocks),
      restingClusters,
    );
    // The quick-add placeholder's own slot, pulled out of the shared
    // layout so its (separately-stateful, drag-tracking) widget can be
    // positioned with the lane the layout assigned it. It is rendered by
    // `_DraggablePendingTaskPill` below rather than by the ordinary slot
    // loop, because unlike a real task it writes to the draft provider
    // rather than the repository — but it occupies a real lane either way.
    final draftId = widget.pendingDraft?.id;
    final draftSlot = draftId == null
        ? null
        : slots.where((s) => s.block.id == draftId).firstOrNull;
    // In Timeline mode, task tops are real elapsed-time math and external
    // events already position independently via the same math — no shared
    // cursor needed, since real time-to-pixel positions can't collide by
    // construction the way an arbitrary stacking cursor can. Collapsed
    // (List) mode is the one case needing ONE shared cursor across both —
    // see _collapsedTops' own doc comment for why.
    // One map for every block's `top`, task or event alike — see
    // `_collapsedTops`'s own doc comment for why the old two-map split
    // (`taskTops`/`externalEventTops`) no longer matches reality now that
    // an event can share a lane/cluster with tasks. In Task view an
    // event's own `top` is still computed independently inside
    // `ExternalEventCapsuleBlock` from real elapsed time (`_blockTops`
    // only ever populates task ids there), so this map is genuinely
    // task-only in that mode and genuinely mixed in List mode — every
    // *caller* reads it the same way regardless.
    final blockTops = widget.showHourLabels
        ? _blockTops(slots, rangeStart, theme)
        : _collapsedTops(slots, restingClusters, theme);
    // List mode only — Task view's zone bands are positioned by
    // `ZoneBackgroundBlock`'s own real-time math directly from
    // `widget.zones`, with no equivalent precomputed geometry needed here.
    final collapsedZoneBandsList = widget.showHourLabels
        ? const <CollapsedZoneBand>[]
        : _collapsedZoneBands(
            filteredTasks,
            filteredExternalEvents,
            blockTops,
            theme,
          );

    // Task view: each task's NAME wants to sit level with its own pill's
    // icon (i.e. at the pill's own top), and only gets pushed down when it
    // would collide with the label above it — requested directly. Computed
    // once here for the whole day so every label agrees, the same way the
    // shared text column's x is.
    // Event slots are excluded: an ExternalEventCapsuleBlock has no
    // "name label pushed below the icon on collision" mechanism at all
    // (unlike TaskCapsuleBlock's own split layout) — its title sits
    // fixed in the shared text column, so there is nothing for this
    // collision-avoidance pass to compute FOR an event slot in the first
    // place.
    final labelTops = widget.showHourLabels
        ? computeLabelTops(
            anchors: [
              for (final slot in slots)
                if (slot.task != null)
                  LabelAnchor(
                    id: slot.block.id,
                    preferredTop: blockTops[slot.block.id]!,
                    height: _labelHeight(theme),
                  ),
            ],
            gap: theme.spacingXs,
          )
        : const <String, double>{};
    // Timeline mode's height is the real elapsed span. Collapsed mode has
    // no span — its height is just however far the stack reached, plus
    // the last block's own height. Includes external event rows now that
    // they can extend the stack past the last task row.
    final contentHeight = widget.showHourLabels
        ? rangeEnd.difference(rangeStart).inMinutes * widget.pixelsPerMinute
        : math.max(
            slots.fold<double>(0, (tallest, slot) {
              // Only task slots here — an event slot's own height is
              // folded separately just below, via `widget.externalEvents`
              // and `_collapsedExternalEventHeight` (that math is
              // event-specific and unrelated to lane/cluster sharing).
              final task = slot.task;
              if (task == null) return tallest;
              return math.max(
                tallest,
                blockTops[slot.block.id]! + _collapsedBlockHeight(task, theme),
              );
            }),
            math.max(
              widget.externalEvents.fold<double>(
                0,
                (tallest, event) => math.max(
                  tallest,
                  (blockTops[event.id] ?? 0) +
                      _collapsedExternalEventHeight(event, theme),
                ),
              ),
              // An empty zone's placeholder band (see `_collapsedZoneBands`)
              // can land after every real row, which none of the folds
              // above would otherwise account for.
              collapsedZoneBandsList.fold<double>(
                0,
                (tallest, band) => math.max(tallest, band.top + band.height),
              ),
            ),
          );
    final pixelsPerMinute = widget.showHourLabels
        ? widget.pixelsPerMinute
        : _collapsedPixelsPerMinute(theme);
    // Collapses to 0 when the Settings toggle is off, so tasks/connectors/
    // the now-line reclaim the space rather than leaving a blank margin —
    // confirmed via AskUserQuestion over the alternative (keep the width
    // reserved but empty).
    // Absorbs the horizontal screen padding the scroll view no longer
    // applies (see its `padding:` note below): every content child in the
    // timeline Stack already positions from this one value, so folding
    // the inset in here keeps them all exactly where they were while
    // letting the Stack itself span the full viewport width.
    final hourGutterWidth =
        (widget.showHourLabels ? _hourGutterWidth : 0.0) +
        theme.spacingScreenPadding;

    /// The matching inset on the RIGHT, for children that previously
    /// stopped at the padded viewport's own edge (`right: 0`). Governs pill
    /// positioning, the drag-lift frosted pane, and the overlap-cluster
    /// row's own edge — NOT the checkbox column, see [textColumnRightInset]
    /// below.
    final rightEdgeInset = theme.spacingScreenPadding;

    /// The right inset for a task row's time/title/checkbox column
    /// specifically — narrower than [rightEdgeInset] on direct request:
    /// "in spatial view... parent container could be wider even though
    /// it's reaching edge we have some room to the right," confirmed as
    /// "the 24px margin itself is too generous here specifically" (not the
    /// shared page margin every other screen uses — scoped to just this
    /// column). `spacingMd` (16px) rather than `spacingScreenPadding`
    /// (24px): still a real gap, but the checkbox now sits noticeably
    /// closer to the true edge than the rest of the day's own margins.
    final textColumnRightInset = theme.spacingMd;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Floors the day's own height at the viewport's, so the timeline
        // surface/gutter/markers always reach the bottom of the screen
        // rather than stopping short and reading as a "cut off" container
        // (reported directly back when `_visibleRange` was task-derived
        // and could be very short). The range is a full calendar day now,
        // so this floor rarely binds — it still matters in collapsed mode
        // (`showHourLabels` off), whose `contentHeight` is just however
        // far the stacked blocks reached. Must subtract the SAME vertical
        // padding the SingleChildScrollView below applies, since that
        // counts as consumed viewport space.
        final dayHeight = math.max(
          contentHeight,
          constraints.maxHeight - theme.spacingLg * 2,
        );

        // Wraps the scrollable day in a Stack so the delete target (Edit
        // Mode's drag-to-delete drop zone) can be pinned to the VIEWPORT'S
        // own bottom edge, fixed regardless of scroll position — it must
        // not be a child of the SingleChildScrollView below, or it would
        // scroll away with the content instead of staying reachable
        // throughout a drag. `IgnorePointer` inside `EditModeDeleteTarget`
        // itself means this overlay never blocks a scroll/tap on the
        // content underneath even while visible.
        return Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              // Deliberately CLIPPED (the framework default) — reported directly:
              // with Clip.none the scrolled day painted straight over the header
              // (day nav arrows, date, Today button) as it moved past, since a
              // Column sibling that paints outside its own bounds isn't contained
              // by anything. Clipping here is what keeps the header visually on
              // top.
              //
              // This was briefly Clip.none to stop the drag lift shadow being
              // trimmed at the viewport edge. That trade isn't needed: the inner
              // Stack below stays unclipped, so a lifted block's shadow still
              // spills freely over its neighbours (the case that actually
              // mattered) — only the shadow of a block dragged hard against the
              // very top/bottom of the scroll viewport gets cut, which is the
              // same edge behaviour every scrollable surface has.
              // spacingLg vertically, not spacingMd: every hour label is
              // centered ON its own tick line (TaskBoundaryMarkers applies a
              // -0.5 FractionalTranslation), so the label at the range's very
              // first tick extends half its own height ABOVE the content box,
              // and the one at the last tick sits flush against the bottom.
              // With the range now a full calendar day, those are the 00:00
              // labels at both ends — reported directly as being clipped.
              // spacingMd (12px) wasn't enough to clear half a caption line.
              // Bottom padding grows to reserve room for the mini sheet
              // while a quick-create draft is active — otherwise the
              // scroll content's own natural end (midnight) sits at the
              // bottom of the FULL viewport with nothing extra to scroll
              // past, so `_revealPendingDraft`'s target gets clamped to a
              // `maxScrollExtent` that still leaves the sheet covering
              // whatever was tapped. Reported directly: tapping after
              // 20:00 put the draft under the sheet with "can't see."
              // `quickCreateSheetMinFraction` is the sheet's own
              // proportion of the SCREEN, not of this scroll viewport, so
              // it's applied against the physical screen height via
              // MediaQuery, matching how the sheet itself sizes.
              // NO horizontal padding — deliberately, and this is what
              // makes the tap-to-create ripple reach the screen edges.
              // Reported directly: "there is some padding or margin on
              // the right because, of the entire viewport in the timeline,
              // I can see that when tapping, the ripple is cut off. Let's
              // remove this. This will give us more horizontal real
              // estate... the individual inner elements would have their
              // own padding."
              //
              // The inset moved INWARD instead: `hourGutterWidth` below
              // absorbs it on the left (every content child already
              // positions from that one value), and each child's own
              // `right:` adds it back on the right. So content sits
              // exactly where it did, while the Stack — and the
              // full-bleed tap layer inside it — spans the whole width.
              padding: EdgeInsets.only(
                top: theme.spacingLg,
                bottom:
                    theme.spacingLg +
                    (widget.pendingDraft != null
                        ? MediaQuery.sizeOf(context).height *
                              quickCreateSheetMinFraction
                        : 0),
              ),
              child: SizedBox(
                height: dayHeight,
                child: Stack(
                  // A dragged block's lift shadow extends well beyond the block's
                  // own bounds, and a Stack clips to its bounds by default — which
                  // silently cut the shadow off. Reported as "can't see it on
                  // iPhone": clipping and shadow rasterisation differ between
                  // Impeller (iOS) and the Android renderer, so the same clip made
                  // the shadow invisible on one platform and merely trimmed on the
                  // other.
                  clipBehavior: Clip.none,
                  children: [
                    // FIRST child, deliberately — see PlaceTaskLineLayer's own doc
                    // comment for why its position in this list (not just its
                    // hit-test behaviour) is what keeps it from intercepting
                    // presses meant for a task pill or a free-window block.
                    // Timeline mode only: the placement line's whole job is
                    // converting a Y position into a real time, which collapsed
                    // mode's stacking layout has no meaningful mapping for.
                    if (widget.showHourLabels)
                      PlaceTaskLineLayer(
                        theme: theme,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        pixelsPerMinute: widget.pixelsPerMinute,
                        controller: _placeLineController,
                        onPlaced: widget.onCreateAt,
                        onTapAt: widget.onEmptyTap,
                      ),
                    if (widget.showHourLabels)
                      TaskBoundaryMarkers(
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        pixelsPerMinute: widget.pixelsPerMinute,
                        hideLabelNear: _now,
                        // LEFT-aligned at the same `spacingScreenPadding`
                        // the rotated zone names sit in from the right
                        // edge — so the two annotations frame the day
                        // symmetrically. Requested directly: "these
                        // should have same padding as zone names on the
                        // other side[,] left aligned."
                        //
                        // `columnWidth` is deliberately NOT passed: it is
                        // what switches these labels to right-aligned
                        // (see TaskBoundaryMarkers), which an earlier
                        // request had asked for and this one reverses.
                        leftInset: theme.spacingScreenPadding,
                      ),
                    // Zone background blocks — purely decorative, rendered
                    // BEHIND every task capsule (this Stack paints in child-
                    // list order, and every task-rendering child comes later
                    // in this same list). Timeline mode only, same reasoning
                    // as every other time-positioned background element here:
                    // collapsed mode has no time axis for a zone's start/end
                    // to mean anything against. Per CONSTITUTION.md's Zone
                    // section, this does NOT filter by whether any task
                    // actually references the zone — every persisted zone
                    // renders for its time range regardless.
                    if (widget.showHourLabels)
                      for (final zone in widget.zones)
                        // Wiggle applies here too — Edit Mode's persistent
                        // signal covers every visible Zone rendering.
                        // Move/resize now live here too (**2026-09-06**,
                        // reversed from the earlier purely-decorative
                        // scope — see `_DraggableZoneBlock`'s own doc
                        // comment), via the same `_commitZoneCascade`
                        // path `ZoneContainerBlock` (Zone view) uses.
                        _DraggableZoneBlock(
                          key: ValueKey(zone.id),
                          theme: theme,
                          zone: zone,
                          day: widget.selectedDate,
                          rangeStart: rangeStart,
                          pixelsPerMinute: widget.pixelsPerMinute,
                          left: hourGutterWidth,
                          // Hugs the PILL COLUMN rather than spanning the
                          // whole row — the time and task-name columns
                          // sit outside the zone band, on the plain page.
                          // Sized to THIS zone's own occupied lanes so the
                          // space right of its pills matches the space
                          // left of them; see `_zoneBackgroundWidth` for
                          // why that beat the earlier uniform-width rule
                          // where the two clashed.
                          width: _zoneBackgroundWidth(ghostSlots, theme),
                          editModeEnabled: widget.editModeEnabled,
                          phaseOffset: (zone.id.hashCode % 1000) / 1000,
                          onZoneResize: widget.onZoneResize,
                          onZoneMove: widget.onZoneMove,
                          // Same shared delete target every task drag
                          // already uses — requested directly: "zones
                          // cant see remove... dragging zone should
                          // remove zone appear like with tasks."
                          deleteTargetKey: widget.editModeEnabled
                              ? _deleteTargetKey
                              : null,
                          onDeleteTargetVisibilityChanged: (visible) =>
                              setState(
                                () => _deleteTargetVisibleCount += visible
                                    ? 1
                                    : -1,
                              ),
                          onDeleteTargetArmedChanged: (armed) =>
                              setState(() => _deleteTargetArmed = armed),
                          onDeleteZone: widget.onDeleteZone,
                        ),
                    // The zone's name, rotated down the RIGHT edge of the day
                    // — requested directly ("can't see vertical zone name on
                    // task view"), styled like the hour labels on the opposite
                    // edge so the two frame the day as the same kind of
                    // ambient annotation. A sibling of the band above, not a
                    // child: the band hugs the pill column on the left, while
                    // this belongs at the far right.
                    if (widget.showHourLabels)
                      for (final zone in widget.zones)
                        ZoneNameLabel(
                          theme: theme,
                          zone: zone,
                          day: widget.selectedDate,
                          rangeStart: rangeStart,
                          pixelsPerMinute: widget.pixelsPerMinute,
                          width: theme.spacingLg,
                        ),
                    // List mode's own zone bands — same widgets, but positioned
                    // from `_collapsedZoneBands`' member-task-derived geometry
                    // instead of real time-to-pixel math (which has nothing to
                    // measure against here — see that method's own doc
                    // comment). `rangeStart`/`pixelsPerMinute` are still passed
                    // (required params) but ignored whenever `collapsedTop`/
                    // `collapsedHeight` are set.
                    if (!widget.showHourLabels)
                      for (final band in collapsedZoneBandsList)
                        ZoneBackgroundBlock(
                          theme: theme,
                          zone: band.zone,
                          day: widget.selectedDate,
                          rangeStart: rangeStart,
                          pixelsPerMinute: widget.pixelsPerMinute,
                          left: hourGutterWidth,
                          width: _zoneBackgroundWidth(ghostSlots, theme),
                          collapsedTop: band.top,
                          collapsedHeight: band.height,
                        ),
                    if (!widget.showHourLabels)
                      for (final band in collapsedZoneBandsList)
                        ZoneNameLabel(
                          theme: theme,
                          zone: band.zone,
                          day: widget.selectedDate,
                          rangeStart: rangeStart,
                          pixelsPerMinute: widget.pixelsPerMinute,
                          width: theme.spacingLg,
                          collapsedTop: band.top,
                          collapsedHeight: band.height,
                        ),
                    // Read-only external calendar events (Feature 1) no
                    // longer render in a separate loop here — **2026-09-07**
                    // (confirmed directly: "the imported tasks should also
                    // stack in the same way as native tasks... otherwise
                    // exactly the same, with different styling"), reversing
                    // the "always lane 0, excluded from clustering" design
                    // this comment used to describe. An event is now one
                    // more entry in `blocks` (see this build method's own
                    // top), flows through the SAME `layoutOverlappingTasks`/
                    // `detectOverlapClusters` calls tasks do, and renders
                    // through the `for (final slot in slots)` loop below —
                    // see that loop's own `else if (slot.block case final
                    // ExternalCalendarEvent event)` branch. Still NOT
                    // draggable/resizable/completable — only the existing
                    // tap-for-info sheet stays (see `ExternalEventCapsuleBlock`'s
                    // own doc comment for why it's a separate widget, not
                    // `TaskCapsuleBlock` reused with a fake `Task` wrapper).
                    // A cluster containing an event renders that event's row
                    // in `OverlapClusterBlock`'s own flat list too — see that
                    // widget's own updated doc comment.
                    //
                    // A visible gray thread connecting every consecutive pair of
                    // tasks, matching a reference design — requested directly.
                    // Painted before the task blocks so the blocks sit on top.
                    // Timeline mode only: the connector's whole job is to show
                    // the run of real time between two tasks, which collapsed
                    // mode deliberately doesn't represent. Further gated by its
                    // own Settings toggle (show/hide, Task view only) —
                    // requested directly.
                    if (widget.showHourLabels && widget.showTimelineConnectors)
                      _TimelineConnectors(
                        tasks: tasks,
                        theme: theme,
                        rangeStart: rangeStart,
                        pixelsPerMinute: widget.pixelsPerMinute,
                        hourGutterWidth: hourGutterWidth,
                      ),
                    // A subtle labeled block for any gap of freeWindowThreshold or
                    // longer between two tasks — requested directly: "no indicator
                    // for small/normal gaps... a labeled, size-appropriate compact
                    // block only for large gaps." Timeline mode only, same
                    // reasoning as the connectors above: collapsed mode has no
                    // time axis for a gap's size to mean anything against.
                    if (widget.showHourLabels && widget.showFreeWindowPrompt)
                      for (final window in findFreeWindows(
                        tasks,
                        // Mirrors the pill-height floor TaskCapsuleBlock applies
                        // (see _pillHeight above) — without this, a free window
                        // computed from raw scheduled times could start before a
                        // short task's actual RENDERED pill has finished, and the
                        // two visually overlapped. Reported directly.
                        minPillMinutes:
                            _pillWidth(theme) / widget.pixelsPerMinute,
                      ))
                        FreeWindowBlock(
                          theme: theme,
                          window: window,
                          // Inset top/bottom by spacingSm so the block never
                          // touches the task immediately before/after it —
                          // reported directly: "should have gap from top and
                          // bottom so not fully adjacent [to the] tasks between
                          // which it indicates the gap." Symmetric: shrinking the
                          // window by the inset on BOTH ends, not just padding
                          // visually inside a full-height box, is what actually
                          // creates real empty space above and below.
                          top:
                              _minutesSinceStart(rangeStart, window.start) *
                                  widget.pixelsPerMinute +
                              theme.spacingSm,
                          height:
                              window.duration.inMinutes *
                                  widget.pixelsPerMinute -
                              theme.spacingSm * 2,
                          // Aligned with task NAMES, not the icon-pill column —
                          // corrected directly: "left indent[should be] of size
                          // of the pill of tasks + padding/gap between pill and
                          // description... the window container is [a]ligned up
                          // with names of tasks." pillWidth + spacingSm mirrors
                          // exactly the SizedBox TaskCapsuleBlock puts between
                          // its icon pill and its title/time column.
                          left:
                              hourGutterWidth +
                              _pillWidth(theme) +
                              theme.spacingSm,
                          onTap: () => widget.onCreateAt(window.start),
                        ),
                    // Overlapping tasks are laid out side by side rather than
                    // stacked on top of each other — Amble never moves a task the
                    // user didn't drag (cascade replanning is out of MVP scope,
                    // see docs/SCOPE.md), so a clash stays visible instead.
                    //
                    // The dragged block is emitted LAST so it paints above every
                    // other block — reported directly: a block being dragged past
                    // its neighbours slid underneath the ones that happened to
                    // come later in layout order. A Stack paints in child order
                    // and has no z-index, so "always on top" has to be an
                    // ordering change, not a property. Only the dragged block
                    // moves in the list; everything else keeps its existing
                    // relative order, so nothing else's stacking changes.
                    //
                    // Clustered tasks now render THROUGH this same loop, not a
                    // separate one — requested directly ("should be able to still
                    // drag and move around the clustered items"). Each clustered
                    // slot already carries its fixed cluster lane (see
                    // _withClusterLanes) and renders with `contentHidden: true`
                    // while resting (icon/title/time hidden, checkbox and drag
                    // still live — see TaskCapsuleBlock.contentHidden), falling
                    // back to full content automatically the moment it's the one
                    // being dragged (_DraggableTaskBlock forces contentHidden off
                    // while _isDragging is true). The cluster's own flat list
                    // (rendered separately, below) is what still shows title/time
                    // for a resting member.
                    for (final slot in slots) ...[
                      // The dragged block's faded "ghost", left behind at its
                      // original slot for the duration of the drag — a direct
                      // sibling here (not nested inside _DraggableTaskBlock's own
                      // Stack) so it can't inflate that block's hit-test region.
                      // Non-interactive (IgnorePointer) so it never intercepts the
                      // drag/tap gestures meant for the real block on top of it.
                      //
                      // `slot.task` (not `slot.block`) — a ghost only ever
                      // exists for the actively-dragged item, and an
                      // ExternalCalendarEvent is never draggable at all, so
                      // `_draggingTaskId` can never equal an event's id. This
                      // whole branch is naturally a no-op for an event slot.
                      if (slot.task case final draggedTask?
                          when _draggingTaskId == draggedTask.id)
                        Positioned(
                          // Keyed so its insertion/removal can't disturb element
                          // matching for the keyed sibling block right after it.
                          // Without this, releasing a drag (which removes the
                          // ghost) could make Flutter re-create the real block's
                          // element instead of updating it, resetting its
                          // AnimatedPositioned to animate from the GHOST's
                          // position — reported as the block jumping to a higher
                          // spot and then easing back down to the actual drop.
                          key: ValueKey('ghost-${draggedTask.id}'),
                          top: blockTops[draggedTask.id]!,
                          left:
                              hourGutterWidth +
                              _ghostSlotFor(ghostSlots, draggedTask.id).column *
                                  (_pillWidth(theme) + _columnGap(theme)),
                          right: rightEdgeInset,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.2,
                              child: TaskCapsuleBlock(
                                task: draggedTask,
                                category:
                                    widget.categoryById[draggedTask.categoryId],
                                pixelsPerMinute: pixelsPerMinute,
                                compactText: !widget.showHourLabels,
                                showCompletionCheckbox:
                                    widget.showCompletionCheckbox,
                                // The ghost is a plain shape marking the slot
                                // the task came FROM — no title, time, icon or
                                // checkbox. Requested directly: "in ghost
                                // state we shouldn't have title and time and
                                // not icon when moving." The task's own text
                                // travels with the lifted pill instead (see
                                // `liftedTextInline`), so repeating it here
                                // would show the same task's name twice
                                // mid-drag. `glyphHidden` additionally drops
                                // the category emoji, which `contentHidden`
                                // alone deliberately keeps (it is a resting
                                // cluster member's only category cue) — the
                                // ghost wants none of it.
                                contentHidden: true,
                                glyphHidden: true,
                                bottomTrim: _zoneTaskBottomTrim(draggedTask),
                                maxPillHeight: _maxPillHeight(
                                  draggedTask,
                                  ghostSlots,
                                  blockTops,
                                ),
                                maxTextWidth:
                                    _ghostSlotFor(
                                          ghostSlots,
                                          draggedTask.id,
                                        ).column <
                                        _ghostSlotFor(
                                              ghostSlots,
                                              draggedTask.id,
                                            ).columnCount -
                                            1
                                    ? _pillWidth(theme)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      // A task slot renders through the real, interactive
                      // pipeline; an event slot (see the `else` branch
                      // below) renders a non-interactive
                      // ExternalEventCapsuleBlock at the SAME lane instead
                      // — **2026-09-07** (confirmed directly: "the imported
                      // tasks should also stack in the same way as native
                      // tasks... They just can't be moved, changed, or have
                      // their duration, time, or name updated, but
                      // otherwise exactly the same, with different
                      // styling").
                      if (slot.task case final task?)
                        _DraggableTaskBlock(
                          key: ValueKey(task.id),
                          task: task,
                          theme: theme,
                          baseTop: blockTops[task.id]!,
                          left: hourGutterWidth,
                          rightInset: rightEdgeInset,
                          slot: slot,
                          pixelsPerMinute: pixelsPerMinute,
                          // Only in List mode does a clustered task surrender its
                          // text to the cluster's own row list. In Task view
                          // every task keeps its own label (aligned to its pill's
                          // icon — see `labelTops`), so there is nothing to
                          // suppress and no duplicate to avoid.
                          contentHidden:
                              !widget.showHourLabels &&
                              clusteredIds.contains(task.id),
                          // Drag-to-reschedule needs a pixel->minute mapping, which
                          // collapsed mode doesn't have: vertical position there is
                          // stacking order, not time. Disabled rather than given a
                          // second, inconsistent meaning — confirmed via
                          // AskUserQuestion. "Edit time and duration" still works,
                          // and dragging returns as soon as hour labels are back on.
                          isDraggable: widget.showHourLabels,
                          compactText: !widget.showHourLabels,
                          showCompletionCheckbox: widget.showCompletionCheckbox,
                          // Both modes now: icon-only pill at its own lane x,
                          // name/time in the shared text column — requested
                          // directly, so List mode's names line up the same way
                          // Task view's already do regardless of lane depth.
                          splitLayout: true,
                          textColumnLeft: _textColumnLeft(theme, ghostSlots),
                          // How far the label sits BELOW its own pill's top —
                          // zero when nothing collides (perfectly icon-aligned),
                          // positive when the label above pushed it down. Passed
                          // as an offset rather than an absolute top so it rides
                          // the block's own drag/settle animation unchanged.
                          labelOffset:
                              (labelTops[task.id] ?? blockTops[task.id]!) -
                              blockTops[task.id]!,
                          // Always just `rightEdgeInset` now — no
                          // longer widened when zones exist. Requested
                          // directly, with a reference screenshot marking
                          // the new checkbox edge with a red line: the
                          // checkbox belongs at the TRUE screen edge, with
                          // the rotated zone-name label sharing that same
                          // outer margin rather than pushing the checkbox
                          // column inward to avoid it. The label's own
                          // `IgnorePointer` (ZoneNameLabel) means it can't
                          // steal the checkbox's taps even where the two
                          // visually share space.
                          textColumnRight: textColumnRightInset,
                          bottomTrim: _zoneTaskBottomTrim(task),
                          maxPillHeight: _maxPillHeight(task, slots, blockTops),
                          // Only the block for the task the modal just CREATED
                          // fades in. A duration change animates via the pill's own
                          // AnimatedContainer instead (see TaskCapsuleBlock) — that
                          // block is already on screen, so fading it would read as
                          // it disappearing and coming back rather than growing.
                          fadeInOnFirstBuild:
                              widget.recentlySaved?.taskId == task.id &&
                              widget.recentlySaved?.change ==
                                  SavedTaskChange.created,
                          growFromMinutes:
                              widget.recentlySaved?.taskId == task.id &&
                                  widget.recentlySaved?.change ==
                                      SavedTaskChange.durationChanged
                              ? widget.recentlySaved?.previousDurationMinutes
                              : null,
                          onTap: () => widget.onTaskTap(task),
                          onToggleComplete: () => widget.onToggleComplete(task),
                          onReschedule: (newScheduledAt) =>
                              widget.onReschedule(task, newScheduledAt),
                          onDraggingChanged: (isDragging) {
                            setState(() {
                              _draggingTaskId = isDragging ? task.id : null;
                              // Ordering starts with the drag and is only released
                              // by onSettled below, deliberately outliving the
                              // ghost.
                              if (isDragging) _settlingTaskId = task.id;
                            });
                          },
                          onSettled: () {
                            // Ignore a stale settle: either a different task now
                            // holds the pin, or this same task has been picked up
                            // again before its previous drop finished animating.
                            if (_settlingTaskId != task.id) return;
                            if (_draggingTaskId != null) return;
                            setState(() => _settlingTaskId = null);
                          },
                          editModeEnabled: widget.editModeEnabled,
                          onDeleteTask: widget.onDeleteTask,
                          deleteTargetKey: widget.editModeEnabled
                              ? _deleteTargetKey
                              : null,
                          onDeleteTargetVisibilityChanged: (visible) =>
                              setState(
                                () => _deleteTargetVisibleCount += visible
                                    ? 1
                                    : -1,
                              ),
                          onDeleteTargetArmedChanged: (armed) =>
                              setState(() => _deleteTargetArmed = armed),
                        )
                      else if (slot.block
                          case final ExternalCalendarEvent event)
                        // ExternalEventCapsuleBlock builds its own outer
                        // `Positioned` (see its own doc comment on why —
                        // matching `_DraggableTaskBlock._buildSplit`'s
                        // structure exactly), so this is used directly, not
                        // wrapped in a second one.
                        ExternalEventCapsuleBlock(
                          key: ValueKey(event.id),
                          theme: theme,
                          event: event,
                          rangeStart: rangeStart,
                          pixelsPerMinute: pixelsPerMinute,
                          // Fixed at the day column's own origin, same as
                          // `_DraggableTaskBlock.left` — NOT lane-shifted,
                          // so the text column (relative to this same
                          // origin) never moves when the event lands in a
                          // deeper lane. The lane offset lives entirely in
                          // `columnOffset` below, applied only to the
                          // rail.
                          left: hourGutterWidth,
                          // The rail's own lane x — `pillBoxLeftForColumn`,
                          // the SAME formula a task's own rail uses, so an
                          // event sharing a lane group with tasks lines up
                          // exactly like one of them would. Ignored when
                          // `collapsedTop` is set (List mode has no lane
                          // concept horizontally either — see that
                          // widget's own contract), same as a task's own
                          // rail is.
                          columnOffset: pillBoxLeftForColumn(
                            column: slot.column,
                            pillWidth: _pillWidth(theme),
                            columnGap: _columnGap(theme),
                          ),
                          textColumnLeft: _textColumnLeft(theme, ghostSlots),
                          textColumnRight: textColumnRightInset,
                          collapsedTop: widget.showHourLabels
                              ? null
                              : blockTops[event.id],
                          collapsedHeight: widget.showHourLabels
                              ? null
                              : _collapsedExternalEventHeight(event, theme),
                          compactText: !widget.showHourLabels,
                          durationVisible: widget.devDurationVisible,
                          onTap: () => showExternalCalendarEventInfo(
                            context: context,
                            theme: theme,
                            event: event,
                          ),
                        ),
                    ],
                    // The wiggly placeholder pill dropped by tapping empty
                    // Timeline space — requested directly. Task view only
                    // (this whole `_DayTimeline` widget is only ever
                    // mounted in the Task-view branch of TimelineScreen's
                    // own view-switch ternary). Now part of `slots`/the
                    // lane/cluster system above — it shares lanes and
                    // joins clusters exactly as a real task does, so the
                    // slot it was assigned supplies its column, and only
                    // its `top` still comes from its own live drag state.
                    if (widget.showHourLabels &&
                        widget.pendingDraft != null &&
                        draftSlot != null)
                      _DraggablePendingTaskPill(
                        key: ValueKey('pending-${widget.pendingDraft!.id}'),
                        theme: theme,
                        draft: widget.pendingDraft!,
                        rangeStart: rangeStart,
                        pixelsPerMinute: pixelsPerMinute,
                        left: hourGutterWidth,
                        width: _pillWidth(theme),
                        slot: draftSlot,
                        // Same shared text column every real task's name
                        // sits in — requested directly ("the task name
                        // should also be aligned as other text").
                        textColumnLeft: _textColumnLeft(theme, ghostSlots),
                        textColumnRight: textColumnRightInset,
                      ),
                    // The cluster's own flat title+time list — the member pills
                    // themselves now render through the ordinary slot loop above
                    // (each carrying its fixed cluster lane, see _withClusterLanes)
                    // rather than a separate non-interactive layer, since a
                    // clustered task must stay draggable (requested directly).
                    // This list is top-anchored at the cluster's start and
                    // positioned beside the fixed lane group — `cluster.tasks
                    // .length` IS the lane count now (one lane per task, always),
                    // so no separate layout call is needed to find where the pills
                    // end. Row order (earliest first) matches lane order
                    // (leftmost = earliest) exactly, per direct instruction — this
                    // is a real positional guarantee now, not just an incidental
                    // one, since _withClusterLanes assigns both from the same
                    // chronological index.
                    //
                    // AnimatedSwitcher gives the crossfade the work order asked
                    // for: each cluster's Positioned is keyed by its member ids,
                    // so a drop that changes cluster MEMBERSHIP (not just
                    // position) is a genuinely different widget to Flutter, and
                    // AnimatedSwitcher fades between old and new automatically. A
                    // cluster DISSOLVING back to individual capsules is the same
                    // mechanism from the other side: clusteredIds stops containing
                    // those tasks, so their pills (above) regain full content
                    // while this switcher fades its old list out.
                    //
                    // Rendered from `restingClusters` (NOT the drag-excluded
                    // `clusters`), so the list keeps showing every member —
                    // structure held — for the whole duration of a drag, with
                    // only the actively-dragged member's own row fading (via
                    // `fadedTaskId` on OverlapClusterBlock, same "still there,
                    // just lifted" treatment TaskCapsuleBlock already gives a
                    // dragged task's own name/time/checkbox). Requested directly:
                    // the list used to crossfade to a shorter version the INSTANT
                    // a drag started (since `clusters` already excludes the
                    // dragged task), which read as the row vanishing rather than
                    // the task being lifted. The crossfade to a genuinely
                    // different list (drop creates/dissolves a cluster) still
                    // happens — the key is derived from `clusters` (the settled,
                    // post-drop membership), which only changes once the drag
                    // actually commits.
                    // LIST MODE ONLY. Task view now gives every task its own
                    // label, aligned to its own pill's icon and pushed down
                    // only on collision (see `labelTops` / computeLabelTops) —
                    // requested directly: "position the task name so it's
                    // always lined up with the icon ... only if two tasks are
                    // starting at the same time or too close would they
                    // stack." This block's Column packs a cluster's names
                    // sequentially from the cluster's own top instead, which
                    // severs that alignment. List mode has no time axis to
                    // align to, so it keeps this treatment.
                    if (!widget.showHourLabels)
                      for (final cluster in restingClusters)
                        Positioned(
                          key: ValueKey(
                            'cluster-list-${cluster.tasks.map((task) => task.id).join('-')}',
                          ),
                          // `blocks.first`, NOT `tasks.first`. `tasks` is a
                          // filtered view of `blocks` (events dropped), so
                          // whenever a cluster's EARLIEST member is an
                          // imported calendar event, `tasks.first` is some
                          // later task — and `blockTops` is keyed by the
                          // row's own first member. The cluster then
                          // rendered at a different row's top and painted
                          // over it. Reported directly from a screenshot:
                          // an 08:30 imported event's row sitting between
                          // 15:20 and 19:30, overlapping its neighbour.
                          top: blockTops[cluster.blocks.first.id]!,
                          // The SHARED text column, not this cluster's own member
                          // count — corrected directly ("all text ... always lined
                          // up"). Sizing it per cluster meant a 4-task cluster's
                          // rows started further right than a 2-task one's, and
                          // than every unclustered task's name.
                          left:
                              hourGutterWidth +
                              _textColumnLeft(theme, ghostSlots),
                          // Matches the ordinary task rows' own checkbox-
                          // column edge, including its narrower inset — see
                          // `textColumnRightInset`'s own comment above.
                          right: textColumnRightInset,
                          child: AnimatedSwitcher(
                            duration: theme.motionNormal,
                            child: OverlapClusterBlock(
                              // Keyed off `restingClusters`' own membership — which
                              // stays fixed for the whole duration of a drag (it's
                              // computed WITHOUT excluding the dragged task) and
                              // only changes once the drop actually commits a new
                              // schedule and `restingClusters` is recomputed from
                              // the updated task list. So this key does NOT change
                              // mid-drag, and the crossfade only fires on a genuine
                              // membership change, not a drag in progress.
                              key: ValueKey(
                                cluster.tasks.map((task) => task.id).join('-'),
                              ),
                              cluster: cluster,
                              onTaskTap: widget.onTaskTap,
                              onToggleComplete: widget.onToggleComplete,
                              fadedTaskId: _draggingTaskId,
                              compactText: !widget.showHourLabels,
                              durationVisible: widget.devDurationVisible,
                              // This whole render block is List-mode-only (see
                              // the outer `if (!widget.showHourLabels)` above)
                              // — always true here, matching the non-clustered
                              // row's own `alwaysShowTime: widget.compactText`.
                              alwaysShowTime: true,
                              timeRangeVisible: widget.devTimeRangeVisible,
                              textLayout: widget.devTextLayout,
                              showCompletionCheckbox:
                                  widget.showCompletionCheckbox,
                            ),
                          ),
                        ),
                    // Timeline mode only: the now-line's position is meaningless
                    // without a time axis to place it against — in collapsed mode
                    // it would sit at an arbitrary point between two stacked
                    // blocks and imply a scale that isn't there.
                    if (widget.showHourLabels)
                      CurrentTimeIndicator(
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        pixelsPerMinute: widget.pixelsPerMinute,
                        gutterWidth: hourGutterWidth,
                        leftInset: theme.spacingScreenPadding,
                        rightInset: rightEdgeInset,
                      ),
                    // LAST, deliberately — the placement line has to paint above
                    // every task (reported directly: it was rendering underneath
                    // them). Its press surface stays first in this list; see
                    // PlaceTaskLineLayer's doc comment for why they're split.
                    if (widget.showHourLabels)
                      PlaceTaskLineOverlay(
                        theme: theme,
                        rangeStart: rangeStart,
                        pixelsPerMinute: widget.pixelsPerMinute,
                        controller: _placeLineController,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: EditModeDeleteTarget(
                theme: theme,
                visible:
                    widget.editModeEnabled && _deleteTargetVisibleCount > 0,
                isArmed: _deleteTargetArmed,
                targetKey: _deleteTargetKey,
              ),
            ),
            // The small quick-create panel — a sibling of the scrollable
            // day (not a child of it, same reasoning as
            // EditModeDeleteTarget above: it must stay pinned to the
            // VIEWPORT'S own bottom edge, fixed regardless of scroll
            // position, not scroll away with the day's content). See
            // QuickCreateOverlay's own doc comment for why this can't be
            // a pushed Navigator route.
            if (widget.showHourLabels && widget.pendingDraft != null)
              QuickCreateOverlay(
                key: ValueKey('quick-create-${widget.pendingDraft!.id}'),
                draft: widget.pendingDraft!,
              ),
            // Top scroll-fade — requested directly: "give gradient of
            // the color of bg to create that effect of content smoothly
            // fading... so there is not a hard line when content scrolls
            // underneath." A sibling of the scroll view (same reasoning
            // as EditModeDeleteTarget/QuickCreateOverlay above), so it
            // stays fixed at the viewport's own top edge rather than
            // scrolling away with the content it's meant to fade against.
            // Extracted into AppTopScrollFade (2026-09-08) once the same
            // fade turned out to be needed on Inbox/Tracked/every sheet
            // header too — see that widget's own doc comment.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppTopScrollFade(color: theme.colorSurfaceTimeline),
            ),
            // Mirrored bottom fade — requested directly: "use same at
            // the bottom." Same reasoning as the top one: content
            // scrolling out at the viewport's bottom edge disappears
            // smoothly instead of hitting a hard line.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AppTopScrollFade(
                color: theme.colorSurfaceTimeline,
                fromBottom: true,
              ),
            ),
          ],
        );
      },
    );
  }

  double _minutesSinceStart(DateTime rangeStart, DateTime scheduledAt) =>
      scheduledAt.difference(rangeStart).inMinutes.toDouble();

  /// Every task's vertical offset, keyed by task id — computed once here
  /// so every place a `top` is needed reads the same values rather than
  /// re-deriving them.
  ///
  /// Timeline mode maps real elapsed time to pixels. An event's OWN top in
  /// this mode is computed independently, inside `ExternalEventCapsuleBlock`
  /// itself from that same real-time math (`collapsedTop: null` at the
  /// render site) — so this map only ever needs task ids here; an event
  /// slot is simply skipped. Collapsed (List) mode instead delegates
  /// entirely to [_collapsedTops]' unified stacking cursor, which already
  /// covers both kinds of block in one pass — see its own doc comment.
  Map<String, double> _blockTops(
    List<TaskLayoutSlot> slots,
    DateTime rangeStart,
    AmbleTheme theme,
  ) {
    if (widget.showHourLabels) {
      return {
        for (final slot in slots)
          if (slot.task case final task?)
            task.id:
                _minutesSinceStart(rangeStart, task.scheduledAt!) *
                    widget.pixelsPerMinute +
                _zoneTaskTopInset(task),
      };
    }
    // Unreachable in practice — this whole method is only ever called from
    // inside an outer `if (widget.showHourLabels)` at its one call site, so
    // this branch can never actually run. `clusters` isn't in scope here;
    // an empty list keeps this compiling without expanding this fix's
    // scope to a pre-existing dead branch.
    return _collapsedTops(slots, const [], theme);
  }

  /// How far to nudge [task] down so it isn't flush against the top edge of
  /// a zone band that starts at the exact same time.
  ///
  /// Requested directly: "task that start same as zone should just have
  /// small gap same as from side of the zone, atm too big gap." That gap
  /// used to come from the BAND starting 12px above its own start time,
  /// which is what made a zone read as beginning (and ending) well off its
  /// real hours. Confirmed directly to fix it the other way round: the
  /// band's edges are now exact, and the task moves instead.
  ///
  /// Zero for every task that doesn't start exactly on some zone's start —
  /// a task in the middle of a zone already has room above it, and one
  /// outside every zone has no band to clear.
  double _zoneTaskTopInset(Task task) {
    final scheduledAt = task.scheduledAt;
    if (scheduledAt == null) return 0;
    final startMinutes = scheduledAt.hour * 60 + scheduledAt.minute;
    final startsAZone = widget.zones.any(
      (zone) => zone.startMinutes == startMinutes,
    );
    // The same inset the band already uses on its left edge, so the gap
    // above the task reads as the same size as the gap beside it — which
    // is exactly what "same as from side of the zone" asks for.
    return startsAZone ? zoneBackgroundOffset : 0;
  }

  /// The bottom-edge counterpart to [_zoneTaskTopInset] — how much shorter
  /// [task]'s own pill renders when its END lands exactly on some zone's
  /// end, so it isn't flush against that zone's own bottom edge.
  ///
  /// Requested directly, from a screenshot showing a task's pill flush
  /// against its zone's bottom with no visible margin: "the task that's
  /// matching the timing duration of a zone needs to have a bottom padding
  /// of a zone from the zone, same as the top padding (same principle)."
  ///
  /// NOT just `zoneBackgroundOffset` — the band's own rendered bottom edge
  /// already sits `zoneBackgroundGap` above the zone's real end time (see
  /// that constant's own doc comment, the inter-zone spacing), unlike its
  /// top edge, which lands exactly on the true start. Trimming the task by
  /// `zoneBackgroundOffset` alone landed its bottom exactly on the band's
  /// already-raised edge — the two moved together and visually still
  /// touched, reported directly from a screenshot as "no padding" despite
  /// the trim genuinely being applied. The two gaps have to stack so the
  /// visible space below the task matches the visible space above it.
  ///
  /// Same "only exactly on the boundary" condition as the top inset — a
  /// task ending mid-zone already has room below it, and one outside every
  /// zone has no band to clear.
  double _zoneTaskBottomTrim(Task task) {
    final scheduledAt = task.scheduledAt;
    final durationMinutes = task.durationMinutes;
    if (scheduledAt == null || durationMinutes == null) return 0;
    final endMinutes =
        scheduledAt.hour * 60 + scheduledAt.minute + durationMinutes;
    final endsAZone = widget.zones.any((zone) => zone.endMinutes == endMinutes);
    return endsAZone ? zoneBackgroundOffset + zoneBackgroundGap : 0;
  }

  /// Caps [task]'s pill height so it never runs into the top of the next
  /// task sharing its own overlap COLUMN, when the two are close enough in
  /// time that `badgeSize`'s floor (applied to both) would otherwise make
  /// their floored pills touch or overlap despite not actually overlapping
  /// in time.
  ///
  /// Requested directly, from a screenshot of two short, closely-spaced
  /// tasks (5- and 15-minute examples given) whose pills visibly touched:
  /// "the smaller one gets below the minimum size in order to always
  /// create some small 2-pixel gap between tasks that don't effectively
  /// overlap but are too close to show."
  ///
  /// Deliberately scoped to same-COLUMN neighbours only — two tasks in
  /// different columns of the same overlap group sit side by side
  /// horizontally, so their pills can't visually collide vertically no
  /// matter how their floored heights compare. Only Timeline mode's real
  /// elapsed-time tops need this: [_blockTops] already notes that real
  /// time-to-pixel positions can't collide by construction, but that
  /// covers TOPS only — a floored HEIGHT can still push one pill's bottom
  /// past the next same-column task's top. Collapsed (List) mode can't
  /// exhibit this: its own [_collapsedTops] already derives every row's
  /// top from a shared cursor that advances by the PREVIOUS row's real
  /// (already-floored) height plus a gap, so two rows can never collide by
  /// construction — this cap only ever matters, and is only ever passed,
  /// in Timeline mode.
  ///
  /// Returns null (no cap) when there's no same-column task after this one
  /// close enough to matter, or when [task] isn't in [slots] at all (the
  /// ghost/ ancestor-less cases some call sites pass through).
  // `slot.block.id` throughout (not `slot.task.id`) — the "next occupant"
  // in [task]'s own column can now be an ExternalCalendarEvent slot, and
  // finding/comparing by id works identically for either.
  double? _maxPillHeight(
    Task task,
    List<TaskLayoutSlot> slots,
    Map<String, double> blockTops,
  ) {
    TaskLayoutSlot? ownSlot;
    for (final slot in slots) {
      if (slot.block.id == task.id) {
        ownSlot = slot;
        break;
      }
    }
    final ownTop = blockTops[task.id];
    if (ownSlot == null || ownTop == null) return null;

    TaskLayoutSlot? next;
    double? nextTop;
    for (final slot in slots) {
      if (slot.column != ownSlot.column || slot.block.id == task.id) continue;
      final top = blockTops[slot.block.id];
      if (top == null || top <= ownTop) continue;
      if (nextTop == null || top < nextTop) {
        next = slot;
        nextTop = top;
      }
    }
    if (next == null || nextTop == null) return null;

    return nextTop - ownTop - _minPillGap;
  }

  /// Collapsed (List) mode's ONE unified stacking pass over every block —
  /// task or external-calendar-event — walked with a single shared cursor.
  /// Real bug, reported directly: "tasks on list view should not overlap
  /// (the app tasks with the imported tasks should be one by one." A prior
  /// version computed task tops FIRST, entirely unaware external events
  /// existed, then positioned external events in a second pass that only
  /// read those already-fixed task tops — so an external event landing
  /// chronologically BETWEEN two tasks could never push the later task's
  /// row down to make room; it just overlapped it. Merging both sequences
  /// into one cursor walk (ordered by each row's own start time) is what
  /// actually guarantees "one by one": whichever row comes next in time is
  /// the one that advances the cursor, task or external, every time.
  ///
  /// **2026-09-07**: [slots] now already contains BOTH tasks and events as
  /// one merged list (see this build method's own `blocks`), so this no
  /// longer needs a separate pass over `widget.externalEvents` at all — one
  /// slot walk covers every block, keyed generically by `slot.block.id`
  /// rather than the narrower `slot.task.id`. Returns one map (was two,
  /// `taskTops`/`externalEventTops`, an artificial split that no longer
  /// matched reality once a block's KIND stopped determining how it's
  /// positioned) — every caller reads it the same way regardless of what
  /// kind of block an id belongs to.
  Map<String, double> _collapsedTops(
    List<TaskLayoutSlot> slots,
    List<OverlapCluster> clusters,
    AmbleTheme theme,
  ) {
    // A cluster's own row renders via OverlapClusterBlock — a vertically
    // stacked flat list of every member's own title+time line, not the
    // ordinary combined pill+text row — so its real height is nothing
    // like a single task's badge-floored pill height. Keyed by cluster
    // SIZE (member count), not identity: every member of the same cluster
    // needs the same height value once looked up by id below. Reads
    // [OverlapCluster.blocks] (not the narrower `.tasks`) so an event
    // pulled into a cluster gets the cluster's own height too.
    final clusterSizeById = {
      for (final cluster in clusters)
        for (final block in cluster.blocks) block.id: cluster.blocks.length,
    };

    // One row per overlap GROUP, carrying the group's start time and the
    // tallest member's height. The actual merge (this function's whole
    // point) lives in the pure, unit-tested computeCollapsedStackTops.
    //
    // Grouped by `slot.groupIndex`, NOT by `slot.column == 0`. Real bug,
    // reported directly from a screenshot ("on list view we have some
    // important tasks overlap they seem duplicated... whatever the
    // scenario should never overlap"): a group packs its blocks into the
    // fewest columns it can, so column 0 gets REUSED by any later block
    // that starts after column 0's previous occupant ends (09:00-10:00,
    // 09:30-10:30, 10:00-11:00 → columns 0, 1, 0). Treating column 0 as
    // "starts a new row" therefore split a single group into two rows
    // whose members interleave in time, and the two painted on top of
    // each other.
    final rows = <CollapsedStackRow>[];
    int? currentGroupIndex;
    for (final slot in slots) {
      final task = slot.task;
      final height = clusterSizeById[slot.block.id] != null
          ? _collapsedClusterHeight(clusterSizeById[slot.block.id]!, theme)
          : task != null
          ? _collapsedBlockHeight(task, theme)
          : _collapsedExternalEventHeight(
              slot.block as ExternalCalendarEvent,
              theme,
            );
      if (slot.groupIndex != currentGroupIndex || rows.isEmpty) {
        currentGroupIndex = slot.groupIndex;
        rows.add(
          CollapsedStackRow(
            ids: [slot.block.id],
            start: slot.block.scheduledStart,
            height: height,
          ),
        );
      } else {
        final last = rows.removeLast();
        rows.add(
          CollapsedStackRow(
            ids: [...last.ids, slot.block.id],
            start: last.start,
            height: math.max(last.height, height),
          ),
        );
      }
    }

    return computeCollapsedStackTops(
      taskRows: rows,
      externalEventRows: const [],
      gap: _collapsedBlockGap(theme),
    );
  }

  /// A cluster's real rendered height in collapsed mode — see
  /// [collapsedClusterHeight]'s own doc comment for why the stacking
  /// cursor needs this instead of a single member pill's own height.
  /// [_labelHeight] is one line of `OverlapClusterBlock`'s own flat list
  /// (List mode always forces its inline row layout), `spacingXs` is that
  /// widget's own inter-row gap, `spacingSm` its own vertical padding.
  double _collapsedClusterHeight(int memberCount, AmbleTheme theme) =>
      collapsedClusterHeight(
        memberCount: memberCount,
        lineHeight: _labelHeight(theme),
        lineGap: theme.spacingXs,
        verticalPadding: theme.spacingSm,
      );

  /// List (collapsed) mode's own zone bands — see [collapsedZoneBands]'s
  /// own doc comment for why these can't be derived from
  /// `ZoneBackgroundBlock`'s real time-to-pixel math the way Task view's
  /// are. Reuses [resolveZoneContainment] (already shared with the
  /// separate Zone View) for "which tasks/events belong to which zone" —
  /// this is the one place in `timeline_screen.dart` that calls it.
  ///
  /// [blockTops] is [_collapsedTops]' single unified map (task AND event
  /// ids together, as of 2026-09-07) — passed once and read by both id
  /// spaces below, since `taskTops[task.id]`/`externalEventTops[event.id]`
  /// now genuinely come from the same source map.
  List<CollapsedZoneBand> _collapsedZoneBands(
    List<Task> tasks,
    List<ExternalCalendarEvent> externalEvents,
    Map<String, double> blockTops,
    AmbleTheme theme,
  ) {
    if (widget.zones.isEmpty) return const [];

    // NOT `widget.externalEvents` — containment must be resolved from the
    // SAME (possibly List-view-filtered) lists `blockTops` was built from,
    // or a zone containing only a filtered-out member would look non-empty
    // to `resolveZoneContainment` while having no top/height entry at all.
    // `collapsedZoneBands`'s own `_rawMemberBand` falls back to the
    // placeholder band for that case regardless, but resolving containment
    // from the filtered lists in the first place is what keeps a filtered
    // member from being counted as "in the zone" here at all, matching
    // what's actually on screen.
    final result = resolveZoneContainment(
      tasks: tasks,
      zones: widget.zones,
      day: widget.selectedDate,
      externalEvents: externalEvents,
    );

    return collapsedZoneBands(
      containments: result.containments,
      day: widget.selectedDate,
      taskTops: blockTops,
      taskHeights: {
        for (final task in tasks) task.id: _collapsedBlockHeight(task, theme),
      },
      externalEventTops: blockTops,
      externalEventHeights: {
        for (final event in externalEvents)
          event.id: _collapsedExternalEventHeight(event, theme),
      },
      rowTopsByStartTime: [
        for (final task in tasks)
          if (blockTops[task.id] != null)
            MapEntry(task.scheduledAt!, blockTops[task.id]!),
        for (final event in externalEvents)
          if (blockTops[event.id] != null)
            MapEntry(event.start, blockTops[event.id]!),
      ],
      rowExtents: [
        for (final task in tasks)
          if (blockTops[task.id] != null)
            (
              blockTops[task.id]!,
              blockTops[task.id]! + _collapsedBlockHeight(task, theme),
            ),
        for (final event in externalEvents)
          if (blockTops[event.id] != null)
            (
              blockTops[event.id]!,
              blockTops[event.id]! +
                  _collapsedExternalEventHeight(event, theme),
            ),
      ],
      // NOT zoneBackgroundOffset — that constant is tied to Task view's
      // own "task starting late" perception issue on a real time axis
      // (see its own doc comment) and doesn't carry the same meaning
      // here, where a band's padding is measured against other rows'
      // already-collapsed positions, not real minutes. List mode's own
      // value, requested directly ("add space also before and after"
      // around a zone's own band).
      padding: theme.spacingSm,
      placeholderHeight: theme.sizeTaskBadge,
    );
  }

  /// A block's rendered height in collapsed mode — the same
  /// duration-proportional value [TaskCapsuleBlock] computes internally,
  /// mirrored here so the stacking cursor knows how far to advance.
  double _collapsedBlockHeight(Task task, AmbleTheme theme) => math.max(
    task.durationMinutes! * _collapsedPixelsPerMinute(theme),
    _pillWidth(theme),
  );

  /// How wide [zone]'s background block should be: just the pill column,
  /// widened by one pill per extra overlap lane in use inside the zone's
  /// own time window.
  ///
  /// Requested directly ("zone width is dynamic depending whether there is
  /// stacking"), and confirmed as hugging the PILLS ONLY — the time and
  /// task-name columns deliberately sit outside the zone background.
  ///
  /// Reads the SAME [TaskLayoutSlot]s the capsules are positioned from,
  /// rather than re-deriving overlap here, so the background can never
  /// disagree with the pills it is drawn behind. A zone with no tasks
  /// still gets one pill's width, so an empty zone stays a visible band
  /// (the confirmed spec renders every zone regardless of membership).
  /// The zone band's width: the day's pill column, plus one extra pill
  /// width — requested directly ("zone larger by the width of task pill"),
  /// so the band reads as a container around the pills rather than a strip
  /// cut exactly to them.
  /// Every zone's band width, sized so the visible space to the RIGHT of
  /// its own pills equals the space to their LEFT — requested directly:
  /// "gap from right (zone to right task) should be same as left gap
  /// (padding)", then clarified as "I mean perceived padding right".
  ///
  /// The arithmetic: `ZoneBackgroundBlock` starts the band
  /// `zoneBackgroundOffset` left of the pill column and trims
  /// `zoneBackgroundGap` off this width, so landing the same inset on the
  /// right means carrying BOTH insets plus that trim (see
  /// [zoneBackgroundWidthForPills]). An earlier formula added a bare
  /// `_pillWidth`, leaving 8px against 12px.
  ///
  /// The lane count is [dayPillLanes] — the whole DAY's deepest stack
  /// (whichever zone or ungrouped run of tasks it comes from), the same
  /// value the shared text column already uses ([_textColumnLeft]) — so
  /// every zone band on screen is exactly the same width, and clears
  /// whichever overlap happens to be the widest anywhere in view.
  /// Requested directly ("all zones widen to the same size" whenever any
  /// overlap exists anywhere in the visible day), reversing an earlier,
  /// now-superseded per-zone-lanes decision ([zonePillLanes] is unused by
  /// this call site as of this change, kept only for its own tests/other
  /// callers if any).
  double _zoneBackgroundWidth(List<TaskLayoutSlot> slots, AmbleTheme theme) {
    return zoneBackgroundWidthForPills(
      pillsSpan: zoneBackgroundPillWidth(
        lanes: dayPillLanes(slots),
        pillWidth: _pillWidth(theme),
        columnGap: _columnGap(theme),
      ),
      horizontalInset: zoneBackgroundOffset,
      trailingTrim: zoneBackgroundGap,
    );
  }

  /// One task-name label's rendered height, used by [computeLabelTops] to
  /// decide when two labels would collide.
  ///
  /// `TaskCapsuleTextRow` is a single line of `textTaskTitle`, so this is
  /// that line's own height — the two must agree, or the collision sweep
  /// reserves more or less space than the label actually occupies.
  double _labelHeight(AmbleTheme theme) =>
      theme.textTaskTitle.fontSize! * theme.textTaskTitle.height!;

  /// [ExternalCalendarEvent] counterpart to [_collapsedBlockHeight] — now
  /// byte-for-byte the same duration-proportional floor, since
  /// `ExternalEventCapsuleBlock` renders as a real capsule pill (single-
  /// line text, same geometry as a task's own pill) rather than the old
  /// two-stacked-text-lines background block — the previous
  /// `externalEventBlockMinHeight` text-height floor no longer applies
  /// (**2026-09-06**, alongside the pill-format reversal). Both callers of
  /// this value — the cursor's own advance here, and
  /// `ExternalEventCapsuleBlock.collapsedHeight` passed to the widget —
  /// must agree, or the cursor reserves less space than the widget
  /// renders.
  double _collapsedExternalEventHeight(
    ExternalCalendarEvent event,
    AmbleTheme theme,
  ) => math.max(
    event.end.difference(event.start).inMinutes *
        _collapsedPixelsPerMinute(theme),
    _pillWidth(theme),
  );

  /// [slots] with the dragged task moved to the end, so it's the last
  /// child in the Stack and therefore paints above every other block.
  /// Returns the list unchanged when nothing is being dragged or settling,
  /// so the resting timeline keeps its natural layout order.
  ///
  /// Keyed off [_settlingTaskId] rather than [_draggingTaskId] so the
  /// order survives until the drop animation completes — see that field's
  /// own comment for the jump this prevents.
  /// Overrides [slots]' column assignment for every clustered task with a
  /// fixed, one-lane-per-task layout: lane index equals chronological
  /// position within the cluster (earliest = column 0 = leftmost), and
  /// `columnCount` is always the cluster's own task count. Requested
  /// directly ("leftmost pill to topmost task") — `layoutOverlappingTasks`'
  /// own packed-column algorithm reuses a column once its previous
  /// occupant has finished, which does NOT guarantee a stable per-task lane
  /// (e.g. two tasks that don't directly overlap each other, both inside a
  /// 3-task cluster, could otherwise share a column) — the cluster's flat
  /// list needs that guarantee to keep its row order matching pill
  /// position. Non-clustered tasks are returned unchanged.
  /// The slot a task held in [ghostSlots] — used only for the drag ghost,
  /// which needs its ORIGINAL (pre-drag) lane, not the current one
  /// (`slots`), since the two schemes disagree the instant a drag starts
  /// excluding this task from cluster detection. Falls back to a single,
  /// full-width slot if the task isn't found (shouldn't happen — the
  /// ghost only ever renders for a task that was on today's list a moment
  /// ago — but this keeps the lookup total rather than partial).
  TaskLayoutSlot _ghostSlotFor(List<TaskLayoutSlot> ghostSlots, String taskId) {
    return ghostSlots.firstWhere(
      (slot) => slot.block.id == taskId,
      orElse: () => ghostSlots.first,
    );
  }

  /// Reads [cluster]'s member ids/count from [OverlapCluster.blocks], NOT
  /// the narrower [OverlapCluster.tasks] getter — **2026-09-07** (see this
  /// file's own doc comment on event/task parity): an
  /// [ExternalCalendarEvent] pulled into a cluster needs the exact same
  /// fixed, one-lane-per-member treatment a task does, or it would keep
  /// whatever column `layoutOverlappingTasks`' packed-column algorithm
  /// happened to assign it — breaking the "leftmost pill/row = topmost
  /// row" guarantee this function exists for.
  List<TaskLayoutSlot> _withClusterLanes(
    List<TaskLayoutSlot> slots,
    List<OverlapCluster> clusters,
  ) {
    if (clusters.isEmpty) return slots;

    final laneById = <String, int>{};
    final countById = <String, int>{};
    for (final cluster in clusters) {
      for (final (index, block) in cluster.blocks.indexed) {
        laneById[block.id] = index;
        countById[block.id] = cluster.blocks.length;
      }
    }

    return [
      for (final slot in slots)
        if (laneById.containsKey(slot.block.id))
          TaskLayoutSlot(
            block: slot.block,
            column: laneById[slot.block.id]!,
            columnCount: countById[slot.block.id]!,
            // Carried through unchanged: this only re-lanes a slot within
            // its cluster, it never moves it to a different overlap group.
            groupIndex: slot.groupIndex,
          )
        else
          slot,
    ];
  }

  List<TaskLayoutSlot> _dragLastOrder(List<TaskLayoutSlot> slots) {
    final draggingId = _settlingTaskId;
    if (draggingId == null) return slots;

    final index = slots.indexWhere((slot) => slot.block.id == draggingId);
    if (index == -1) return slots;

    // Copy first — `slots` is the caller's list and must not be mutated.
    final reordered = [...slots];
    reordered.add(reordered.removeAt(index));
    return reordered;
  }
}

/// Wraps a [ZoneBackgroundBlock] with vertical drag-to-move and top/bottom
/// drag-to-resize, on the Spatial Task View — mirrors [_DraggableTaskBlock]'s
/// own shape (tracks live drag deltas for visual feedback; commits only on
/// release) and, on the Zone view side, `_ZoneDayTimelineState`'s own
/// `_commitZoneResize`/`_commitZoneMove`. **New 2026-09-06** (confirmed
/// directly — "we should be able to edit zones in any view ... in spatial
/// task view also"), reversing the earlier "Task view zones are purely
/// decorative" scope: both gestures resolve to the SAME shared cascade
/// commit path (`_commitZoneCascade`) Zone view's own container already
/// uses, via [widget.onZoneResize]/[widget.onZoneMove] — this widget itself
/// computes nothing about overlap or capacity, only the candidate window.
///
/// A [ConsumerStatefulWidget] living inside `_DayTimelineState` (a plain,
/// non-Riverpod-aware `StatefulWidget`) for the exact same reason
/// [_DraggableTaskBlock] already is: reading `ref` here, locally, is
/// simpler than threading a second layer of plain callbacks through
/// `_DayTimeline` for state this widget alone needs to own frame-to-frame
/// (the live delta) — [onZoneResize]/[onZoneMove] themselves ARE the plain
/// callback contract already used everywhere else in this widget tree.
class _DraggableZoneBlock extends ConsumerStatefulWidget {
  const _DraggableZoneBlock({
    super.key,
    required this.theme,
    required this.zone,
    required this.day,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.left,
    required this.width,
    required this.editModeEnabled,
    required this.phaseOffset,
    this.onZoneResize,
    this.onZoneMove,
    this.deleteTargetKey,
    this.onDeleteTargetVisibilityChanged,
    this.onDeleteTargetArmedChanged,
    this.onDeleteZone,
  });

  final AmbleTheme theme;
  final Zone zone;
  final DateTime day;
  final DateTime rangeStart;
  final double pixelsPerMinute;
  final double left;
  final double width;
  final bool editModeEnabled;
  final double phaseOffset;

  /// See [_DayTimeline.onZoneResize]/[_DayTimeline.onZoneMove] — passed
  /// straight through from there.
  final void Function(
    String zoneId,
    int originalStartMinutes,
    int newStartMinutes,
    int newEndMinutes,
  )?
  onZoneResize;
  final void Function(
    String zoneId,
    int originalStartMinutes,
    int newStartMinutes,
    int newEndMinutes,
  )?
  onZoneMove;

  /// The SAME shared delete-target `GlobalKey`/callbacks
  /// `_DraggableTaskBlock` already uses — reported directly: "zones cant
  /// see remove... when in edt move dragging zone should remove zone
  /// appear like with tasks." One delete target on screen at a time
  /// regardless of whether a task or a zone is the thing being dragged
  /// onto it, so this reuses `_DayTimelineState`'s existing
  /// `_deleteTargetKey`/`_deleteTargetVisibleCount`/`_deleteTargetArmed`
  /// rather than a second, zone-only target widget. See
  /// [_DraggableTaskBlock.deleteTargetKey]'s own doc comment for the full
  /// contract — identical here.
  final GlobalKey? deleteTargetKey;
  final ValueChanged<bool>? onDeleteTargetVisibilityChanged;
  final ValueChanged<bool>? onDeleteTargetArmedChanged;

  /// Deletes [zone] — fired when a move-drag drops onto the delete
  /// target. Mirrors [_DraggableTaskBlock.onDeleteTask]'s own contract:
  /// the caller (`TimelineScreen`) owns confirmation/scope handling, if
  /// any; this widget only fires the drop.
  final Future<void> Function(Zone zone)? onDeleteZone;

  @override
  ConsumerState<_DraggableZoneBlock> createState() =>
      _DraggableZoneBlockState();
}

class _DraggableZoneBlockState extends ConsumerState<_DraggableZoneBlock> {
  /// Snap granularity — matches `_ZoneDayTimelineState._zoneResizeSnapMinutes`
  /// (the Zone view's own equivalent gesture), not a new increment invented
  /// for this view.
  static const _snapMinutes = 5;

  bool _resizingTopEdge = false;
  double _resizeMinutesDelta = 0;
  bool _isResizing = false;
  double _moveMinutesDelta = 0;
  bool _isMoving = false;

  /// The move-drag's own last-known finger position — same
  /// `_lastDragGlobalPosition` pattern `_DraggableTaskBlockState` already
  /// uses, resolved against [_DraggableZoneBlock.deleteTargetKey]'s
  /// bounds at drop time.
  Offset? _lastMoveGlobalPosition;

  /// Edge-detection for the delete target's warning haptic — see
  /// `_DraggableTaskBlockState._deleteTargetWasArmed`, same reasoning:
  /// the armed state is recomputed on every move-drag frame.
  bool _deleteTargetWasArmed = false;

  void _playHaptic(AmbleHaptic haptic) =>
      ref.read(hapticsProvider).play(haptic);

  /// Mirrors `_DraggableTaskBlockState._effectiveOnTap`'s own exact
  /// reasoning: off (the default), the header has no tap of its own here
  /// (its move-drag still works via `onVerticalDrag*`, unaffected). On,
  /// tapping the header toggles this zone's selection instead of starting
  /// a move — the same "tap becomes select/deselect" rule multi-task mode
  /// already gives tasks. **New 2026-09-06** (confirmed directly — zones
  /// should not wiggle/be draggable in multi-task mode unless selected).
  VoidCallback? get _effectiveOnHeaderTap {
    if (!widget.editModeEnabled || !ref.watch(devMultiTaskEditModeProvider)) {
      return null;
    }
    return () =>
        ref.read(zoneEditSelectionProvider.notifier).toggle(widget.zone.id);
  }

  bool get _isSelected =>
      ref.watch(zoneEditSelectionProvider) == widget.zone.id;

  /// Whether wiggle/handles/the move-header actually render right now —
  /// mirrors `_DraggableTaskBlockState`'s own `wiggleEnabled` exactly:
  /// multi-task mode flips what "active" means from "Edit Mode is on" (every
  /// zone) to "this zone is selected" (only the selected one), since
  /// otherwise Edit Mode's own active-state signal would be indistinguishable
  /// from the selection signal if both used the same motion on every zone at
  /// once.
  bool get _interactionEnabled {
    if (!widget.editModeEnabled) return false;
    if (!ref.watch(devMultiTaskEditModeProvider)) return true;
    return _isSelected;
  }

  void _commitResize() {
    _playHaptic(AmbleHaptic.drop);
    final snappedDelta =
        (_resizeMinutesDelta / _snapMinutes).round() * _snapMinutes;
    setState(() {
      _isResizing = false;
      _resizeMinutesDelta = 0;
    });
    if (snappedDelta == 0 || widget.onZoneResize == null) return;

    final zone = widget.zone;
    final newStart = _resizingTopEdge
        ? zone.startMinutes + snappedDelta
        : zone.startMinutes;
    final newEnd = _resizingTopEdge
        ? zone.endMinutes
        : zone.endMinutes + snappedDelta;
    // Mirrors Zone's own constructor invariant, same guard
    // `_commitZoneResize` (Zone view) already applies before ever handing a
    // candidate window to the caller's cascade computation.
    if (newStart < 0 || newEnd > 24 * 60 || newEnd <= newStart) return;

    widget.onZoneResize!(zone.id, zone.startMinutes, newStart, newEnd);
  }

  Future<void> _commitMove() async {
    _playHaptic(AmbleHaptic.drop);
    // Drop the delete target's own visible/armed state immediately
    // regardless of outcome, same as `_DraggableTaskBlockState.onDragEnd`
    // — that's the tactile "released" feedback and shouldn't wait on I/O.
    if (widget.editModeEnabled) {
      widget.onDeleteTargetVisibilityChanged?.call(false);
      widget.onDeleteTargetArmedChanged?.call(false);
    }

    // Delete-drop short-circuit — checked FIRST, before any resize/move
    // commit below, mirroring `_DraggableTaskBlockState.onDragEnd`'s own
    // ordering exactly. Requested directly: "when in edt move dragging
    // zone should remove zone appear like with tasks."
    final dropPosition = _lastMoveGlobalPosition;
    final droppedOnTarget =
        widget.editModeEnabled &&
        widget.deleteTargetKey != null &&
        dropPosition != null &&
        isInsideDeleteTarget(widget.deleteTargetKey!, dropPosition);

    if (droppedOnTarget) {
      setState(() {
        _isMoving = false;
        _moveMinutesDelta = 0;
      });
      await widget.onDeleteZone?.call(widget.zone);
      return;
    }

    final snappedDelta =
        (_moveMinutesDelta / _snapMinutes).round() * _snapMinutes;
    setState(() {
      _isMoving = false;
      _moveMinutesDelta = 0;
    });
    if (snappedDelta == 0 || widget.onZoneMove == null) return;

    final zone = widget.zone;
    final newStart = zone.startMinutes + snappedDelta;
    final newEnd = zone.endMinutes + snappedDelta;
    if (newStart < 0 || newEnd > 24 * 60) return;

    widget.onZoneMove!(zone.id, zone.startMinutes, newStart, newEnd);
  }

  @override
  Widget build(BuildContext context) {
    // Live preview: an in-progress resize/move renders at its candidate
    // GEOMETRY rather than waiting for the write to land, matching every
    // other drag surface in this codebase (`_DraggableTaskBlock`'s own
    // `_dragOffset`/`_resizeOffset`). `zone` itself is passed through
    // UNCHANGED — only `previewTop`/`previewHeight` override where this
    // renders, mirroring `ZoneContainerBlock`'s own live-resize precedent
    // in Zone view (see `ZoneBackgroundBlock.previewTop`'s own doc
    // comment for why this beat giving `Zone` a `copyWith`).
    final dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final zoneStart = dayStart.add(Duration(minutes: widget.zone.startMinutes));
    final strictTop =
        zoneStart.difference(widget.rangeStart).inMinutes *
        widget.pixelsPerMinute;
    final strictHeight = widget.zone.durationMinutes * widget.pixelsPerMinute;
    final isPreviewing = _isMoving || _isResizing;
    final previewTop = !isPreviewing
        ? null
        : _isMoving
        ? strictTop + _moveMinutesDelta * widget.pixelsPerMinute
        : (_resizingTopEdge
              ? strictTop + _resizeMinutesDelta * widget.pixelsPerMinute
              // Bottom-edge resize doesn't move the top edge at all —
              // still passed through (not left null) so the pair stays
              // both-set, per `ZoneBackgroundBlock.previewTop`'s contract.
              : strictTop);
    final previewHeight = !isPreviewing
        ? null
        : _isMoving
        ? strictHeight
        : strictHeight +
              (_resizingTopEdge ? -1 : 1) *
                  _resizeMinutesDelta *
                  widget.pixelsPerMinute;

    final interactionEnabled = _interactionEnabled;

    // Live move/resize time badges — "also should be show for zones,"
    // extending the same left-pinned accent-time treatment tasks get.
    // Unsnapped (matches previewTop/previewHeight's own live-geometry
    // precision above); the commit path still snaps to `_snapMinutes`
    // via `_commitMove`/`_commitResize`. A resize shows only the edge
    // that's actually moving (null for the anchored one) — mirroring
    // `_liveEdgeTimeLabels`' own "only the edge that moves" contract for
    // tasks; a move shows BOTH (they shift together).
    final liveStartMinutes = !isPreviewing
        ? null
        : _isMoving
        ? (widget.zone.startMinutes + _moveMinutesDelta).round()
        : (_resizingTopEdge
              ? (widget.zone.startMinutes + _resizeMinutesDelta).round()
              : null);
    final liveEndMinutes = !isPreviewing
        ? null
        : _isMoving
        ? (widget.zone.endMinutes + _moveMinutesDelta).round()
        : (_resizingTopEdge
              ? null
              : (widget.zone.endMinutes + _resizeMinutesDelta).round());

    return ZoneBackgroundBlock(
      theme: widget.theme,
      zone: widget.zone,
      day: widget.day,
      rangeStart: widget.rangeStart,
      pixelsPerMinute: widget.pixelsPerMinute,
      left: widget.left,
      width: widget.width,
      previewTop: previewTop,
      previewHeight: previewHeight,
      liveStartMinutes: liveStartMinutes,
      liveEndMinutes: liveEndMinutes,
      // Drives wiggle/handle/header visibility — see `_interactionEnabled`'s
      // own doc comment for why this differs from plain
      // `widget.editModeEnabled` under multi-task mode.
      editModeEnabled: interactionEnabled,
      phaseOffset: widget.phaseOffset,
      onHeaderTap: _effectiveOnHeaderTap,
      onResizeTopStart: !interactionEnabled
          ? null
          : (_) {
              _playHaptic(AmbleHaptic.lift);
              setState(() {
                _isResizing = true;
                _resizingTopEdge = true;
                _resizeMinutesDelta = 0;
              });
            },
      onResizeTopUpdate: !interactionEnabled
          ? null
          : (details) => setState(() {
              _resizeMinutesDelta += details.delta.dy / widget.pixelsPerMinute;
            }),
      onResizeTopEnd: !interactionEnabled ? null : (_) => _commitResize(),
      onResizeBottomStart: !interactionEnabled
          ? null
          : (_) {
              _playHaptic(AmbleHaptic.lift);
              setState(() {
                _isResizing = true;
                _resizingTopEdge = false;
                _resizeMinutesDelta = 0;
              });
            },
      onResizeBottomUpdate: !interactionEnabled
          ? null
          : (details) => setState(() {
              _resizeMinutesDelta += details.delta.dy / widget.pixelsPerMinute;
            }),
      onResizeBottomEnd: !interactionEnabled ? null : (_) => _commitResize(),
      // Gated identically to the resize handlers: an unselected zone under
      // multi-task mode has no move drag (only the header's tap-to-select
      // is live there — see `ZoneBackgroundBlock`'s own header, which
      // renders tap-to-select XOR drag-to-move, never both at once).
      onMoveStart: !interactionEnabled
          ? null
          : (details) {
              _playHaptic(AmbleHaptic.lift);
              _deleteTargetWasArmed = false;
              setState(() {
                _isMoving = true;
                _moveMinutesDelta = 0;
              });
              _lastMoveGlobalPosition = details.globalPosition;
              // Edit Mode only — outside it there is no delete target to
              // show at all, same gate `_DraggableTaskBlockState.onDragStart`
              // uses.
              if (widget.editModeEnabled) {
                widget.onDeleteTargetVisibilityChanged?.call(true);
              }
            },
      onMoveUpdate: !interactionEnabled
          ? null
          : (details) {
              setState(() {
                _moveMinutesDelta += details.delta.dy / widget.pixelsPerMinute;
              });
              _lastMoveGlobalPosition = details.globalPosition;
              if (widget.editModeEnabled && widget.deleteTargetKey != null) {
                final armed = isInsideDeleteTarget(
                  widget.deleteTargetKey!,
                  details.globalPosition,
                );
                if (armed && !_deleteTargetWasArmed) {
                  _playHaptic(AmbleHaptic.warning);
                }
                _deleteTargetWasArmed = armed;
                widget.onDeleteTargetArmedChanged?.call(armed);
              }
            },
      onMoveEnd: !interactionEnabled ? null : (_) => _commitMove(),
    );
  }
}

/// Wraps [PendingTaskPill] with the same drag-to-move/drag-to-resize
/// physics real tasks get — confirmed scope: the wiggly placeholder
/// pill's own drag/resize reuses Edit Mode's snap-to-5min rule and
/// cascade-push (if "Prevent overlapping tasks" is on), computed and
/// applied only at Save (not live during this drag — confirmed scope),
/// so this widget only ever writes to [pendingTaskDraftProvider], never
/// the task repository. A [ConsumerStatefulWidget] living inside
/// `_DayTimelineState` for the same reason [_DraggableZoneBlock] already
/// is: reading `ref` locally here is simpler than threading a second
/// layer of plain callbacks through `_DayTimeline` for state this widget
/// alone owns frame-to-frame (the live drag/resize preview).
class _DraggablePendingTaskPill extends ConsumerStatefulWidget {
  const _DraggablePendingTaskPill({
    super.key,
    required this.theme,
    required this.draft,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.left,
    required this.width,
    required this.slot,
    required this.textColumnLeft,
    required this.textColumnRight,
  });

  final AmbleTheme theme;
  final PendingTaskDraft draft;
  final DateTime rangeStart;
  final double pixelsPerMinute;
  final double left;
  final double width;

  /// The lane the shared overlap layout assigned this draft — the draft
  /// participates in that layout exactly as a real task does, so an
  /// overlapping placeholder sits BESIDE what it collides with rather
  /// than painting over it.
  final TaskLayoutSlot slot;

  /// The shared text column every task's name is aligned to, and the
  /// gutter reserved on its right — passed through so the placeholder's
  /// own name lines up with the real ones instead of sitting wherever its
  /// own rail happens to end.
  final double textColumnLeft;
  final double textColumnRight;

  @override
  ConsumerState<_DraggablePendingTaskPill> createState() =>
      _DraggablePendingTaskPillState();
}

class _DraggablePendingTaskPillState
    extends ConsumerState<_DraggablePendingTaskPill> {
  double _dragOffset = 0;
  double _resizeOffset = 0;

  /// Live TOP-edge resize delta, the mirror of [_resizeOffset] — see
  /// [_commitResizeTop].
  double _resizeTopOffset = 0;

  double get _baseTop =>
      widget.draft.scheduledAt.difference(widget.rangeStart).inMinutes *
      widget.pixelsPerMinute;

  double get _baseHeight =>
      widget.draft.durationMinutes * widget.pixelsPerMinute;

  void _commitMove() {
    final delta = snappedMinutesDelta(_dragOffset, widget.pixelsPerMinute);
    setState(() => _dragOffset = 0);
    if (delta == 0) return;

    final newScheduledAt = widget.draft.scheduledAt.add(
      Duration(minutes: delta),
    );
    // A day-boundary/cascade-feasibility check only — per confirmed scope,
    // the cascade itself is computed and applied at Save, never live here.
    // A synthetic in-memory Task (never persisted, never touching a
    // repository) stands in for the draft so computeCascadeMoves' own
    // signature — which needs a real Task's id/durationMinutes — can be
    // reused as-is rather than duplicating its logic for a second shape.
    if (ref.read(preventOverlappingTasksSettingProvider)) {
      final tasks = ref.read(taskListProvider);
      final overlaps = overlapsExistingTask(
        scheduledAt: newScheduledAt,
        durationMinutes: widget.draft.durationMinutes,
        existingTasks: tasks,
      );
      if (overlaps) {
        final draggedTask = Task(
          id: widget.draft.id,
          title: '',
          scheduledAt: newScheduledAt,
          durationMinutes: widget.draft.durationMinutes,
        );
        final sameDayTasks = tasks
            .where(
              (t) =>
                  t.isScheduled &&
                  t.scheduledAt!.year == newScheduledAt.year &&
                  t.scheduledAt!.month == newScheduledAt.month &&
                  t.scheduledAt!.day == newScheduledAt.day,
            )
            .toList();
        final moves = computeCascadeMoves(
          draggedTask: draggedTask,
          newStart: newScheduledAt,
          sameDayTasks: sameDayTasks,
        );
        // Day-boundary guard failed (or, in principle, some other
        // infeasibility computeCascadeMoves might report) — snap back
        // rather than commit a move that Save could never actually apply.
        if (moves == null) return;
      }
    }

    ref.read(pendingTaskDraftProvider.notifier).updatePosition(newScheduledAt);
  }

  void _commitResize() {
    final delta = snappedDurationDelta(_resizeOffset, widget.pixelsPerMinute);
    setState(() => _resizeOffset = 0);
    if (delta == 0) return;

    final newDuration = math.max(
      minTaskDurationMinutes,
      widget.draft.durationMinutes + delta,
    );
    ref.read(pendingTaskDraftProvider.notifier).updateDuration(newDuration);
  }

  /// Top-edge resize — the draft's START moves while its END stays put,
  /// so this commits BOTH position and duration, unlike [_commitResize]'s
  /// duration-only bottom edge. Mirrors `_DraggableTaskBlockState`'s own
  /// top-edge commit for real tasks.
  void _commitResizeTop() {
    final rawDelta = snappedDurationDelta(
      _resizeTopOffset,
      widget.pixelsPerMinute,
    );
    setState(() => _resizeTopOffset = 0);
    if (rawDelta == 0) return;

    // Clamped so the start can never cross the (fixed) end — the same
    // floor the bottom edge gets from its own `math.max`, expressed here
    // against the start because this is the edge that moves.
    final startDelta = math.min(
      rawDelta,
      widget.draft.durationMinutes - minTaskDurationMinutes,
    );
    if (startDelta == 0) return;

    final newScheduledAt = widget.draft.scheduledAt.add(
      Duration(minutes: startDelta),
    );
    final dayStart = DateTime(
      newScheduledAt.year,
      newScheduledAt.month,
      newScheduledAt.day,
    );
    if (newScheduledAt.isBefore(dayStart)) return;

    final notifier = ref.read(pendingTaskDraftProvider.notifier);
    notifier.updatePosition(newScheduledAt);
    notifier.updateDuration(widget.draft.durationMinutes - startDelta);
  }

  @override
  Widget build(BuildContext context) {
    final top = _baseTop + _dragOffset + _resizeTopOffset;
    final height = math.max(
      _baseHeight + _resizeOffset - _resizeTopOffset,
      widget.theme.sizeTaskBadge,
    );

    // A top-edge drag moves the pill's own top as it goes (the end is
    // anchored), so it shifts `top` AND shrinks `height` — the bottom
    // edge only does the latter.
    // The lane the shared overlap layout assigned — identical math to
    // `_DraggableTaskBlock`'s own, so a placeholder and a real task in
    // the same overlap group land in genuinely the same lanes rather
    // than two schemes that happen to agree most of the time.
    final columnOffset = pillBoxLeftForColumn(
      column: widget.slot.column,
      pillWidth: _pillWidth(widget.theme),
      columnGap: _columnGap(widget.theme),
    );

    // The live start/end this pill would commit to right now — shown via
    // the same accent "time on the right" treatment the long-press
    // placement line uses, requested directly: "when quick new add task
    // is dropped and wiggly showing start and end of task... until it's
    // scheduled or closed." Mirrors `_commitMove`/`_commitResize`/
    // `_commitResizeTop`'s own snap math exactly, but read-only here —
    // purely for the label, never written to the draft provider until an
    // actual commit happens.
    final previewStart = widget.draft.scheduledAt.add(
      Duration(
        minutes:
            snappedMinutesDelta(_dragOffset, widget.pixelsPerMinute) +
            snappedDurationDelta(_resizeTopOffset, widget.pixelsPerMinute),
      ),
    );
    final previewDurationMinutes = math.max(
      minTaskDurationMinutes,
      widget.draft.durationMinutes +
          snappedDurationDelta(_resizeOffset, widget.pixelsPerMinute) -
          snappedDurationDelta(_resizeTopOffset, widget.pixelsPerMinute),
    );
    final previewEnd = previewStart.add(
      Duration(minutes: previewDurationMinutes),
    );

    return PendingTaskPill(
      theme: widget.theme,
      top: top,
      left: widget.left,
      columnOffset: columnOffset,
      width: widget.width,
      height: height,
      startTime: TimeOfDay.fromDateTime(previewStart),
      endTime: TimeOfDay.fromDateTime(previewEnd),
      textColumnLeft: widget.textColumnLeft,
      textColumnRight: widget.textColumnRight,
      onMoveStart: (_) {},
      onMoveUpdate: (delta) => setState(() => _dragOffset += delta),
      onMoveEnd: _commitMove,
      onResizeStart: (_) {},
      onResizeUpdate: (delta) => setState(() => _resizeOffset += delta),
      onResizeEnd: _commitResize,
      onResizeTopStart: (_) {},
      onResizeTopUpdate: (delta) => setState(() => _resizeTopOffset += delta),
      onResizeTopEnd: _commitResizeTop,
    );
  }
}

/// Wraps a [TaskCapsuleBlock] with vertical drag-to-reschedule. Tracks a
/// live drag offset for visual feedback while dragging; on release, snaps
/// to the nearest 5-minute increment and calls [onReschedule] — which is
/// the only place a reschedule actually gets written (via
/// [TaskList.rescheduleTask]).
class _DraggableTaskBlock extends ConsumerStatefulWidget {
  const _DraggableTaskBlock({
    super.key,
    required this.task,
    required this.theme,
    required this.baseTop,
    required this.left,
    required this.rightInset,
    required this.slot,
    required this.onTap,
    required this.onToggleComplete,
    required this.onReschedule,
    required this.onDraggingChanged,
    required this.onSettled,
    required this.pixelsPerMinute,
    required this.isDraggable,
    this.fadeInOnFirstBuild = false,
    this.growFromMinutes,
    this.contentHidden = false,
    this.compactText = false,
    this.showCompletionCheckbox = true,
    this.splitLayout = false,
    this.textColumnLeft = 0,
    this.textColumnRight = 0,
    this.labelOffset = 0,
    this.bottomTrim = 0,
    this.maxPillHeight,
    this.editModeEnabled = false,
    this.onDeleteTask,
    this.deleteTargetKey,
    this.onDeleteTargetVisibilityChanged,
    this.onDeleteTargetArmedChanged,
  });

  final Task task;
  final AmbleTheme theme;
  final double baseTop;
  final double left;

  /// The timeline's horizontal screen padding, applied to this block's
  /// own right edge. The scroll view no longer pads itself (so the
  /// tap-to-create ripple can reach the screen edges), so every child
  /// that used to stop at the padded viewport's edge carries the inset
  /// itself — see the scroll view's own `padding:` note.
  final double rightInset;

  /// Whether Edit Mode is active — see [_DayTimeline.editModeEnabled]'s
  /// own doc comment for why this is a plain field, not a Riverpod watch,
  /// on every widget between here and `TimelineScreen`.
  final bool editModeEnabled;

  /// See [_DayTimeline.onDeleteTask].
  final Future<void> Function(Task task)? onDeleteTask;

  /// The delete-drag-target's own `GlobalKey` — one shared instance owned
  /// by `_DayTimelineState` (there is only ever one delete target visible
  /// on screen at a time, regardless of how many draggable blocks exist),
  /// passed down so a drop can test its position against the target's
  /// resolved bounds via [isInsideDeleteTarget]. Null whenever Edit Mode
  /// is off, since the target itself never renders then.
  final GlobalKey? deleteTargetKey;

  /// Reported true for the duration of a move-drag while Edit Mode is
  /// active, so the parent can fade the delete target in/out — see
  /// `_DayTimelineState`'s own `_showDeleteTarget`. Distinct from
  /// [onDraggingChanged] (which drives the ghost) because the two are
  /// conceptually different signals that happen to fire at the same
  /// moments; kept separate rather than overloading one callback for two
  /// meanings.
  final ValueChanged<bool>? onDeleteTargetVisibilityChanged;

  /// Whether a move-drag is CURRENTLY positioned inside the delete
  /// target's bounds — drives the target's own armed/unarmed highlight.
  /// Reported on every drag update while Edit Mode is on, mirroring
  /// [onDeleteTargetVisibilityChanged]'s "own callback per distinct
  /// signal" reasoning.
  final ValueChanged<bool>? onDeleteTargetArmedChanged;

  /// This task's horizontal share of the timeline — full width when it
  /// overlaps nothing, a narrowed column when it clashes with others.
  final TaskLayoutSlot slot;

  final VoidCallback onTap;
  final VoidCallback onToggleComplete;
  final Future<void> Function(DateTime newScheduledAt) onReschedule;

  /// Reports drag start/end to the parent, which renders this task's
  /// faded "ghost" as its own sibling — see the comment on
  /// [_DayTimelineState._draggingTaskId] for why this lives one level up
  /// rather than inside this widget's own build().
  final ValueChanged<bool> onDraggingChanged;

  /// Fired once the drop's settle animation has finished, so the parent
  /// can stop pinning this block to the top of the Stack. Separate from
  /// [onDraggingChanged] because the ghost and the paint order have
  /// different lifetimes — see [_DayTimelineState._settlingTaskId].
  final VoidCallback onSettled;

  /// Vertical scale for this block's pill height, and the pixel->minute
  /// conversion behind drag-to-reschedule. Differs between timeline and
  /// collapsed modes — see [_collapsedPixelsPerMinute].
  final double pixelsPerMinute;

  /// False in collapsed mode, where vertical position carries no time
  /// meaning and a drag has nothing meaningful to convert into.
  final bool isDraggable;

  /// Fades this block in on its first build — set only for a task the
  /// create/edit modal just saved, so the user sees it arrive rather than
  /// finding it already there when the modal closes. Requested directly.
  final bool fadeInOnFirstBuild;

  /// The duration this block should RENDER at until the create/edit modal
  /// has finished closing, after which it animates to the task's real
  /// (already-saved) duration. Null except for a task whose duration the
  /// modal just changed.
  ///
  /// Needed because the save is written before the modal pops, so without
  /// this the pill reaches its new height while still hidden behind the
  /// modal and there is nothing left to watch — reported directly ("no se
  /// already placed or extended").
  final int? growFromMinutes;

  /// True for a resting cluster member — see [TaskCapsuleBlock.contentHidden].
  /// Ignored (treated as false) while this block is actively being
  /// dragged: a dragged task always renders its full content, per the
  /// settled clustering design (docs/DECISIONS.md) — the drag handler
  /// itself passes `contentHidden: false` down for that reason, this flag
  /// only ever reflects the RESTING state.
  final bool contentHidden;

  /// True in List (collapsed) mode — see [TaskCapsuleBlock.compactText].
  final bool compactText;

  /// See [_DayTimeline.showCompletionCheckbox].
  final bool showCompletionCheckbox;

  /// See [TaskCapsuleBlock.splitLayout] — positions the pill and the
  /// time/title row independently so every task's name starts at the same
  /// x. True for the Spatial Task View (hour labels on); false in List
  /// (collapsed) mode, whose rows stack rather than sharing a time axis
  /// and whose text is already compact.
  final bool splitLayout;

  /// The shared x every task's time/title row starts at — see
  /// [_textColumnLeft]. Computed ONCE by the parent from the whole day's
  /// slots and passed down, rather than derived per block, since the whole
  /// point is that every block agrees on it. Ignored unless
  /// [splitLayout] is true.
  final double textColumnLeft;

  /// How far short of the day column's right edge the time/title row
  /// stops — always `rightEdgeInset`, the same margin the hour labels use
  /// on the left. **Changed 2026-09-12**: no longer widened when zones
  /// exist. It used to reserve extra room for the rotated zone-name label
  /// so a checkbox could never render under it; reported directly (with a
  /// reference screenshot marking the intended edge) that the checkbox
  /// should reach the TRUE screen edge instead, with the zone-name label
  /// sharing that same outer margin. The label is `IgnorePointer`, so it
  /// can't steal the checkbox's taps even where the two visually overlap.
  final double textColumnRight;

  /// How far this task's NAME sits below its own pill's top. Zero means
  /// perfectly aligned with the pill's icon (the normal case); a positive
  /// value means the label above it would have collided and pushed it
  /// down. See `computeLabelTops`.
  final double labelOffset;

  /// The bottom-edge counterpart to the top gap this task's zone already
  /// gets — see `_zoneTaskBottomTrim` in `_DayTimelineState`, the only
  /// place that computes a non-zero value. Passed straight through to
  /// `TaskCapsuleBlock.bottomTrim`.
  final double bottomTrim;

  /// Caps this task's pill height so it can't run into the next
  /// same-column task's top. See `_maxPillHeight` in `_DayTimelineState`,
  /// the only place that computes a non-null value. Passed straight
  /// through to `TaskCapsuleBlock.maxPillHeight`.
  final double? maxPillHeight;

  @override
  ConsumerState<_DraggableTaskBlock> createState() =>
      _DraggableTaskBlockState();
}

class _DraggableTaskBlockState extends ConsumerState<_DraggableTaskBlock> {
  double _dragOffset = 0;
  bool _isDragging = false;

  /// Routes a tap to selection instead of the detail sheet while Edit
  /// Mode's multi-task route is on (`DevMultiTaskEditMode`,
  /// `core/dev_config.dart`) — requested directly. Off (the default),
  /// this is exactly `widget.onTap` with nothing in between, so ordinary
  /// (single-task) Edit Mode and the non-Edit-Mode Timeline are both
  /// completely unaffected by any of this file's multi-task code. On, the
  /// detail sheet becomes unreachable from a tap — confirmed via
  /// AskUserQuestion: leaving multi-task mode is how you get back to it,
  /// same as leaving Edit Mode entirely already was the only way to reach
  /// resize handles before this feature existed.
  VoidCallback get _effectiveOnTap {
    if (!widget.editModeEnabled || !ref.watch(devMultiTaskEditModeProvider)) {
      // **2026-09-12 — reversed for the tapped-the-armed-task-itself
      // case.** Reported directly: "when by long tap task in edit mode
      // tapping on it again it's not opening detail, but stopping edit
      // mode (wiggling)." A tap on THIS SAME already-armed task now only
      // clears the arm — it no longer also opens the detail sheet.
      // Tapping a DIFFERENT task (or tapping while nothing is armed)
      // still opens the sheet exactly as before ("keep single tap to
      // open edit sheet" — that original work order's own premise never
      // covered tapping the SAME task twice in a row).
      if (_isArmed) {
        return () => ref.read(armedEditTaskProvider.notifier).clear();
      }
      return () {
        ref.read(armedEditTaskProvider.notifier).clear();
        widget.onTap();
      };
    }
    return () =>
        ref.read(editSelectionProvider.notifier).toggle(widget.task.id);
  }

  /// See [_effectiveOnTap]'s doc comment. Only meaningful while multi-task
  /// mode is actually on — every other read site already guards on that,
  /// so this doesn't re-check it itself.
  bool get _isSelected =>
      ref.watch(editSelectionProvider).contains(widget.task.id);

  /// Long-press arms THIS task for editing — requested directly: "long
  /// press on task should enable its edit mode (duration) wiggle." Null
  /// (no-op) while multi-task select mode's own tap-to-select is active,
  /// same guard as [_effectiveOnTap]: that mode already repurposes a tap on
  /// this block for a different meaning (selection), so a long-press
  /// arming a single task on top of that would be a second, conflicting
  /// gesture contract in the same mode.
  VoidCallback? get _effectiveOnLongPress {
    if (widget.editModeEnabled && ref.watch(devMultiTaskEditModeProvider)) {
      return null;
    }
    return () {
      // `lift` rather than `tap`: a long-press that arms edit mode is the
      // same class of event as picking a block up — the user is entering a
      // held state, and the haptic is the only cue that the press has
      // registered before the wiggle starts.
      _playHaptic(AmbleHaptic.lift);
      ref.read(armedEditTaskProvider.notifier).arm(widget.task.id);
    };
  }

  /// True while THIS task specifically is long-press-armed — requested
  /// directly: "long press on task should enable its edit mode (duration)
  /// wiggle." Independent of [_DayTimeline.editModeEnabled] (the existing
  /// global toggle): a task can be armed with the global mode off, and the
  /// global mode being on doesn't imply any one task is armed.
  bool get _isArmed => ref.watch(armedEditTaskProvider) == widget.task.id;

  /// Drives THIS block's own wiggle/resize-handle visibility — either the
  /// existing global Edit Mode is on, or this one task is long-press-armed.
  /// Deliberately NOT used for the drag-to-delete-target machinery (that
  /// stays gated on `widget.editModeEnabled` alone, unchanged) — delete via
  /// drag-to-target is a whole-Edit-Mode feature per CONSTITUTION.md, not
  /// part of this per-task arming.
  bool get _editActive => widget.editModeEnabled || _isArmed;

  /// True for exactly the build in which the view MODE changed (List's
  /// collapsed stack <-> Task view's real time axis, tracked via
  /// [_DraggableTaskBlock.isDraggable]). Suppresses this block's own
  /// position animation for that one frame.
  ///
  /// Reported directly: switching List -> Task made every capsule visibly
  /// slide down into place from the top. The two modes lay blocks out at
  /// completely different `top` values, and this block is the SAME element
  /// across the switch (only `showHourLabels` differs, so nothing
  /// remounts), so `AnimatedPositioned` did exactly what it's built to do
  /// — tween between two unrelated layouts. A mode switch isn't motion
  /// worth showing; the new layout should simply be there.
  bool _suppressPositionAnimation = false;

  /// Drives the just-saved entrance stagger (see
  /// [TaskCapsuleBlock.entranceProgress], which spreads this single value
  /// across the block's five parts). Starts at 0 only when this block is
  /// the one that was just created; every other block starts — and stays
  /// — at 1, so nothing animates on an ordinary rebuild or day change.
  late double _entranceProgress = widget.fadeInOnFirstBuild ? 0 : 1;

  /// The duration to render at while the modal is still closing — see
  /// [_DraggableTaskBlock.growFromMinutes]. Cleared once the modal has
  /// gone, which is what lets the pill animate into its real height.
  late int? _heldDurationMinutes = widget.growFromMinutes;

  @override
  void initState() {
    super.initState();
    if (!widget.fadeInOnFirstBuild && widget.growFromMinutes == null) return;
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(_DraggableTaskBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A duration change does NOT remount this block — same task id, same
    // key, so the element is updated rather than recreated and initState
    // never runs again. Without this the held pre-save height would never
    // be picked up (or never released), which is exactly why the resize
    // wasn't visible. A newly CREATED task does mount fresh, so that case
    // is still handled by initState above.
    // View-mode switch (List <-> Task, via isDraggable) — snap straight to
    // the new layout instead of tweening from the old one. Cleared again
    // one frame later so a genuine reposition WITHIN the same mode (drag,
    // cascade push) still eases normally.
    if (widget.isDraggable != oldWidget.isDraggable) {
      _suppressPositionAnimation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _suppressPositionAnimation = false);
      });
    }

    if (widget.growFromMinutes == oldWidget.growFromMinutes) return;
    if (widget.growFromMinutes == null) return;
    setState(() => _heldDurationMinutes = widget.growFromMinutes);
    _scheduleReveal();
  }

  /// Holds the block at its pre-save appearance until the create/edit
  /// modal has finished sliding away, then releases it so the entrance
  /// (or the pill's resize) plays where the user can actually see it —
  /// reported directly: starting at save time meant the whole animation
  /// ran behind the closing modal and was over before the timeline was
  /// visible.
  void _scheduleReveal() {
    Future<void>.delayed(widget.theme.motionRouteSettle, () {
      if (!mounted) return;
      setState(() {
        _entranceProgress = 1;
        _heldDurationMinutes = null;
      });
    });
  }

  /// True from the moment the finger lifts until the reschedule write has
  /// landed and `baseTop` has caught up. While set, the block renders at
  /// the SNAPPED offset rather than the raw finger offset — combined with
  /// the AnimatedPositioned below (which is only un-animated while the
  /// finger is actually down), that turns the raw → snapped correction
  /// into an eased settle instead of a jump.
  ///
  /// The correction is real and was reported as a flicker: mid-drag the
  /// block tracks the finger exactly (`_dragOffset` is unsnapped), but the
  /// drop commits `_previewStartsAt`, which IS snapped — so at release the
  /// block was drawn up to half a snap interval away from where it was
  /// about to land, then jumped there when the new data arrived.
  bool _isSettling = false;

  static const _snapMinutes = 5;

  /// How much a dragged block grows. Deliberately subtle — enough to read
  /// as "picked up" alongside the shadow, small enough that the block still
  /// lines up believably with the hour row it will land on. A larger scale
  /// makes the drop target ambiguous, since the block no longer matches the
  /// size of the slot it's being dropped into.
  static const _liftScale = 1.04;

  /// Live duration delta (minutes) while a resize drag is in progress —
  /// the resize-drag counterpart to [_dragOffset], unsnapped while the
  /// finger is down, applied to `task.durationMinutes` only at release.
  /// Zero whenever no resize is in progress.
  double _resizeOffset = 0;
  bool _isResizing = false;

  /// Live TOP-edge resize delta (pixels) — the mirror of [_resizeOffset],
  /// but for the handle that moves the task's START while its END stays
  /// fixed. Dragging DOWN (positive) shortens the task from the top and
  /// pushes its start later; dragging UP (negative) lengthens it earlier.
  /// Zero whenever no top-edge resize is in progress. Requested directly:
  /// "let's include resize up (so resize handle on top) ... we already
  /// have that in zone resize."
  double _resizeTopOffset = 0;
  bool _isResizingTop = false;

  /// The task's own snap granularity — matches `TaskDurationModal`'s wheel
  /// picker (`minuteStep: 5`), which is the existing duration-entry
  /// surface this resize handle needs to feel consistent with, and also
  /// matches drag-to-reschedule's own `_snapMinutes` above. Not a new
  /// increment invented for this gesture.
  static const _durationSnapMinutes = 5;

  /// The floor a Task resize can shrink `durationMinutes` to. No existing
  /// constant enforces a real minimum anywhere in the codebase —
  /// `TaskDurationModal` only floors at 1 minute to avoid a literal zero.
  /// Chosen here as [_durationSnapMinutes] itself (5) rather than 1: a
  /// drag gesture's own granularity already can't express anything finer
  /// than one snap step, so a 1-minute floor could never actually be
  /// reached by dragging in the first place, and 5 minutes is still a
  /// materially real duration a task can usefully have (unlike 1).
  /// Flagged in docs/DECISIONS.md as a judgment call, not a discovered
  /// existing rule.
  static const _minDurationMinutes = _durationSnapMinutes;

  int get _snappedResizeDelta =>
      (_resizeOffset / widget.pixelsPerMinute / _durationSnapMinutes).round() *
      _durationSnapMinutes;

  /// The smallest duration whose pill is still tall enough to render
  /// without hitting [_pillHeight]'s own `sizeTaskBadge` floor.
  ///
  /// **This is the constraint that actually binds a top-edge drag, and it
  /// is NOT [_minDurationMinutes].** The pill's rendered height is
  /// `max(duration x pixelsPerMinute, sizeTaskBadge)`, so below this many
  /// minutes the pill stops shrinking even though the duration keeps
  /// falling. For a top-edge drag — which moves `top` by the start delta
  /// while shrinking the height by that same delta — the two only cancel
  /// (leaving the END anchored) while the height is genuinely still
  /// shrinking. Past the floor the height freezes, `top` keeps moving,
  /// and the whole pill slides downward: reported directly as "it's
  /// almost like I'm moving the pill and the bottom... is being resized
  /// downward," with the end-time badge drifting along with it.
  ///
  /// At the default scale this is 24px / 1.5 = 16 minutes — more than
  /// three times [_minDurationMinutes] (5), which is why clamping to that
  /// constant alone never prevented the slide.
  double get _minRenderableDurationMinutes =>
      _pillWidth(widget.theme) / widget.pixelsPerMinute;

  /// How far the START may move on a top-edge drag before the pill can no
  /// longer shrink to match — i.e. the point past which moving it further
  /// would translate the whole block instead of resizing its top edge.
  /// Shared by the live preview and the commit so the two can never
  /// disagree about where the drag actually stopped.
  double _clampTopStartDelta(double rawDelta) => math.min(
    rawDelta,
    widget.task.durationMinutes! - _minRenderableDurationMinutes,
  );

  /// The RAW (unsnapped) live duration for a bottom-edge drag.
  ///
  /// Live geometry follows the finger continuously and snaps only on
  /// release — the same contract move-drag already states for itself
  /// ("while dragging, follow the finger exactly (unsnapped)... once
  /// released, switch to the SNAPPED offset"). Driving the pill from the
  /// snapped value instead made it jump a whole 5-minute step at a time
  /// (~7px at the default scale) while the time badge beside it changed
  /// on the same instants — which read as the badge responding and the
  /// pill lagging behind it, reported directly.
  double get _livePreviewDurationMinutes => math.max(
    widget.task.durationMinutes! + _resizeOffset / widget.pixelsPerMinute,
    _minDurationMinutes.toDouble(),
  );

  /// The duration this resize would COMMIT to if released right now —
  /// snapped, and floored at [_minDurationMinutes], mirroring
  /// [_previewStartsAt]'s own "what the drop would actually commit"
  /// contract for move-drag.
  int get _previewDurationMinutes => math.max(
    widget.task.durationMinutes! + _snappedResizeDelta,
    _minDurationMinutes,
  );

  /// [_snappedResizeDelta]'s top-edge counterpart — how far (in snapped
  /// minutes) the START would move if the top-edge drag were released
  /// now. Positive shortens from the top (start moves later).
  int get _snappedResizeTopDelta =>
      (_resizeTopOffset / widget.pixelsPerMinute / _durationSnapMinutes)
          .round() *
      _durationSnapMinutes;

  /// The RAW (unsnapped) live start delta for a top-edge drag — see
  /// [_livePreviewDurationMinutes] for why live geometry is unsnapped,
  /// and [_minRenderableDurationMinutes] for why the clamp is the
  /// pill-height floor rather than [_minDurationMinutes].
  double get _liveTopStartDelta =>
      _clampTopStartDelta(_resizeTopOffset / widget.pixelsPerMinute);

  /// The live duration a top-edge drag is previewing. Always exactly
  /// `duration - liveStartDelta`, so the shrink and the downward shift of
  /// `top` cancel at every point in the gesture and the END edge stays
  /// genuinely anchored.
  double get _liveTopDurationMinutes =>
      widget.task.durationMinutes! - _liveTopStartDelta;

  /// How far the start ACTUALLY moves when a top-edge drag is COMMITTED —
  /// the snapped delta under the same floor clamp the live preview uses,
  /// so what the user released on is what gets saved.
  int get _previewTopStartDelta =>
      _clampTopStartDelta(_snappedResizeTopDelta.toDouble()).floor();

  /// The duration a top-edge resize would commit to — the end stays put,
  /// so the duration shrinks by exactly however far the start moved.
  int get _previewTopDurationMinutes =>
      widget.task.durationMinutes! - _previewTopStartDelta;

  /// The last global pointer position reported by the active move-drag —
  /// needed at drop time to test against the delete target's bounds
  /// (`DragEndDetails` carries velocity only, no position). Null whenever
  /// no drag is in progress.
  Offset? _lastDragGlobalPosition;

  /// The start time this drag would commit to if released right now —
  /// derived from the same snapped offset the drop itself uses, so the
  /// time shown mid-drag can never disagree with the time actually saved.
  DateTime get _previewStartsAt =>
      widget.task.scheduledAt!.add(Duration(minutes: _snappedMinutesDelta));

  int get _snappedMinutesDelta =>
      (_dragOffset / widget.pixelsPerMinute / _snapMinutes).round() *
      _snapMinutes;

  /// The last [_snappedMinutesDelta] a haptic was played for, so the snap
  /// tick fires once per crossed increment rather than on every drag frame
  /// — `onDragUpdate` runs at display rate, and playing there unguarded
  /// would be a continuous buzz instead of a detent.
  int _lastSnapTickDelta = 0;

  /// Mirrors [_lastSnapTickDelta] for the delete target: its
  /// armed/disarmed state is recomputed on every drag update, so the
  /// warning must fire only on the false -> true edge.
  bool _deleteTargetWasArmed = false;

  void _playHaptic(AmbleHaptic haptic) =>
      ref.read(hapticsProvider).play(haptic);

  @override
  Widget build(BuildContext context) {
    // Edit Mode's multi-task group-move follow — see
    // `edit_selection_provider.dart`'s own doc comment on
    // `EditGroupGesture` for why this broadcast exists at all (every
    // block's own drag state is otherwise invisible to its siblings).
    // Only a SELECTED block that ISN'T the one actually under the finger
    // follows this: the dragged block already tracks the finger directly
    // via its own `_dragOffset`, and applying the broadcast on top of that
    // would double the offset.
    final multiTaskEditMode =
        widget.editModeEnabled && ref.watch(devMultiTaskEditModeProvider);
    final groupGesture = multiTaskEditMode
        ? ref.watch(editGroupGestureStateProvider)
        : null;
    final isGroupFollower =
        multiTaskEditMode &&
        !_isDragging &&
        _isSelected &&
        groupGesture?.kind == EditGroupGestureKind.move;
    final groupFollowOffsetPixels = isGroupFollower
        ? groupGesture!.deltaPixels
        : 0.0;

    // Same follow relationship, resize axis — a SELECTED block that isn't
    // the one under the finger previews the group's live resize delta via
    // `durationMinutesOverride` below, floored at its OWN
    // `_minDurationMinutes` independently (a short follower can't shrink
    // past its own floor just because a longer one still has room to).
    final isGroupResizeFollower =
        multiTaskEditMode &&
        !_isResizing &&
        _isSelected &&
        groupGesture?.kind == EditGroupGestureKind.resize;
    final groupResizeDeltaPixels = isGroupResizeFollower
        ? groupGesture!.deltaPixels
        : 0.0;
    final groupPreviewDurationMinutes = isGroupResizeFollower
        ? math.max(
            widget.task.durationMinutes! +
                (groupResizeDeltaPixels /
                            widget.pixelsPerMinute /
                            _durationSnapMinutes)
                        .round() *
                    _durationSnapMinutes,
            _minDurationMinutes,
          )
        : null;

    // Same follow relationship again, TOP-resize axis. Unlike the bottom
    // edge this shifts the follower's own top as well as its duration,
    // because a top-edge resize moves the start and keeps the END
    // anchored — so a follower that only changed height would visibly
    // disagree with what the gesture is doing to the block under the
    // finger.
    final isGroupResizeTopFollower =
        multiTaskEditMode &&
        !_isResizingTop &&
        _isSelected &&
        groupGesture?.kind == EditGroupGestureKind.resizeTop;
    // Clamped so a follower already at its own floor stops shrinking
    // rather than inverting — the same per-task independence the bottom
    // edge's own follower preview applies.
    final groupTopStartDelta = isGroupResizeTopFollower
        ? math.min(
            (groupGesture!.deltaPixels /
                        widget.pixelsPerMinute /
                        _durationSnapMinutes)
                    .round() *
                _durationSnapMinutes,
            widget.task.durationMinutes! - _minDurationMinutes,
          )
        : 0;
    final groupPreviewTopDurationMinutes = isGroupResizeTopFollower
        ? widget.task.durationMinutes! - groupTopStartDelta
        : null;

    // While dragging, follow the finger exactly (unsnapped) — confirmed
    // via AskUserQuestion over the alternative of snapping every 5 minutes
    // mid-drag. Once released, switch to the SNAPPED offset so the block
    // animates into the slot it actually commits to, closing the gap that
    // previously showed as a flicker.
    final effectiveOffset =
        (_isSettling
            ? _snappedMinutesDelta * widget.pixelsPerMinute
            : _dragOffset) +
        groupFollowOffsetPixels;
    // A top-edge resize moves the block's own TOP as it drags (the end
    // stays anchored), so unlike the bottom edge — which only changes
    // the previewed duration/height — this one has to shift `top` too.
    //
    // RAW (unsnapped) while THIS block is the one being dragged, so the
    // shift cancels exactly against the equally-raw height shrink
    // (`_liveTopDurationMinutes`) and the bottom edge stays put at every
    // point in the gesture. A snapped shift against a snapped height
    // still cancels, but both step in 5-minute jumps, which is the
    // stepping reported as the pill "taking time to animate." Group
    // FOLLOWERS keep the snapped delta: they aren't under a finger, so
    // continuity buys them nothing, and it keeps a follower's preview
    // identical to what the group commit will write.
    final topResizeOffset =
        ((_isResizingTop ? _liveTopStartDelta : 0) + groupTopStartDelta) *
        widget.pixelsPerMinute.toDouble();
    final top = widget.baseTop + effectiveOffset + topResizeOffset;
    final slot = widget.slot;

    // Dev-only layout experiment (see core/dev_config.dart) — always the
    // shipped default outside kDebugMode, since the providers themselves
    // default to `stacked`/true/true and nothing outside the Settings
    // screen's "Developer" section ever calls their `set()`.
    final devTextLayout = ref.watch(devTimelineTaskTextLayoutProvider);
    final devIconsVisible = ref.watch(devTimelineTaskIconsVisibleProvider);
    final devDurationVisible = ref.watch(
      devTimelineTaskDurationVisibleProvider,
    );
    final devTimeRangeVisible = ref.watch(
      devTimelineTaskTimeRangeVisibleProvider,
    );

    // Overlapping tasks are nudged right by one pill-width per column, so
    // each stays individually visible and tappable. A fractional width
    // wouldn't work here: the pill is a fixed-width element inside the
    // block's Row, so narrowing the available width leaves it exactly where
    // it was — the offset has to be a real horizontal shift.
    // The pill box's own left edge for this overlap lane. Kept in the
    // shared function (rather than inlined) so the "box starts AT the
    // lane, never left of it" invariant is testable — see
    // `pillBoxLeftForColumn` for the bug that rule exists to prevent.
    final columnOffset = pillBoxLeftForColumn(
      column: slot.column,
      pillWidth: _pillWidth(widget.theme),
      columnGap: _columnGap(widget.theme),
    );

    // AnimatedPositioned, not a plain Positioned: a zero duration while
    // the finger is down (so tracking is 1:1 with no lag), and a real
    // eased duration while settling, which is what makes the drop glide
    // into its snapped slot instead of jumping. The ghost is still
    // rendered by the parent (_DayTimelineState) as a sibling, via
    // widget.onDraggingChanged, specifically so this widget's own
    // hit-testable footprint stays badge-sized rather than inflating to
    // the full day-column height. See the comment on
    // _DayTimelineState._draggingTaskId for the bug that caused.
    // The capsule subtree itself, identical in BOTH layouts — only where
    // it gets positioned differs. Keeping one subtree (rather than a
    // branch per layout) is what guarantees the drag GestureDetector's own
    // render-object ancestry is the same either way, which this widget and
    // TaskCapsuleBlock both depend on (see their tree-shape comments).
    //
    // Lift state: while dragging, the block scales up slightly, gains a
    // large shadow, and stays fully opaque. The previous treatment was a
    // 0.75 opacity fade, which read as the block receding — the opposite
    // of being picked up. Animated so lift and settle are both visible
    // rather than snapping.
    // Drives the entrance stagger — TaskCapsuleBlock spreads this one
    // 0→1 value across its five parts (pill, name, time, icons,
    // checkbox), so the whole sequence runs off a single animation.
    // Slower than the lift/settle motions around it: this is a "here is
    // the thing you just made" beat, not a response to a gesture, so it
    // wants to be seen rather than to get out of the way.
    final capsuleCore = TweenAnimationBuilder<double>(
      // Only `end` matters on rebuild — TweenAnimationBuilder animates
      // from wherever it currently is toward the new end value, so
      // flipping _entranceProgress 0 -> 1 is what plays the sequence. The
      // RAW (linear) progress is what's tweened here — the opacity
      // stagger below applies its own `easeOut` shape on top of it, and
      // the entrance scale below applies a completely different
      // (overshooting) shape on top of the SAME raw value, so the two
      // effects can use different curves without fighting over one
      // shared, already-curved number.
      tween: Tween(begin: 0, end: _entranceProgress),
      duration: widget.theme.motionSlow,
      curve: Curves.linear,
      builder: (context, rawProgress, child) {
        final entranceProgress = Curves.easeOut.transform(rawProgress);
        // See entranceScaleFor's own doc comment — applied to the SAME
        // raw (linear) entrance timeline the opacity stagger above curves
        // separately (via its own `easeOut`), so the pop and the fade
        // finish together without the two effects fighting over one
        // shared, already-curved number. Only ever visible while
        // [_entranceProgress] actually animates 0 -> 1 (a newly created
        // block) — every other block starts and stays at
        // `rawProgress == 1`, i.e. `entranceScale == 1.0` on every build,
        // a no-op.
        final entranceScale = entranceScaleFor(rawProgress);
        return AnimatedScale(
          scale: _isDragging ? _liftScale : entranceScale,
          duration: widget.theme.motionFast,
          curve: widget.theme.curveStandard,
          // Drag handlers now live on TaskCapsuleBlock's own icon-pill
          // GestureDetector (scoped to just the pill, not the whole row) —
          // requested directly, since dragging from the title/time text
          // fought the timeline's own vertical scroll gesture.
          child: TaskCapsuleBlock(
            task: widget.task,
            // ConsumerStatefulWidget, so read directly rather than
            // threading a categoryById map through another field — the
            // parent _DayTimeline already does that for the ghost preview,
            // which isn't Riverpod-aware.
            category: ref
                .watch(categoryListProvider)
                .where((c) => c.id == widget.task.categoryId)
                .firstOrNull,
            pixelsPerMinute: widget.pixelsPerMinute,
            onTap: _effectiveOnTap,
            onLongPress: _effectiveOnLongPress,
            onToggleComplete: widget.onToggleComplete,
            dragPreviewStartsAt: _isDragging ? _previewStartsAt : null,
            // LIVE (unsnapped) while this block is the one under a
            // finger, so the dragged edge follows continuously rather
            // than jumping a 5-minute step at a time — see
            // `_livePreviewDurationMinutes`. Group followers and the
            // held pre-save duration stay snapped/whole: neither is
            // being dragged, so continuity buys them nothing.
            durationMinutesOverride: _isResizing
                ? _livePreviewDurationMinutes
                : _isResizingTop
                ? _liveTopDurationMinutes
                : (groupPreviewTopDurationMinutes ??
                          groupPreviewDurationMinutes ??
                          _heldDurationMinutes)
                      ?.toDouble(),
            entranceProgress: entranceProgress,
            isLifted: _isDragging,
            // Zeroes the pill's own height animation for the length of
            // the gesture, so the edge being dragged tracks the finger
            // 1:1 instead of easing after it — see
            // `TaskCapsuleBlock.isResizing`. Both edges, since a
            // top-edge resize changes the height too (the block's own
            // `top` moves as well, handled separately by the
            // AnimatedPositioned above).
            isResizing: _isResizing || _isResizingTop,
            // A dragged cluster member always shows full content — only
            // the resting state stays blanked.
            contentHidden: widget.contentHidden && !_isDragging,
            textLayout: devTextLayout,
            iconsVisible: devIconsVisible,
            durationVisible: devDurationVisible,
            timeRangeVisible: devTimeRangeVisible,
            compactText: widget.compactText,
            showCompletionCheckbox: widget.showCompletionCheckbox,
            splitLayout: widget.splitLayout,
            // While lifted, the pill carries its own name/time inside the
            // frosted pane — the shared text column stays anchored at its
            // own x, so a pill dragged away from it would otherwise travel
            // unlabelled. Requested directly.
            liftedTextInline: widget.splitLayout && _isDragging,
            bottomTrim: widget.bottomTrim,
            maxPillHeight: widget.maxPillHeight,
            // When a task shares its slot, its text has to stop
            // before the next column's pill starts, or titles run
            // under neighbours. Irrelevant in split layout — the text
            // isn't inside this widget there.
            maxTextWidth: slot.column < slot.columnCount - 1
                ? _pillWidth(widget.theme)
                : null,
            // Null handlers in collapsed mode leave the pill tappable but
            // not draggable — see _DraggableTaskBlock.isDraggable.
            onDragStart: !widget.isDraggable
                ? null
                : (details) {
                    _playHaptic(AmbleHaptic.lift);
                    _lastSnapTickDelta = 0;
                    _deleteTargetWasArmed = false;
                    setState(() => _isDragging = true);
                    widget.onDraggingChanged(true);
                    _lastDragGlobalPosition = details.globalPosition;
                    // Edit Mode only — outside it there is no delete target
                    // to show at all, per CONSTITUTION.md ("delete via
                    // drag-to-target ... only active while Edit Mode is
                    // on").
                    if (widget.editModeEnabled) {
                      widget.onDeleteTargetVisibilityChanged?.call(true);
                    }
                  },
            onDragUpdate: !widget.isDraggable
                ? null
                : (details) {
                    setState(() => _dragOffset += details.delta.dy);
                    _lastDragGlobalPosition = details.globalPosition;
                    // One tick per crossed 5-minute increment, so the drag
                    // feels like it is clicking through slots rather than
                    // sliding freely — the haptic counterpart of the snap
                    // the drop will actually apply.
                    final snapped = _snappedMinutesDelta;
                    if (snapped != _lastSnapTickDelta) {
                      _lastSnapTickDelta = snapped;
                      _playHaptic(AmbleHaptic.selection);
                    }
                    // Broadcast this drag's live offset to every OTHER
                    // selected block — see `build()`'s own
                    // `groupFollowOffsetPixels` for the read side. Only
                    // meaningful (and only ever watched) while multi-task
                    // mode is on and this block is itself selected;
                    // otherwise this is a single-task drag and nothing
                    // reads the broadcast.
                    if (multiTaskEditMode && _isSelected) {
                      ref
                          .read(editGroupGestureStateProvider.notifier)
                          .update(
                            EditGroupGesture(
                              kind: EditGroupGestureKind.move,
                              deltaPixels: _dragOffset,
                            ),
                          );
                    }
                    if (widget.editModeEnabled &&
                        widget.deleteTargetKey != null) {
                      final armed = isInsideDeleteTarget(
                        widget.deleteTargetKey!,
                        details.globalPosition,
                      );
                      // Edge-triggered: `armed` is recomputed every frame
                      // the finger is over the target, so firing on the
                      // value rather than the transition would buzz
                      // continuously for as long as the user hovers there.
                      if (armed && !_deleteTargetWasArmed) {
                        _playHaptic(AmbleHaptic.warning);
                      }
                      _deleteTargetWasArmed = armed;
                      widget.onDeleteTargetArmedChanged?.call(armed);
                    }
                  },
            onDragEnd: !widget.isDraggable
                ? null
                : (_) async {
                    // Drop the lift (shadow/scale) immediately regardless of
                    // outcome — that's the tactile "released" feedback and
                    // shouldn't wait on I/O. The haptic goes here for the
                    // same reason: it answers the finger lifting, not the
                    // save that follows it.
                    _playHaptic(AmbleHaptic.drop);
                    setState(() => _isDragging = false);
                    widget.onDraggingChanged(false);
                    if (widget.editModeEnabled) {
                      widget.onDeleteTargetVisibilityChanged?.call(false);
                      widget.onDeleteTargetArmedChanged?.call(false);
                    }

                    // Delete-drop short-circuit — checked FIRST, before any
                    // snap/overlap/cascade/group logic below even runs. Per
                    // the work order: "this path MUST bypass the existing
                    // cascade-push algorithm entirely ... the delete-drop
                    // handler should short-circuit before that logic is
                    // ever reached, not call it and discard the result."
                    // `_isSettling` is deliberately never set true here —
                    // there is no slot to settle into; the block is about
                    // to be removed from the list entirely once the delete
                    // completes and the provider refreshes.
                    //
                    // Group delete — confirmed via AskUserQuestion during
                    // planning ("delete moves whole group"): dropping any
                    // SELECTED task on the target removes every selected
                    // task, not just the one dragged. Each removal goes
                    // through the plain `deleteTask(id)` path (never
                    // `removeTask`'s own recurring-scope dialog) — asking
                    // that question once per selected recurring task would
                    // stack N sequential dialogs, so a group delete always
                    // means "this occurrence only" for every member,
                    // matching how group move/resize already treat each
                    // selected task as its own single instance rather than
                    // opening a series-wide question. Flagged in
                    // docs/DECISIONS.md as a judgment call.
                    final dropPosition = _lastDragGlobalPosition;
                    final droppedOnTarget =
                        widget.editModeEnabled &&
                        widget.deleteTargetKey != null &&
                        dropPosition != null &&
                        isInsideDeleteTarget(
                          widget.deleteTargetKey!,
                          dropPosition,
                        );

                    if (droppedOnTarget && multiTaskEditMode && _isSelected) {
                      ref
                          .read(editGroupGestureStateProvider.notifier)
                          .update(null);
                      setState(() => _dragOffset = 0);
                      final selectedIds = ref.read(editSelectionProvider);
                      final notifier = ref.read(taskListProvider.notifier);
                      for (final id in selectedIds) {
                        await notifier.deleteTask(id);
                      }
                      ref.read(editSelectionProvider.notifier).clear();
                      return;
                    }

                    if (droppedOnTarget) {
                      setState(() => _dragOffset = 0);
                      await widget.onDeleteTask?.call(widget.task);
                      return;
                    }

                    // Group move — this drag was broadcasting to selected
                    // siblings (see onDragUpdate above), so this drop
                    // commits the WHOLE selection rather than falling
                    // through to the single-task overlap/cascade path
                    // below, which was derived for one dragged task against
                    // others and has no concept of a locked group (per
                    // AskUserQuestion: skip cascade entirely for group
                    // moves). Clears the broadcast in every exit path (the
                    // clamped-to-zero case included) so no other block goes
                    // on reading a stale gesture.
                    if (multiTaskEditMode && _isSelected) {
                      final delta = _snappedMinutesDelta;
                      ref
                          .read(editGroupGestureStateProvider.notifier)
                          .update(null);
                      setState(() => _dragOffset = 0);
                      if (delta == 0) return;

                      final selectedIds = ref.read(editSelectionProvider);
                      final selectedTasks = ref
                          .read(taskListProvider)
                          .where((t) => selectedIds.contains(t.id))
                          .toList();
                      final moves = computeGroupMoves(
                        selectedTasks: selectedTasks,
                        deltaMinutes: delta,
                      );
                      if (moves.isEmpty) return;
                      await ref
                          .read(taskListProvider.notifier)
                          .rescheduleTaskWithCascade(moves);
                      return;
                    }

                    setState(() => _isSettling = true);

                    final minutesDelta = _snappedMinutesDelta;
                    final newScheduledAt = _previewStartsAt;

                    if (minutesDelta == 0) {
                      // Released within the snap threshold of where it started —
                      // ease back to the original slot rather than cutting.
                      setState(() => _dragOffset = 0);
                      await _endSettle();
                      return;
                    }

                    // With the preference on and the drop overlapping another task,
                    // the drag path pushes the conflicting task(s) out of the way
                    // (a cascade) instead of rejecting the drop — a deliberate,
                    // confirmed reversal of the reject-and-snap-back behavior for
                    // this one path only (the create wizard and edit-schedule modal
                    // keep reject-with-inline-error, unchanged, since neither has a
                    // drag context to compute a push from). See docs/DECISIONS.md.
                    if (ref.read(preventOverlappingTasksSettingProvider) &&
                        overlapsExistingTask(
                          scheduledAt: newScheduledAt,
                          durationMinutes: widget.task.durationMinutes!,
                          existingTasks: ref.read(taskListProvider),
                          excludeTaskId: widget.task.id,
                        )) {
                      final sameDayTasks = ref
                          .read(taskListProvider)
                          .where(
                            (other) =>
                                other.id != widget.task.id &&
                                other.isScheduled &&
                                _isSameDay(other.scheduledAt!, newScheduledAt),
                          )
                          .toList();

                      final moves = computeCascadeMoves(
                        draggedTask: widget.task,
                        newStart: newScheduledAt,
                        sameDayTasks: sameDayTasks,
                      );

                      // Day-boundary guard failed (or some other reason the
                      // cascade can't be satisfied) — abort the whole cascade and
                      // snap back exactly as the previous reject behavior did,
                      // as if the drop never happened. Nothing partially applies.
                      if (moves == null) {
                        setState(() => _dragOffset = 0);
                        await _endSettle();
                        return;
                      }

                      // Deliberately do NOT clear `_dragOffset` yet — see the
                      // comment below on the non-cascade path for why.
                      await ref
                          .read(taskListProvider.notifier)
                          .rescheduleTaskWithCascade(moves);

                      if (mounted) setState(() => _dragOffset = 0);
                      await _endSettle();
                      return;
                    }

                    // Deliberately do NOT clear `_dragOffset` yet. The write is
                    // async (repository save + notification sync + provider
                    // refresh), and clearing it here snapped the block back to
                    // its old position for the frame or two before the new
                    // data arrived — a visible blink of the task at its
                    // original time. Holding the offset keeps the block
                    // exactly where the user dropped it until the rebuilt
                    // widget takes over at the new `baseTop`.
                    await widget.onReschedule(newScheduledAt);

                    // Snap the offset back to zero only once the task itself
                    // has moved, so the two changes cancel out and the block
                    // never visibly jumps.
                    if (mounted) setState(() => _dragOffset = 0);
                    await _endSettle();
                  },
            editModeEnabled: _editActive,
            // TOP-edge resize — moves the task's START, end stays anchored,
            // so it commits BOTH scheduledAt and durationMinutes. Mirrors
            // the zone blocks' own long-standing top handle; requested
            // directly ("let's include resize up ... we already have that
            // in zone resize"). Broadcasts to the whole selection under
            // multi-task mode, exactly like the bottom edge below —
            // reversing an earlier single-task-only rule after it was
            // reported as a bug ("top resize in multi select not resizing
            // all selected like bottom does"). See CONSTITUTION.md.
            onResizeTopStart: _editActive
                ? (_) {
                    _playHaptic(AmbleHaptic.lift);
                    setState(() => _isResizingTop = true);
                  }
                : null,
            onResizeTopUpdate: _editActive
                ? (details) {
                    setState(() => _resizeTopOffset += details.delta.dy);
                    // Broadcast to every OTHER selected block — same
                    // mechanism as the bottom edge, but its own gesture
                    // kind so followers know to move their top edge too
                    // and not just their height.
                    if (multiTaskEditMode && _isSelected) {
                      ref
                          .read(editGroupGestureStateProvider.notifier)
                          .update(
                            EditGroupGesture(
                              kind: EditGroupGestureKind.resizeTop,
                              deltaPixels: _resizeTopOffset,
                            ),
                          );
                    }
                  }
                : null,
            onResizeTopEnd: _editActive
                ? (_) async {
                    _playHaptic(AmbleHaptic.drop);
                    final startDelta = _previewTopStartDelta;
                    final newDuration = _previewTopDurationMinutes;
                    setState(() {
                      _isResizingTop = false;
                      _resizeTopOffset = 0;
                    });

                    // Group top-resize — this drag was broadcasting to
                    // selected siblings, so this release commits the WHOLE
                    // selection: the same snapped delta moves every
                    // member's start and compensates its duration, so each
                    // task keeps its OWN end anchored (confirmed via
                    // AskUserQuestion). Each is clamped independently at
                    // its own floor so a short task stops rather than
                    // inverting, matching the bottom edge's own rule.
                    // Clears the broadcast on every exit path, including
                    // the zero-delta one, so no block reads a stale
                    // gesture.
                    if (multiTaskEditMode && _isSelected) {
                      ref
                          .read(editGroupGestureStateProvider.notifier)
                          .update(null);
                      if (startDelta == 0) return;

                      final selectedIds = ref.read(editSelectionProvider);
                      final selectedTasks = ref
                          .read(taskListProvider)
                          .where((t) => selectedIds.contains(t.id))
                          .toList();
                      final changes =
                          <
                            String,
                            ({DateTime scheduledAt, int durationMinutes})
                          >{};
                      for (final task in selectedTasks) {
                        final clamped = math.min(
                          startDelta,
                          task.durationMinutes! - _minDurationMinutes,
                        );
                        if (clamped == 0) continue;
                        final newStart = task.scheduledAt!.add(
                          Duration(minutes: clamped),
                        );
                        // Same day-boundary guard the single-task path
                        // applies, per task: a member that would leave its
                        // own day is skipped rather than dragging the
                        // whole group's write down with it.
                        final dayStart = DateTime(
                          newStart.year,
                          newStart.month,
                          newStart.day,
                        );
                        if (newStart.isBefore(dayStart)) continue;
                        changes[task.id] = (
                          scheduledAt: newStart,
                          durationMinutes: task.durationMinutes! - clamped,
                        );
                      }
                      if (changes.isEmpty) return;
                      await ref
                          .read(taskListProvider.notifier)
                          .resizeTasksFromTopInBatch(changes);
                      return;
                    }

                    // Snapped back to where it started — nothing to write,
                    // same short-circuit the bottom edge and move-drag both
                    // already use.
                    if (startDelta == 0) return;

                    final newScheduledAt = widget.task.scheduledAt!.add(
                      Duration(minutes: startDelta),
                    );
                    // Day-boundary guard, mirroring the zone top-resize's
                    // own `newStart < 0` check: a task may not be dragged
                    // out of the day it belongs to.
                    final dayStart = DateTime(
                      newScheduledAt.year,
                      newScheduledAt.month,
                      newScheduledAt.day,
                    );
                    if (newScheduledAt.isBefore(dayStart)) return;

                    // No cascade/overlap check — confirmed, matching the
                    // bottom edge's own rule (CONSTITUTION.md scopes the
                    // cascade to move/create, not resize) even though this
                    // edge does move the start time.
                    widget.task.scheduledAt = newScheduledAt;
                    widget.task.durationMinutes = newDuration;
                    await ref
                        .read(taskListProvider.notifier)
                        .updateTask(widget.task);
                  }
                : null,
            onResizeStart: _editActive
                ? (_) {
                    _playHaptic(AmbleHaptic.lift);
                    setState(() => _isResizing = true);
                  }
                : null,
            onResizeUpdate: _editActive
                ? (details) {
                    setState(() => _resizeOffset += details.delta.dy);
                    // Broadcast to every OTHER selected block — see the
                    // move-drag broadcast just above for the same reasoning
                    // and the read side (`groupPreviewDurationMinutes`).
                    if (multiTaskEditMode && _isSelected) {
                      ref
                          .read(editGroupGestureStateProvider.notifier)
                          .update(
                            EditGroupGesture(
                              kind: EditGroupGestureKind.resize,
                              deltaPixels: _resizeOffset,
                            ),
                          );
                    }
                  }
                : null,
            onResizeEnd: _editActive
                ? (_) async {
                    _playHaptic(AmbleHaptic.drop);
                    final newDuration = _previewDurationMinutes;
                    final resizeDelta = _snappedResizeDelta;
                    setState(() {
                      _isResizing = false;
                      _resizeOffset = 0;
                    });

                    // Group resize — this drag was broadcasting to selected
                    // siblings, so this release commits the WHOLE
                    // selection: the SAME delta applied to every member's
                    // own duration (confirmed via AskUserQuestion), each
                    // floored independently at its own
                    // [_minDurationMinutes] rather than one shared floor.
                    if (multiTaskEditMode && _isSelected) {
                      ref
                          .read(editGroupGestureStateProvider.notifier)
                          .update(null);
                      if (resizeDelta == 0) return;

                      final selectedIds = ref.read(editSelectionProvider);
                      final selectedTasks = ref
                          .read(taskListProvider)
                          .where((t) => selectedIds.contains(t.id))
                          .toList();
                      final newDurations = <String, int>{
                        for (final task in selectedTasks)
                          task.id: math.max(
                            task.durationMinutes! + resizeDelta,
                            _minDurationMinutes,
                          ),
                      };
                      await ref
                          .read(taskListProvider.notifier)
                          .resizeTasksInBatch(newDurations);
                      return;
                    }

                    // No-op resize (snapped back to the same duration it
                    // started at) writes nothing — matches move-drag's own
                    // "released within the snap threshold" short-circuit
                    // just above.
                    if (newDuration == widget.task.durationMinutes) return;
                    // BOTTOM-edge resize changes ONLY durationMinutes —
                    // scheduledAt is never touched here. (The TOP edge,
                    // added 2026-09-08, is the one that moves the start;
                    // see its own handler above and CONSTITUTION.md's
                    // recorded reversal for why the two edges differ.)
                    // Plain
                    // updateTask, not a dedicated resize method: this is
                    // exactly the same shape as any other single-field
                    // edit-and-save (the task detail sheet's own duration
                    // field), and no cascade/overlap check applies to
                    // resize — that's scoped to move/create only, per the
                    // work order.
                    widget.task.durationMinutes = newDuration;
                    await ref
                        .read(taskListProvider.notifier)
                        .updateTask(widget.task);
                  }
                : null,
          ),
        );
      },
    );

    // Edit Mode's own persistent visual signal — see
    // `edit_mode_wiggle.dart`. Suppressed while THIS block is actively
    // being manipulated (dragged or resized): a block already tracking
    // the finger has its own, more specific motion, and adding the
    // independent wiggle rotation on top of that would fight it rather
    // than read as "also editable." Phase offset derived from the task's
    // own id hash — stable across rebuilds, and different per task so a
    // day full of blocks doesn't wiggle in lockstep.
    //
    // Multi-task mode (`DevMultiTaskEditMode`) flips what wiggle MEANS —
    // requested directly: with it on, wiggle stops being "Edit Mode is
    // active" (every block) and becomes "this block is selected" (only
    // selected ones), since Edit Mode's own active-state signal would
    // otherwise be indistinguishable from the selection signal if both
    // used the same motion on every block at once. `multiTaskEditMode`
    // itself is computed once, up top in `build()` (see the group-move
    // follow logic there), not redeclared here.
    final wiggleEnabled = multiTaskEditMode
        ? (_isSelected && !_isDragging && !_isResizing && !_isResizingTop)
        : (_editActive && !_isDragging && !_isResizing && !_isResizingTop);
    final capsule = EditModeWiggle(
      enabled: wiggleEnabled,
      phaseOffset: (widget.task.id.hashCode % 1000) / 1000,
      child: capsuleCore,
    );

    if (widget.splitLayout) {
      return _buildSplit(
        top: top,
        columnOffset: columnOffset,
        pillContent: capsule,
        devDurationVisible: devDurationVisible,
        devTimeRangeVisible: devTimeRangeVisible,
        wiggleEnabled: wiggleEnabled,
      );
    }

    // Combined layout — one full-width box holding pill and text together,
    // exactly as before this split mode existed.
    return AnimatedPositioned(
      // Zero ONLY while this block is the one under the finger — dragging
      // has to track 1:1 with no lag. Every other repositioning eases:
      // this block settling into its snapped slot after a drop, and (the
      // case that matters for neighbours) a task the cascade pushed out of
      // the way, which now slides to its new time instead of teleporting.
      // `_isResizingTop` joins `_isDragging` here (2026-09-12): a
      // top-edge resize MOVES this block's own `top` (see the
      // `topResizeOffset` that feeds it), so an animated duration made
      // the pill lag behind the finger and then visibly settle —
      // reported directly ("seem that pill is moving not only resizing
      // top... and 'settles' with animation"). Any live gesture tracks
      // 1:1; only non-gesture repositioning (a cascade push, a settle
      // after drop) still eases.
      duration: _isDragging || _isResizingTop || _suppressPositionAnimation
          ? Duration.zero
          : widget.theme.motionNormal,
      curve: Curves.easeOut,
      top: top,
      left: widget.left + columnOffset,
      right: widget.rightInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          capsule,
          if (!widget.compactText) ...[
            if (_isDragging || _isResizing || _isResizingTop)
              ..._liveEdgeTimeLabels(
                height: _pillHeight(
                  widget.theme,
                  widget.task,
                  widget.pixelsPerMinute,
                ),
              )
            else if (wiggleEnabled)
              ..._edgeTimeLabels(
                height: _pillHeight(
                  widget.theme,
                  widget.task,
                  widget.pixelsPerMinute,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// The task's own live start/end, shown via the same accent "time"
  /// treatment the long-press placement line and the pending draft pill
  /// use — requested directly: "also in edit mode for selected (wiggly
  /// tasks) we need to show it," then corrected to always sit on the
  /// LEFT, over the hour gutter, like every other edge-time use: "when
  /// wiggling on left generally all cases on left side." `height` is
  /// this block's own resting pill height (real duration ×
  /// pixelsPerMinute, not `top`-adjusted) since the block itself is what
  /// is positioned by the caller — these two labels only need to know
  /// how tall it is to hang correctly off its top and bottom edges.
  /// `left: -widget.left` walks each label back from the block's own
  /// local origin (`widget.left`, i.e. `hourGutterWidth`) to the day
  /// column's true x=0 — see [_liveEdgeTimeLabels]'s own doc comment for
  /// why every one of these labels shares that same trick.
  List<Widget> _edgeTimeLabels({required double height}) {
    final start = widget.task.scheduledAt!;
    final end = start.add(Duration(minutes: widget.task.durationMinutes!));
    return [
      Positioned(
        top: 0,
        left: -widget.left,
        child: FractionalTranslation(
          translation: const Offset(0, -0.5),
          // showLine: false — reported directly: unlike the long-press
          // placement line (marking a drop point on empty background),
          // this sits ON an already-visible task pill, so a second
          // full-width line reads as noise. Just the accent time badge.
          child: TaskEdgeTimeLabel(
            theme: widget.theme,
            time: TimeOfDay.fromDateTime(start),
            showLine: false,
          ),
        ),
      ),
      Positioned(
        top: height,
        left: -widget.left,
        child: FractionalTranslation(
          translation: const Offset(0, -0.5),
          child: TaskEdgeTimeLabel(
            theme: widget.theme,
            time: TimeOfDay.fromDateTime(end),
            showLine: false,
          ),
        ),
      ),
    ];
  }

  /// The live-updating counterpart of [_edgeTimeLabels] — shown instead
  /// of it while actually moving or resizing, since the task's own
  /// `scheduledAt`/`durationMinutes` are stale mid-gesture (the commit
  /// hasn't happened yet). Always left-pinned, same as the resting
  /// labels: "the time in accent color bg when moving or rezising,
  /// sohul[d] always be on left." A move-drag shows BOTH edges (start
  /// AND end move together, since the duration is unchanged) — reported
  /// directly as a gap: "when moving also end should be shown... atm
  /// only beginning start time."
  ///
  /// **2026-09-12 — both edges now shown during EITHER resize too**,
  /// reversing the original "only the edge that's actually moving"
  /// design. Reported directly as wrong: the anchored edge's own RESTING
  /// label (`_edgeTimeLabels`) doesn't render during an active gesture —
  /// `wiggleEnabled`'s branch and this one are mutually exclusive in the
  /// caller (`if (_isDragging || _isResizing || _isResizingTop) ... else
  /// if (wiggleEnabled) ...`) — so a resize was leaving the OTHER edge
  /// with no visible time label at all, not merely deferring to an
  /// already-shown one.
  ///
  /// **Also 2026-09-12 — the bottom-resize end label's own Y position now
  /// tracks the LIVE preview height**, not the stale resting `height`
  /// passed in. Reported directly: unlike the top-resize case (where the
  /// whole block, and everything positioned inside it, already shifts
  /// with `topResizeOffset` — see `build`'s own `top` computation — a
  /// LOCAL `top: 0` on the start label was already correct there), a
  /// bottom-edge resize leaves the block's own `top` fixed and only grows
  /// `height`, so the end label's local `top` has to move by the SAME
  /// live pixel delta the pill's own bottom edge is visibly moving by, or
  /// the label silently stops tracking the finger the instant a resize
  /// starts.
  List<Widget> _liveEdgeTimeLabels({required double height}) {
    final baseStart = widget.task.scheduledAt!;
    if (_isResizing) {
      // Driven by the LIVE (unsnapped) duration, matching what the pill
      // itself is rendering this frame — the badge and the geometry it
      // labels must come from one source, or the badge appears to
      // respond while the pill trails it (reported directly).
      final liveHeight = math.max(
        _livePreviewDurationMinutes * widget.pixelsPerMinute,
        _pillWidth(widget.theme),
      );
      final end = baseStart.add(
        Duration(minutes: _livePreviewDurationMinutes.round()),
      );
      return [
        _leftEdgeLabel(top: 0, time: baseStart),
        _leftEdgeLabel(top: liveHeight, time: end),
      ];
    }
    if (_isResizingTop) {
      // The END is anchored during a top-edge drag, so its badge must
      // NOT move — reported directly: "the blue badge with time, end
      // time is moving around while it should remain fixed."
      //
      // It sits at the block's ORIGINAL height, deliberately un-floored:
      // this whole Stack is positioned by a `top` that already shifted
      // down by the live start delta, and the height shrank by that same
      // delta, so the task's true end is always at `originalHeight -
      // liveStartDelta x ppm` in this local frame — which is exactly the
      // live height. Using the FLOORED live height instead (what this
      // did before) is what made the badge drift once the pill stopped
      // shrinking: the floor freezes while `top` keeps moving.
      final liveHeightUnfloored =
          _liveTopDurationMinutes * widget.pixelsPerMinute;
      final start = baseStart.add(
        Duration(minutes: _liveTopStartDelta.round()),
      );
      final end = baseStart.add(
        Duration(minutes: widget.task.durationMinutes!),
      );
      return [
        _leftEdgeLabel(top: 0, time: start),
        _leftEdgeLabel(top: liveHeightUnfloored, time: end),
      ];
    }
    // Move-drag: both edges shift by the same live offset, duration
    // unchanged.
    final start = _previewStartsAt;
    final end = start.add(Duration(minutes: widget.task.durationMinutes!));
    return [
      _leftEdgeLabel(top: 0, time: start),
      _leftEdgeLabel(top: height, time: end),
    ];
  }

  Widget _leftEdgeLabel({required double top, required DateTime time}) {
    return Positioned(
      top: top,
      left: -widget.left,
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: TaskEdgeTimeLabel(
          theme: widget.theme,
          time: TimeOfDay.fromDateTime(time),
          showLine: false,
        ),
      ),
    );
  }

  /// Split layout's own build — the pill and the time/title row as two
  /// horizontally-placed children of ONE vertically-animated box.
  ///
  /// The single outer `AnimatedPositioned` is what keeps the two halves
  /// locked together through a drag, a settle, and a cascade push: they
  /// share one `top` and one animation rather than two that could drift
  /// apart by a frame. Inside it, the pill sits at its overlap lane's own
  /// x while the text sits at the shared text column, which is the whole
  /// point — a lane-2 pill no longer drags its title rightwards with it.
  ///
  /// The box spans this row only (day-column left edge to right edge, one
  /// pill tall), never the full day: a taller box would cover the
  /// free-window blocks and placement-line targets beneath it and swallow
  /// their taps.
  Widget _buildSplit({
    required double top,
    required double columnOffset,
    required Widget pillContent,
    required bool devDurationVisible,
    required bool devTimeRangeVisible,
    required bool wiggleEnabled,
  }) {
    // Must also cover a label that collision-avoidance pushed BELOW the
    // pill's own bottom: the Stack is Clip.none so it would still paint,
    // but a child outside its parent's bounds is not hit-testable, and the
    // label carries the row's tap-to-edit target and its checkbox.
    final rowHeight = math.max(
      math.max(
        _pillHeight(widget.theme, widget.task, widget.pixelsPerMinute),
        widget.theme.spacingMinTapTarget,
      ),
      widget.labelOffset + widget.theme.spacingMinTapTarget,
    );

    return AnimatedPositioned(
      // Same timing rule as the combined layout's own — see its comment.
      // `_isResizingTop` joins `_isDragging` here (2026-09-12): a
      // top-edge resize MOVES this block's own `top` (see the
      // `topResizeOffset` that feeds it), so an animated duration made
      // the pill lag behind the finger and then visibly settle —
      // reported directly ("seem that pill is moving not only resizing
      // top... and 'settles' with animation"). Any live gesture tracks
      // 1:1; only non-gesture repositioning (a cascade push, a settle
      // after drop) still eases.
      duration: _isDragging || _isResizingTop || _suppressPositionAnimation
          ? Duration.zero
          : widget.theme.motionNormal,
      curve: Curves.easeOut,
      top: top,
      left: widget.left,
      right: widget.rightInset,
      height: rowHeight,
      // Unclipped so a lifted pill's shadow still spills over its
      // neighbours, exactly as it does in the combined layout.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Widened by the frosted wrapper's own lift padding — real bug,
          // reported directly ("right side is cut off, only part of pill
          // visible" while dragging). While lifted, TaskCapsuleBlock wraps
          // the pill in a Container with `EdgeInsets.all(spacingSm)` inside
          // a ClipRRect, and AnimatedScale grows it by _liftScale on top of
          // that — so a box sized to exactly one pill width clipped the
          // right edge off the moment a drag started. The extra room is
          // always reserved (not just while dragging) so the pill's own x
          // never shifts as the padding animates in.
          //
          // While LIFTED the box also has to fit the pill's own inline
          // name/time (see TaskCapsuleBlock.liftedTextInline) — requested
          // directly, "pane containing (bg blur one) should be extended to
          // that name". It runs to the row's right edge then, so the
          // frosted pane can grow around the text rather than clipping it.
          Positioned(
            top: 0,
            // The rail's own lane x, NOT shifted left to make room for the
            // lift padding. Real bug, reported twice as "perceived padding
            // right ... still too big": this used to sit at
            // `columnOffset - spacingSm`, relying on the Align below to
            // re-centre the rail back to `columnOffset`. That never
            // happened — `pillContent` is the whole capsule row (rail plus
            // its collapsed text column and checkbox), which fills the
            // box's width, so Align had nothing to centre and the rail
            // simply hugged the box's left edge. Every pill therefore
            // painted 8px left of its lane, leaving 4px of visible padding
            // inside the zone band on the left against 20px on the right.
            //
            // The lift padding is reserved by letting the box extend to
            // the RIGHT instead (see `width`), which needs no compensating
            // shift and so can't desync from where the rail actually
            // paints.
            left: columnOffset,
            width: _isDragging
                ? null
                : _pillWidth(widget.theme) + widget.theme.spacingSm * 2,
            right: _isDragging ? widget.textColumnRight : null,
            // topLeft, always: the pill's top edge IS the task's start
            // time, and its left edge IS its lane — neither may drift, so
            // there is nothing to centre on either axis. The extra
            // horizontal room simply sits to the right of the rail, unused
            // while resting and filled by the frosted pane while lifted.
            child: Align(alignment: Alignment.topLeft, child: pillContent),
          ),
          Positioned(
            // Level with the pill's icon (offset 0) unless the label above
            // would have collided — see `computeLabelTops`.
            top: widget.labelOffset,
            left: widget.textColumnLeft,
            right: widget.textColumnRight,
            child: TaskCapsuleTextRow(
              task: widget.task,
              timeColumnWidth: taskTimeColumnWidth(widget.theme),
              durationColumnWidth: taskDurationColumnWidth(widget.theme),
              dragPreviewStartsAt: _isDragging ? _previewStartsAt : null,
              onTap: _effectiveOnTap,
              onLongPress: _effectiveOnLongPress,
              onToggleComplete: widget.onToggleComplete,
              durationVisible: devDurationVisible,
              timeRangeVisible: devTimeRangeVisible,
              // List mode has no timeline axis at all, so the time is the
              // only place a task's schedule reads — requested directly
              // ("we always show the time in front of the task because we
              // don't show the timeline"). `compactText` is already this
              // widget's own "true in List mode" signal (see its doc
              // comment); Task view's split layout keeps its existing,
              // dev-toggle-driven behavior unchanged.
              alwaysShowTime: widget.compactText,
              // List mode's layout should match the cluster row's own
              // exactly — requested directly (see
              // `TaskCapsuleTextRow.compactInlineLayout`'s own doc
              // comment). Task view's split layout (compactText: false)
              // keeps its existing fixed-column behavior unchanged.
              compactInlineLayout: widget.compactText,
              showCompletionCheckbox: widget.showCompletionCheckbox,
              // Hidden while this task is the one being dragged: the
              // lifted pill carries its own name/time inside the frosted
              // pane (see `liftedTextInline`), so leaving this row visible
              // would show the same task's title twice mid-drag — once
              // travelling with the finger, once stranded at the shared
              // column. Also hidden for a resting cluster member, whose
              // text lives in the cluster's own row list.
              isFaded: _isDragging || (widget.contentHidden && !_isDragging),
            ),
          ),
          // Edge-time badges, ALWAYS pinned over the hour gutter on the
          // LEFT — reported directly, in stages: first move-only ("when
          // dragging (moving) can't see hour changeing. only when
          // resizing can see"), then resize too ("should always be
          // on left... during resize we should show times not only when
          // wiggling"), then wiggling's own resting pair corrected to
          // match ("when wiggling on left generally all cases on left
          // side" — previously at the pill's own top/bottom-right, not
          // the gutter), then move corrected to show both edges, not
          // just the start ("when moving also end should be shown...
          // atm only beginning start time"). Task view only (List mode
          // has no hour gutter for this to sit over). Live labels
          // ([_liveEdgeTimeLabels]) take over from the resting ones
          // ([_edgeTimeLabels]) during an actual drag/resize, since the
          // task's own `scheduledAt`/`durationMinutes` are stale until
          // the gesture commits.
          if (!widget.compactText) ...[
            if (_isDragging || _isResizing || _isResizingTop)
              ..._liveEdgeTimeLabels(
                height: _pillHeight(
                  widget.theme,
                  widget.task,
                  widget.pixelsPerMinute,
                ),
              )
            else if (wiggleEnabled)
              ..._edgeTimeLabels(
                height: _pillHeight(
                  widget.theme,
                  widget.task,
                  widget.pixelsPerMinute,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Leaves the settling state once the eased move has had time to play.
  /// Kept as its own step (rather than clearing `_isSettling` alongside
  /// `_dragOffset`) because the block must keep animating THROUGH the
  /// frame where `baseTop` updates and the offset resets — those two
  /// cancel out positionally, but only if the widget is still in
  /// animated mode when they land.
  Future<void> _endSettle() async {
    await Future<void>.delayed(widget.theme.motionNormal);
    if (!mounted) return;
    setState(() => _isSettling = false);
    // Release the parent's top-of-Stack pin only now, once nothing is
    // still animating — reordering mid-animation is what caused the
    // reported jump.
    widget.onSettled();
  }
}

/// A vertical gray line connecting every consecutive pair of tasks in the
/// day — requested directly, matching a reference design where the
/// timeline reads as one continuous thread rather than disconnected
/// blocks. Runs from the bottom of one task's badge to the top of the
/// next, regardless of the gap between them.
///
/// When both tasks in a pair share the same overlap-layout column, the
/// line is a plain straight vertical segment at that column's x. When
/// they're in different columns (an overlap-caused side-by-side case), a
/// diagonal line would look accidental rather than deliberate — since the
/// reference never shows overlapping tasks, this draws the segment at the
/// *later* task's column instead, which is what the eye follows down into
/// next regardless.
class _TimelineConnectors extends StatelessWidget {
  const _TimelineConnectors({
    required this.tasks,
    required this.theme,
    required this.rangeStart,
    required this.pixelsPerMinute,
    required this.hourGutterWidth,
  });

  final List<Task> tasks;
  final AmbleTheme theme;
  final DateTime rangeStart;
  final double pixelsPerMinute;
  final double hourGutterWidth;

  double _minutesSinceStart(DateTime scheduledAt) =>
      scheduledAt.difference(rangeStart).inMinutes.toDouble();

  @override
  Widget build(BuildContext context) {
    if (tasks.length < 2) return const SizedBox.shrink();

    // `tasks` here is genuinely `List<Task>` (connectors are a task-only
    // thread, unrelated to event stacking) — `layoutOverlappingTasks` is
    // now generic over `ScheduledBlock`, but every slot it returns for a
    // Task-only input is guaranteed to carry a non-null `.task`.
    final slots = layoutOverlappingTasks(tasks);
    final slotByTaskId = {for (final slot in slots) slot.task!.id: slot};
    final sorted = [...tasks]
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    return Stack(
      children: [
        for (var i = 0; i < sorted.length - 1; i++)
          ?_connector(sorted[i], sorted[i + 1], slotByTaskId),
      ],
    );
  }

  Widget? _connector(
    Task from,
    Task to,
    Map<String, TaskLayoutSlot> slotByTaskId,
  ) {
    final fromSlot = slotByTaskId[from.id];
    final toSlot = slotByTaskId[to.id];
    if (fromSlot == null || toSlot == null) return null;

    final fromBottom =
        _minutesSinceStart(from.scheduledAt!) * pixelsPerMinute +
        _pillHeight(theme, from, pixelsPerMinute);
    final toTop = _minutesSinceStart(to.scheduledAt!) * pixelsPerMinute;
    final height = toTop - fromBottom;
    // Overlapping tasks (a task starting before the previous one ends) can
    // put toTop above fromBottom — nothing to connect there, the pills
    // themselves already show the overlap.
    if (height <= 0) return null;

    final column = toSlot.column;
    final left =
        hourGutterWidth +
        column * (_pillWidth(theme) + _columnGap(theme)) +
        _pillWidth(theme) / 2 -
        theme.borderWidthConnector / 2;

    return Positioned(
      key: ValueKey('connector-${from.id}-${to.id}'),
      top: fromBottom,
      left: left,
      width: theme.borderWidthConnector,
      height: height,
      child: ColoredBox(color: theme.colorBorder),
    );
  }
}

class _EmptyDayState extends StatelessWidget {
  const _EmptyDayState({required this.theme});

  final AmbleTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.self_improvement_rounded,
              size: theme.spacingXl * 1.5,
              color: theme.colorTextSecondary,
            ),
            SizedBox(height: theme.spacingMd),
            Text(
              'Nothing scheduled today',
              style: theme.textBody.copyWith(color: theme.colorTextSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
