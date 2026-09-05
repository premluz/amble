import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/external_calendar_event.dart';
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
import '../../shared/services/overlap_checker.dart';
import '../../shared/services/overlap_cluster.dart';
import '../../shared/services/zone_containment.dart';
import '../tracked_behavior/behavior_outcome_prompt.dart';
import '../task_detail/task_detail_sheet.dart';
import 'collapsed_stack_layout.dart';
import 'current_time_indicator.dart';
import 'day_strip.dart';
import 'external_event_block.dart';
import 'free_window_block.dart';
import 'overlap_cluster_block.dart';
import 'place_task_line.dart';
import 'recently_saved_task_provider.dart';
import 'selected_date_provider.dart';
import 'viewed_time_provider.dart';
import 'task_boundary_markers.dart';
import 'task_capsule_block.dart';
import 'task_overlap_layout.dart';
import 'tasks_for_selected_day_provider.dart';
import 'zone_background_block.dart';
import 'zone_day_timeline.dart';

// The visible scroll range used to be a fixed calendar-day window
// (0-24h, previously 6-22h — see docs/ERROR_LOG.md for why that was
// widened). Now computed dynamically per day from the tasks actually
// scheduled, in _DayTimelineState._visibleRange — requested directly, so
// the day only scrolls through the range it actually has content for.
const _hourGutterWidth = 56.0;

/// Horizontal room reserved at the RIGHT edge of the day for the rotated
/// zone-name labels (see [ZoneNameLabel]) — the mirror of
/// [_hourGutterWidth] on the left. Task rows stop short of it so a title
/// or checkbox can never render underneath a zone name. Sized to one line
/// of `textCaption`, which is all the rotated text needs.
double _zoneLabelGutterWidth(AmbleTheme theme) => theme.spacingLg;

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

/// [TaskCapsuleBlock]'s pill height for a given task, mirrored here for the
/// same reason as [_pillWidth] — needed to find where one task's pill ends
/// so the connector line (see [_TimelineConnectors]) can start there.
double _pillHeight(AmbleTheme theme, Task task, double pixelsPerMinute) =>
    math.max(task.durationMinutes! * pixelsPerMinute, _pillWidth(theme));

/// The Timeline day view — hour markers, tasks for the selected day
/// positioned by [Task.scheduledAt]/[Task.durationMinutes], a live
/// current-time indicator, and simple day navigation. Wired to
/// [tasksForSelectedDayProvider] (real provider data, Phase 1 + this
/// session), not seeded data — see timeline_capsule_preview.dart for the
/// separate dev-scaffold preview.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

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
    final zones = FeatureFlags.zoneEnabled
        ? ref.watch(zoneListProvider)
        : const <Zone>[];
    final categoryById = {
      for (final category in ref.watch(categoryListProvider))
        category.id: category,
    };
    // Only surfaced (and only ever true) when the Zone feature flag is on
    // — see ZoneViewEnabledSetting and the Settings screen's own gating.
    // With the flag off, zoneViewEnabled always reads false here, so the
    // Task view below is the only path a flag-off build can ever take.
    //
    // The `devZoneViewInCycle` term must match `day_strip.dart`'s own
    // gate exactly: that toggle can be switched off while the PERSISTED
    // `zoneViewEnabledSetting` is still true, and without this the strip
    // would cycle Task<->List only while this screen kept rendering the
    // Zone view it can no longer reach. Debug-only, same reasoning as
    // there — `isDevConfigAvailable` is a `kDebugMode` re-export, so this
    // collapses to the flag alone in release.
    final zoneViewEnabled =
        FeatureFlags.zoneEnabled &&
        (!isDevConfigAvailable || ref.watch(devZoneViewInCycleProvider)) &&
        ref.watch(zoneViewEnabledSettingProvider);
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

    return Container(
      color: theme.colorSurfaceTimeline,
      child: SafeArea(
        // The day strip owns the bottom edge itself (its own SafeArea
        // handling — see DayStrip), so this outer SafeArea only needs to
        // guard the top/sides.
        bottom: false,
        child: Column(
          children: [
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
              child: AnimatedSwitcher(
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
                    begin: isEntering ? const Offset(0.15, 0) : Offset.zero,
                    end: isEntering ? Offset.zero : const Offset(-0.15, 0),
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
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
                layoutBuilder: (currentChild, previousChildren) => Stack(
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
                            externalEvents: externalEvents,
                            theme: theme,
                            categoryById: categoryById,
                            selectedDate: selectedDate,
                            // Dev-only capsule display toggles (Settings'
                            // "Developer" section) — read once here, same
                            // as showHourLabels/disableClustering, and
                            // threaded down as plain fields since
                            // ZoneDayTimeline isn't Riverpod-aware.
                            // Requested directly: these already applied to
                            // the Task view's own capsules but not to Zone
                            // view's outer-axis ones.
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
                            // Independently configurable from the Task
                            // view's own scale below — requested directly
                            // (see DevZoneViewPixelsPerMinute's own doc
                            // comment for why the 2x default was needed).
                            pixelsPerMinute: ref.watch(
                              devZoneViewPixelsPerMinuteProvider,
                            ),
                            // Opens Edit directly, skipping the action
                            // sheet (Edit/Duplicate/Remove) — requested
                            // directly. The sheet stays in the codebase,
                            // unused for now, in case it's wanted again.
                            onTaskTap: (task) =>
                                showTaskDetailSheet(context, task: task),
                            onToggleComplete: (task) =>
                                _completeTask(context, ref, task),
                            onReassign: (task, zoneId, newScheduledAt) => ref
                                .read(taskListProvider.notifier)
                                .rescheduleTaskWithZone(
                                  task,
                                  newScheduledAt,
                                  zoneId,
                                ),
                            // Shared with the Task view below via
                            // viewed_time_provider.dart — see its own doc
                            // comment. Lets switching Zone<->Task resume the
                            // same scroll position instead of always
                            // re-centering on "now".
                            //
                            // `read`, NOT `watch`, deliberately: this is a
                            // START position, consumed once when the view
                            // mounts or a switch happens, not live state to
                            // track. Watching it created a feedback loop —
                            // every scroll wrote the provider, which rebuilt
                            // this whole screen, which pushed a new
                            // `readViewedMinutes` down and re-ran
                            // `didUpdateWidget` mid-scroll. That loop is what
                            // caused the reported scroll-position reset, the
                            // "flash" on switching to Zone view, and the
                            // capsules animating in from the top.
                            readViewedMinutes: () =>
                                ref.read(viewedTimeProvider),
                            onViewedMinutesChanged: (minutes) => ref
                                .read(viewedTimeProvider.notifier)
                                .set(minutes),
                          ),
                          if (tasks.isEmpty && zones.isEmpty)
                            IgnorePointer(child: _EmptyDayState(theme: theme)),
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
                            showHourLabels: ref.watch(
                              showHourLabelsSettingProvider,
                            ),
                            showTimelineConnectors: ref.watch(
                              showTimelineConnectorsSettingProvider,
                            ),
                            // Opens Edit directly, skipping the action sheet
                            // (Edit/Duplicate/Remove) — requested directly.
                            // The sheet stays in the codebase, unused for
                            // now, in case it's wanted again.
                            onTaskTap: (task) =>
                                showTaskDetailSheet(context, task: task),
                            onToggleComplete: (task) =>
                                _completeTask(context, ref, task),
                            onReschedule: (task, newScheduledAt) => taskNotifier
                                .rescheduleTask(task, newScheduledAt),
                            onCreateAt: (startAt) => showTaskDetailSheet(
                              context,
                              initialScheduledAt: startAt,
                              initialTimeOfDay: TimeOfDay.fromDateTime(startAt),
                            ),
                            recentlySaved: ref.watch(recentlySavedTaskProvider),
                            onSavedTaskConsumed: () => ref
                                .read(recentlySavedTaskProvider.notifier)
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
                          ),
                          // IgnorePointer so the message never blocks a tap
                          // on the timeline underneath (creating a task by
                          // tapping a free window still works through it).
                          if (tasks.isEmpty)
                            IgnorePointer(child: _EmptyDayState(theme: theme)),
                        ],
                      ),
              ),
            ),
            DayStrip(
              onCreatePressed: () => showTaskDetailSheet(
                context,
                initialScheduledAt: DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  DateTime.now().hour,
                  DateTime.now().minute,
                ),
              ),
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
    required this.recentlySaved,
    required this.onSavedTaskConsumed,
    required this.disableClustering,
    this.pixelsPerMinute = 1.5,
    this.showFreeWindowPrompt = true,
    this.devDurationVisible = true,
    this.devTextLayout = TimelineTaskTextLayout.stacked,
    this.showCompletionCheckbox = true,
    this.readViewedMinutes,
    this.onViewedMinutesChanged,
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
  /// used by a free window's block (start of that gap) and, coming next,
  /// the hold-and-drag placement line (wherever it's released).
  final ValueChanged<DateTime> onCreateAt;

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
    // The task actively being dragged is excluded from the tasks clusters
    // are computed FROM: per direct requirement, a dragged task renders
    // completely normally — its own full capsule — regardless of what's
    // underneath it, and the tasks it would otherwise cluster with must
    // likewise stay as their own ordinary capsules while it's away, not
    // silently form a smaller cluster among themselves mid-drag.
    final clusters = widget.disableClustering
        ? const <OverlapCluster>[]
        : detectOverlapClusters(
            _draggingTaskId == null
                ? tasks
                : tasks.where((task) => task.id != _draggingTaskId).toList(),
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
        : detectOverlapClusters(tasks);
    final slots = _dragLastOrder(
      _withClusterLanes(layoutOverlappingTasks(tasks), clusters),
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
      layoutOverlappingTasks(tasks),
      restingClusters,
    );
    // In Timeline mode, task tops are real elapsed-time math and external
    // events already position independently via the same math — no shared
    // cursor needed, since real time-to-pixel positions can't collide by
    // construction the way an arbitrary stacking cursor can. Collapsed
    // (List) mode is the one case needing ONE shared cursor across both —
    // see _collapsedTops' own doc comment for why.
    final Map<String, double> blockTops;
    final Map<String, double> externalEventTops;
    if (widget.showHourLabels) {
      blockTops = _blockTops(slots, rangeStart, theme);
      externalEventTops = const {};
    } else {
      final collapsed = _collapsedTops(slots, restingClusters, theme);
      blockTops = collapsed.taskTops;
      externalEventTops = collapsed.externalEventTops;
    }
    // List mode only — Task view's zone bands are positioned by
    // `ZoneBackgroundBlock`'s own real-time math directly from
    // `widget.zones`, with no equivalent precomputed geometry needed here.
    final collapsedZoneBandsList = widget.showHourLabels
        ? const <CollapsedZoneBand>[]
        : _collapsedZoneBands(tasks, blockTops, externalEventTops, theme);

    // Task view: each task's NAME wants to sit level with its own pill's
    // icon (i.e. at the pill's own top), and only gets pushed down when it
    // would collide with the label above it — requested directly. Computed
    // once here for the whole day so every label agrees, the same way the
    // shared text column's x is.
    final labelTops = widget.showHourLabels
        ? computeLabelTops(
            anchors: [
              for (final slot in slots)
                LabelAnchor(
                  id: slot.task.id,
                  preferredTop: blockTops[slot.task.id]!,
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
            slots.fold<double>(
              0,
              (tallest, slot) => math.max(
                tallest,
                blockTops[slot.task.id]! +
                    _collapsedBlockHeight(slot.task, theme),
              ),
            ),
            math.max(
              widget.externalEvents.fold<double>(
                0,
                (tallest, event) => math.max(
                  tallest,
                  (externalEventTops[event.id] ?? 0) +
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
    final hourGutterWidth = widget.showHourLabels ? _hourGutterWidth : 0.0;

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

        return SingleChildScrollView(
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
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacingScreenPadding,
            vertical: theme.spacingLg,
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
                  ),
                if (widget.showHourLabels)
                  TaskBoundaryMarkers(
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    pixelsPerMinute: widget.pixelsPerMinute,
                    hideLabelNear: _now,
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
                    ZoneBackgroundBlock(
                      theme: theme,
                      zone: zone,
                      day: widget.selectedDate,
                      rangeStart: rangeStart,
                      pixelsPerMinute: widget.pixelsPerMinute,
                      left: hourGutterWidth,
                      // Hugs the PILL COLUMN rather than spanning the whole
                      // row — the time and task-name columns sit outside
                      // the zone band, on the plain page. Sized to THIS
                      // zone's own occupied lanes so the space right of
                      // its pills matches the space left of them; see
                      // `_zoneBackgroundWidth` for why that beat the
                      // earlier uniform-width rule where the two clashed.
                      width: _zoneBackgroundWidth(ghostSlots, theme),
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
                // Read-only external calendar events (Feature 1) — same
                // time-positioned-background-layer treatment as Zone blocks
                // just above, but NOT IgnorePointer'd (tapping one shows a
                // read-only info sheet — see ExternalEventBlock). Rendered
                // after Zone blocks so an external event visually sits on
                // top of a zone background if their times happen to
                // overlap, and before task capsules/connectors below, same
                // "decorative background, tasks always paint on top" order
                // Zone blocks already established. Deliberately excluded
                // from overlap-cluster detection — see CONSTITUTION.md's
                // "Calendar" section for the reasoning — so this list is
                // never touched by clustering and always renders in full.
                //
                // Shown in BOTH Timeline and List (collapsed) mode —
                // requested directly, alongside the same coverage in Zone
                // view. Collapsed mode uses `externalEventTops`' own
                // stacking-cursor position (see `_externalEventTops`)
                // instead of real time-to-pixel math, matching how task
                // rows already switch positioning schemes between modes.
                for (final event in widget.externalEvents)
                  ExternalEventBlock(
                    theme: theme,
                    event: event,
                    rangeStart: rangeStart,
                    pixelsPerMinute: widget.showHourLabels
                        ? widget.pixelsPerMinute
                        : _collapsedPixelsPerMinute(theme),
                    left: hourGutterWidth,
                    width:
                        MediaQuery.sizeOf(context).width -
                        hourGutterWidth -
                        theme.spacingScreenPadding * 2,
                    collapsedTop: widget.showHourLabels
                        ? null
                        : externalEventTops[event.id],
                    collapsedHeight: widget.showHourLabels
                        ? null
                        : _collapsedExternalEventHeight(event, theme),
                    // Inline in List mode always, and in Task view whenever
                    // the dev layout toggle says so — matching the capsule
                    // and cluster rows beside it. Reported directly:
                    // "important tasks" stayed 2-line in Task view.
                    compactText:
                        !widget.showHourLabels ||
                        widget.devTextLayout == TimelineTaskTextLayout.inline,
                  ),
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
                    minPillMinutes: _pillWidth(theme) / widget.pixelsPerMinute,
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
                          window.duration.inMinutes * widget.pixelsPerMinute -
                          theme.spacingSm * 2,
                      // Aligned with task NAMES, not the icon-pill column —
                      // corrected directly: "left indent[should be] of size
                      // of the pill of tasks + padding/gap between pill and
                      // description... the window container is [a]ligned up
                      // with names of tasks." pillWidth + spacingSm mirrors
                      // exactly the SizedBox TaskCapsuleBlock puts between
                      // its icon pill and its title/time column.
                      left:
                          hourGutterWidth + _pillWidth(theme) + theme.spacingSm,
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
                  if (_draggingTaskId == slot.task.id)
                    Positioned(
                      // Keyed so its insertion/removal can't disturb element
                      // matching for the keyed sibling block right after it.
                      // Without this, releasing a drag (which removes the
                      // ghost) could make Flutter re-create the real block's
                      // element instead of updating it, resetting its
                      // AnimatedPositioned to animate from the GHOST's
                      // position — reported as the block jumping to a higher
                      // spot and then easing back down to the actual drop.
                      key: ValueKey('ghost-${slot.task.id}'),
                      top: blockTops[slot.task.id]!,
                      left:
                          hourGutterWidth +
                          _ghostSlotFor(ghostSlots, slot.task.id).column *
                              (_pillWidth(theme) + _columnGap(theme)),
                      right: 0,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.2,
                          child: TaskCapsuleBlock(
                            task: slot.task,
                            category: widget.categoryById[slot.task.categoryId],
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
                            bottomTrim: _zoneTaskBottomTrim(slot.task),
                            maxPillHeight: _maxPillHeight(
                              slot.task,
                              ghostSlots,
                              blockTops,
                            ),
                            maxTextWidth:
                                _ghostSlotFor(ghostSlots, slot.task.id).column <
                                    _ghostSlotFor(
                                          ghostSlots,
                                          slot.task.id,
                                        ).columnCount -
                                        1
                                ? _pillWidth(theme)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  _DraggableTaskBlock(
                    key: ValueKey(slot.task.id),
                    task: slot.task,
                    theme: theme,
                    baseTop: blockTops[slot.task.id]!,
                    left: hourGutterWidth,
                    slot: slot,
                    pixelsPerMinute: pixelsPerMinute,
                    // Only in List mode does a clustered task surrender its
                    // text to the cluster's own row list. In Task view
                    // every task keeps its own label (aligned to its pill's
                    // icon — see `labelTops`), so there is nothing to
                    // suppress and no duplicate to avoid.
                    contentHidden:
                        !widget.showHourLabels &&
                        clusteredIds.contains(slot.task.id),
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
                        (labelTops[slot.task.id] ?? blockTops[slot.task.id]!) -
                        blockTops[slot.task.id]!,
                    textColumnRight: widget.zones.isEmpty
                        ? 0
                        : _zoneLabelGutterWidth(theme),
                    bottomTrim: _zoneTaskBottomTrim(slot.task),
                    maxPillHeight: _maxPillHeight(slot.task, slots, blockTops),
                    // Only the block for the task the modal just CREATED
                    // fades in. A duration change animates via the pill's own
                    // AnimatedContainer instead (see TaskCapsuleBlock) — that
                    // block is already on screen, so fading it would read as
                    // it disappearing and coming back rather than growing.
                    fadeInOnFirstBuild:
                        widget.recentlySaved?.taskId == slot.task.id &&
                        widget.recentlySaved?.change == SavedTaskChange.created,
                    growFromMinutes:
                        widget.recentlySaved?.taskId == slot.task.id &&
                            widget.recentlySaved?.change ==
                                SavedTaskChange.durationChanged
                        ? widget.recentlySaved?.previousDurationMinutes
                        : null,
                    onTap: () => widget.onTaskTap(slot.task),
                    onToggleComplete: () => widget.onToggleComplete(slot.task),
                    onReschedule: (newScheduledAt) =>
                        widget.onReschedule(slot.task, newScheduledAt),
                    onDraggingChanged: (isDragging) {
                      setState(() {
                        _draggingTaskId = isDragging ? slot.task.id : null;
                        // Ordering starts with the drag and is only released
                        // by onSettled below, deliberately outliving the
                        // ghost.
                        if (isDragging) _settlingTaskId = slot.task.id;
                      });
                    },
                    onSettled: () {
                      // Ignore a stale settle: either a different task now
                      // holds the pin, or this same task has been picked up
                      // again before its previous drop finished animating.
                      if (_settlingTaskId != slot.task.id) return;
                      if (_draggingTaskId != null) return;
                      setState(() => _settlingTaskId = null);
                    },
                  ),
                ],
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
                      top: blockTops[cluster.tasks.first.id]!,
                      // The SHARED text column, not this cluster's own member
                      // count — corrected directly ("all text ... always lined
                      // up"). Sizing it per cluster meant a 4-task cluster's
                      // rows started further right than a 2-task one's, and
                      // than every unclustered task's name.
                      left:
                          hourGutterWidth + _textColumnLeft(theme, ghostSlots),
                      // Same zone-label gutter the ordinary task rows leave
                      // — see _zoneLabelGutterWidth.
                      right: widget.zones.isEmpty
                          ? 0
                          : _zoneLabelGutterWidth(theme),
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
                          textLayout: widget.devTextLayout,
                          showCompletionCheckbox: widget.showCompletionCheckbox,
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
  /// Timeline mode maps real elapsed time to pixels (external events
  /// position independently via that same real math — see the render
  /// site — so no shared cursor is needed there). Collapsed (List) mode
  /// delegates to [_collapsedTops]' unified stacking cursor, which also
  /// positions external events in the SAME pass — see its own doc comment
  /// for why that has to be one merged walk, not two independent ones.
  Map<String, double> _blockTops(
    List<TaskLayoutSlot> slots,
    DateTime rangeStart,
    AmbleTheme theme,
  ) {
    if (widget.showHourLabels) {
      return {
        for (final slot in slots)
          slot.task.id:
              _minutesSinceStart(rangeStart, slot.task.scheduledAt!) *
                  widget.pixelsPerMinute +
              _zoneTaskTopInset(slot.task),
      };
    }
    // Unreachable in practice — this whole method is only ever called from
    // inside an outer `if (widget.showHourLabels)` at its one call site, so
    // this branch can never actually run. `clusters` isn't in scope here;
    // an empty list keeps this compiling without expanding this fix's
    // scope to a pre-existing dead branch.
    return _collapsedTops(slots, const [], theme).taskTops;
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
  double? _maxPillHeight(
    Task task,
    List<TaskLayoutSlot> slots,
    Map<String, double> blockTops,
  ) {
    TaskLayoutSlot? ownSlot;
    for (final slot in slots) {
      if (slot.task.id == task.id) {
        ownSlot = slot;
        break;
      }
    }
    final ownTop = blockTops[task.id];
    if (ownSlot == null || ownTop == null) return null;

    TaskLayoutSlot? next;
    double? nextTop;
    for (final slot in slots) {
      if (slot.column != ownSlot.column || slot.task.id == task.id) continue;
      final top = blockTops[slot.task.id];
      if (top == null || top <= ownTop) continue;
      if (nextTop == null || top < nextTop) {
        next = slot;
        nextTop = top;
      }
    }
    if (next == null || nextTop == null) return null;

    return nextTop - ownTop - _minPillGap;
  }

  /// Collapsed (List) mode's ONE unified stacking pass over BOTH task rows
  /// and external-calendar-event rows, keyed apart in two returned maps but
  /// walked with a single shared cursor — real bug, reported directly:
  /// "tasks on list view should not overlap (the app tasks with the
  /// imported tasks should be one by one." A prior version computed task
  /// tops via [_blockTops] FIRST, entirely unaware external events existed,
  /// then positioned external events in a second pass that only read those
  /// already-fixed task tops — so an external event landing chronologically
  /// BETWEEN two tasks could never push the later task's row down to make
  /// room; it just overlapped it. Merging both sequences into one cursor
  /// walk (ordered by each row's own start time) is what actually
  /// guarantees "one by one": whichever row comes next in time is the one
  /// that advances the cursor, task or external, every time.
  ({Map<String, double> taskTops, Map<String, double> externalEventTops})
  _collapsedTops(
    List<TaskLayoutSlot> slots,
    List<OverlapCluster> clusters,
    AmbleTheme theme,
  ) {
    // A cluster's own row renders via OverlapClusterBlock — a vertically
    // stacked flat list of every member's own title+time line, not the
    // ordinary combined pill+text row — so its real height is nothing
    // like a single task's badge-floored pill height. Keyed by cluster
    // SIZE (member count), not identity: every member of the same cluster
    // needs the same height value once looked up by task id below.
    final clusterSizeByTaskId = {
      for (final cluster in clusters)
        for (final task in cluster.tasks) task.id: cluster.tasks.length,
    };

    // Task rows: one entry per overlap GROUP (column 0 starts a new group —
    // see layoutOverlappingTasks), carrying the group's start time and the
    // tallest member's height. The actual merge (this function's whole
    // point) lives in the pure, unit-tested computeCollapsedStackTops.
    final taskRows = <CollapsedStackRow>[];
    for (final slot in slots) {
      final height = clusterSizeByTaskId[slot.task.id] != null
          ? _collapsedClusterHeight(clusterSizeByTaskId[slot.task.id]!, theme)
          : _collapsedBlockHeight(slot.task, theme);
      if (slot.column == 0 || taskRows.isEmpty) {
        taskRows.add(
          CollapsedStackRow(
            ids: [slot.task.id],
            start: slot.task.scheduledAt!,
            height: height,
          ),
        );
      } else {
        final last = taskRows.removeLast();
        taskRows.add(
          CollapsedStackRow(
            ids: [...last.ids, slot.task.id],
            start: last.start,
            height: math.max(last.height, height),
          ),
        );
      }
    }

    final eventRows = [
      for (final event in widget.externalEvents)
        CollapsedStackRow(
          ids: [event.id],
          start: event.start,
          height: _collapsedExternalEventHeight(event, theme),
        ),
    ];

    final allTops = computeCollapsedStackTops(
      taskRows: taskRows,
      externalEventRows: eventRows,
      gap: _collapsedBlockGap(theme),
    );

    final taskIds = {for (final row in taskRows) ...row.ids};
    return (
      taskTops: {
        for (final entry in allTops.entries)
          if (taskIds.contains(entry.key)) entry.key: entry.value,
      },
      externalEventTops: {
        for (final entry in allTops.entries)
          if (!taskIds.contains(entry.key)) entry.key: entry.value,
      },
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
  List<CollapsedZoneBand> _collapsedZoneBands(
    List<Task> tasks,
    Map<String, double> taskTops,
    Map<String, double> externalEventTops,
    AmbleTheme theme,
  ) {
    if (widget.zones.isEmpty) return const [];

    final result = resolveZoneContainment(
      tasks: tasks,
      zones: widget.zones,
      day: widget.selectedDate,
      externalEvents: widget.externalEvents,
    );

    return collapsedZoneBands(
      containments: result.containments,
      day: widget.selectedDate,
      taskTops: taskTops,
      taskHeights: {
        for (final task in tasks) task.id: _collapsedBlockHeight(task, theme),
      },
      externalEventTops: externalEventTops,
      externalEventHeights: {
        for (final event in widget.externalEvents)
          event.id: _collapsedExternalEventHeight(event, theme),
      },
      rowTopsByStartTime: [
        for (final task in tasks)
          if (taskTops[task.id] != null)
            MapEntry(task.scheduledAt!, taskTops[task.id]!),
        for (final event in widget.externalEvents)
          if (externalEventTops[event.id] != null)
            MapEntry(event.start, externalEventTops[event.id]!),
      ],
      rowExtents: [
        for (final task in tasks)
          if (taskTops[task.id] != null)
            (
              taskTops[task.id]!,
              taskTops[task.id]! + _collapsedBlockHeight(task, theme),
            ),
        for (final event in widget.externalEvents)
          if (externalEventTops[event.id] != null)
            (
              externalEventTops[event.id]!,
              externalEventTops[event.id]! +
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

  /// [ExternalCalendarEvent] counterpart to [_collapsedBlockHeight] — same
  /// duration-proportional floor, plus [externalEventBlockMinHeight]'s own
  /// two-lines-of-text floor (real bug, reported directly: "but same
  /// line" — the stacking cursor previously only reserved
  /// `_pillWidth(theme)` worth of space, which could be shorter than what
  /// the block's own two text lines actually need, so the NEXT row landed
  /// close enough to visually compress this block's title under its time
  /// line). Both callers of this value — the cursor's own advance here,
  /// and [ExternalEventBlock.collapsedHeight] passed to the widget — must
  /// agree, or the cursor reserves less space than the widget renders.
  double _collapsedExternalEventHeight(
    ExternalCalendarEvent event,
    AmbleTheme theme,
  ) => math.max(
    event.end.difference(event.start).inMinutes *
        _collapsedPixelsPerMinute(theme),
    math.max(
      _pillWidth(theme),
      externalEventBlockMinHeight(theme, compactText: true),
    ),
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
      (slot) => slot.task.id == taskId,
      orElse: () => ghostSlots.first,
    );
  }

  List<TaskLayoutSlot> _withClusterLanes(
    List<TaskLayoutSlot> slots,
    List<OverlapCluster> clusters,
  ) {
    if (clusters.isEmpty) return slots;

    final laneByTaskId = <String, int>{};
    final countByTaskId = <String, int>{};
    for (final cluster in clusters) {
      for (final (index, task) in cluster.tasks.indexed) {
        laneByTaskId[task.id] = index;
        countByTaskId[task.id] = cluster.tasks.length;
      }
    }

    return [
      for (final slot in slots)
        if (laneByTaskId.containsKey(slot.task.id))
          TaskLayoutSlot(
            task: slot.task,
            column: laneByTaskId[slot.task.id]!,
            columnCount: countByTaskId[slot.task.id]!,
          )
        else
          slot,
    ];
  }

  List<TaskLayoutSlot> _dragLastOrder(List<TaskLayoutSlot> slots) {
    final draggingId = _settlingTaskId;
    if (draggingId == null) return slots;

    final index = slots.indexWhere((slot) => slot.task.id == draggingId);
    if (index == -1) return slots;

    // Copy first — `slots` is the caller's list and must not be mutated.
    final reordered = [...slots];
    reordered.add(reordered.removeAt(index));
    return reordered;
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
  });

  final Task task;
  final AmbleTheme theme;
  final double baseTop;
  final double left;

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
  /// stops — the zone-name label gutter (see [_zoneLabelGutterWidth]), so
  /// a title or checkbox never renders under a rotated zone name.
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

  /// The start time this drag would commit to if released right now —
  /// derived from the same snapped offset the drop itself uses, so the
  /// time shown mid-drag can never disagree with the time actually saved.
  DateTime get _previewStartsAt =>
      widget.task.scheduledAt!.add(Duration(minutes: _snappedMinutesDelta));

  int get _snappedMinutesDelta =>
      (_dragOffset / widget.pixelsPerMinute / _snapMinutes).round() *
      _snapMinutes;

  @override
  Widget build(BuildContext context) {
    // While dragging, follow the finger exactly (unsnapped) — confirmed
    // via AskUserQuestion over the alternative of snapping every 5 minutes
    // mid-drag. Once released, switch to the SNAPPED offset so the block
    // animates into the slot it actually commits to, closing the gap that
    // previously showed as a flicker.
    final effectiveOffset = _isSettling
        ? _snappedMinutesDelta * widget.pixelsPerMinute
        : _dragOffset;
    final top = widget.baseTop + effectiveOffset;
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
    final capsule = TweenAnimationBuilder<double>(
      // Only `end` matters on rebuild — TweenAnimationBuilder animates
      // from wherever it currently is toward the new end value, so
      // flipping _entranceProgress 0 -> 1 is what plays the sequence.
      tween: Tween(begin: 0, end: _entranceProgress),
      duration: widget.theme.motionSlow,
      curve: Curves.easeOut,
      builder: (context, entranceProgress, child) => AnimatedScale(
        scale: _isDragging ? _liftScale : 1.0,
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
          onTap: widget.onTap,
          onToggleComplete: widget.onToggleComplete,
          dragPreviewStartsAt: _isDragging ? _previewStartsAt : null,
          durationMinutesOverride: _heldDurationMinutes,
          entranceProgress: entranceProgress,
          isLifted: _isDragging,
          // A dragged cluster member always shows full content — only
          // the resting state stays blanked.
          contentHidden: widget.contentHidden && !_isDragging,
          textLayout: devTextLayout,
          iconsVisible: devIconsVisible,
          durationVisible: devDurationVisible,
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
              : (_) {
                  setState(() => _isDragging = true);
                  widget.onDraggingChanged(true);
                },
          onDragUpdate: !widget.isDraggable
              ? null
              : (details) {
                  setState(() => _dragOffset += details.delta.dy);
                },
          onDragEnd: !widget.isDraggable
              ? null
              : (_) async {
                  final minutesDelta = _snappedMinutesDelta;
                  final newScheduledAt = _previewStartsAt;

                  // Drop the lift (shadow/scale) immediately — that's the
                  // tactile "released" feedback and shouldn't wait on I/O. This
                  // also clears the ghost (via onDraggingChanged), since the
                  // parent only shows it while this task's id is the dragging
                  // one. `_isSettling` turns on in the same frame so the block
                  // eases from the raw finger position into its snapped slot
                  // rather than jumping there.
                  setState(() {
                    _isDragging = false;
                    _isSettling = true;
                  });
                  widget.onDraggingChanged(false);

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
        ),
      ),
    );

    if (widget.splitLayout) {
      return _buildSplit(
        top: top,
        columnOffset: columnOffset,
        pillContent: capsule,
        devDurationVisible: devDurationVisible,
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
      duration: _isDragging || _suppressPositionAnimation
          ? Duration.zero
          : widget.theme.motionNormal,
      curve: Curves.easeOut,
      top: top,
      left: widget.left + columnOffset,
      right: 0,
      child: capsule,
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
      duration: _isDragging || _suppressPositionAnimation
          ? Duration.zero
          : widget.theme.motionNormal,
      curve: Curves.easeOut,
      top: top,
      left: widget.left,
      right: 0,
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
              onTap: widget.onTap,
              onToggleComplete: widget.onToggleComplete,
              durationVisible: devDurationVisible,
              // List mode has no timeline axis at all, so the time is the
              // only place a task's schedule reads — requested directly
              // ("we always show the time in front of the task because we
              // don't show the timeline"). `compactText` is already this
              // widget's own "true in List mode" signal (see its doc
              // comment); Task view's split layout keeps its existing,
              // dev-toggle-driven behavior unchanged.
              alwaysShowTime: widget.compactText,
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

    final slots = layoutOverlappingTasks(tasks);
    final slotByTaskId = {for (final slot in slots) slot.task.id: slot};
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
