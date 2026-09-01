import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dev_config.dart';
import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/providers/category_providers.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/services/cascade_reschedule.dart';
import '../../shared/services/overlap_checker.dart';
import '../../shared/services/overlap_cluster.dart';
import '../tracked_behavior/behavior_outcome_prompt.dart';
import '../task_detail/task_action_sheet.dart';
import '../task_detail/task_detail_sheet.dart';
import 'current_time_indicator.dart';
import 'day_strip.dart';
import 'free_window_block.dart';
import 'overlap_cluster_block.dart';
import 'place_task_line.dart';
import 'recently_saved_task_provider.dart';
import 'selected_date_provider.dart';
import 'task_boundary_markers.dart';
import 'task_capsule_block.dart';
import 'task_overlap_layout.dart';
import 'tasks_for_selected_day_provider.dart';

// The visible scroll range used to be a fixed calendar-day window
// (0-24h, previously 6-22h — see docs/ERROR_LOG.md for why that was
// widened). Now computed dynamically per day from the tasks actually
// scheduled, in _DayTimelineState._visibleRange — requested directly, so
// the day only scrolls through the range it actually has content for.
const _pixelsPerMinute = 1.5;
const _hourGutterWidth = 56.0;

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
double _collapsedBlockGap(AmbleTheme theme) => theme.spacingMd;

/// [TaskCapsuleBlock]'s pill width, mirrored here (not imported — it's an
/// internal layout detail of that component, not part of its public API)
/// so overlapping tasks can be offset by exactly one pill per column. See
/// docs/DECISIONS.md.
double _pillWidth(AmbleTheme theme) => theme.spacingXl * 0.9;

/// Horizontal gap between the pills of two overlapping tasks.
double _columnGap(AmbleTheme theme) => theme.spacingXs;

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
    final categoryById = {
      for (final category in ref.watch(categoryListProvider))
        category.id: category,
    };
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
              child: tasks.isEmpty
                  ? _EmptyDayState(theme: theme)
                  : _DayTimeline(
                      tasks: tasks,
                      theme: theme,
                      categoryById: categoryById,
                      showHourLabels: ref.watch(showHourLabelsSettingProvider),
                      onTaskTap: (task) =>
                          showTaskActionSheet(context, task: task),
                      onToggleComplete: (task) =>
                          _completeTask(context, ref, task),
                      onReschedule: (task, newScheduledAt) =>
                          taskNotifier.rescheduleTask(task, newScheduledAt),
                      onCreateAt: (startAt) => showTaskDetailSheet(
                        context,
                        initialScheduledAt: startAt,
                        initialTimeOfDay: TimeOfDay.fromDateTime(startAt),
                      ),
                      recentlySaved: ref.watch(recentlySavedTaskProvider),
                      onSavedTaskConsumed: () =>
                          ref.read(recentlySavedTaskProvider.notifier).clear(),
                      disableClustering: ref.watch(
                        disableOverlapClusteringSettingProvider,
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
    required this.showHourLabels,
    required this.onTaskTap,
    required this.onToggleComplete,
    required this.onReschedule,
    required this.onCreateAt,
    required this.recentlySaved,
    required this.onSavedTaskConsumed,
    required this.disableClustering,
  });

  final List<Task> tasks;
  final AmbleTheme theme;

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
  /// 2–3 overlapping tasks stay individual capsules (naive spatial
  /// overlap) instead of collapsing into one `OverlapClusterBlock`.
  /// Threaded down as a plain field for the same reason as
  /// [showHourLabels].
  final bool disableClustering;

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

  /// Half an hour of scrollable space kept before the first task and after
  /// the last, so a task at either edge of the day isn't clipped right at
  /// the scroll boundary — its full pill (and time label) stays
  /// comfortably visible when scrolled all the way to that end.
  static const _rangePadding = Duration(minutes: 30);

  /// The day view's visible top/bottom edges, clamped to what's actually
  /// scheduled that day (plus [_rangePadding]) rather than a fixed
  /// calendar-day window — requested directly. A task at 4am or 11pm is
  /// reachable because the range is built from real task times, not
  /// because the window is artificially wide; a day with no early/late
  /// tasks simply doesn't scroll into empty pre-dawn/late-night space.
  (DateTime start, DateTime end) _visibleRange(List<Task> tasks) {
    var earliest = tasks.first.scheduledAt!;
    var latest = earliest.add(Duration(minutes: tasks.first.durationMinutes!));
    for (final task in tasks.skip(1)) {
      final start = task.scheduledAt!;
      final end = start.add(Duration(minutes: task.durationMinutes!));
      if (start.isBefore(earliest)) earliest = start;
      if (end.isAfter(latest)) latest = end;
    }
    return (earliest.subtract(_rangePadding), latest.add(_rangePadding));
  }

  @override
  void initState() {
    super.initState();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // The day's FIRST task doesn't reach didUpdateWidget: the screen was
    // showing _EmptyDayState until a moment ago, so this widget mounts
    // fresh rather than updating. Handled here so saving the first task
    // of a day scrolls to it and clears the flag exactly like every
    // subsequent one does.
    if (widget.recentlySaved != null) {
      _revealSavedTask(widget.recentlySaved!);
      return;
    }
    // Open the day view scrolled to roughly the current time, so "now" is
    // visible without the user having to scroll first — falls back to the
    // top of the range when "now" isn't inside it at all (e.g. viewing a
    // different day, or every task on today is already in the past).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.tasks.isEmpty) return;
      // Collapsed mode has no time axis to scroll "to now" against, and
      // its stack is short enough that opening at the top is right.
      if (!widget.showHourLabels) return;
      final (rangeStart, rangeEnd) = _visibleRange(widget.tasks);
      final now = DateTime.now();
      final anchor = now.isBefore(rangeStart) || now.isAfter(rangeEnd)
          ? rangeStart
          : now;
      final minutesSinceStart = anchor.difference(rangeStart).inMinutes;
      final target =
          (minutesSinceStart * _pixelsPerMinute) -
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
    if (saved == null || saved.taskId == oldWidget.recentlySaved?.taskId) {
      return;
    }
    _revealSavedTask(saved);
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
        (minutesSinceStart * _pixelsPerMinute) -
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
    // tasks is never empty here — the parent (TimelineScreen) renders
    // _EmptyDayState instead of _DayTimeline when there are no tasks.
    final (rangeStart, rangeEnd) = _visibleRange(tasks);
    // Timeline mode only — clustering answers "how does this render on the
    // real time axis," which collapsed mode's stacking layout has no
    // meaningful version of. Detection re-runs from the CURRENT task list
    // on every build, so a drop that creates/dissolves a cluster (task 5/6
    // of the work order) is picked up automatically on the very next
    // rebuild after the reschedule write lands — no separate "recompute
    // clusters" step is needed.
    //
    // The task actively being dragged is excluded from the tasks clusters
    // are computed FROM: per direct requirement, a dragged task renders
    // completely normally — its own full capsule — regardless of what's
    // underneath it, and the tasks it would otherwise cluster with must
    // likewise stay as their own ordinary capsules while it's away, not
    // silently form a smaller cluster among themselves mid-drag.
    final clusters = (widget.showHourLabels && !widget.disableClustering)
        ? detectOverlapClusters(
            _draggingTaskId == null
                ? tasks
                : tasks.where((task) => task.id != _draggingTaskId).toList(),
          )
        : const <OverlapCluster>[];
    final clusteredIds = clusteredTaskIds(clusters);
    // The dragged block's ghost (left behind at its ORIGINAL slot, see the
    // loop below) needs the lane it held as a resting cluster member, not
    // an ordinary layoutOverlappingTasks column — those two schemes don't
    // agree, and mixing them made the ghost land in a lane that visually
    // collided with the remaining members' now-recomputed fixed lanes,
    // reported directly as "items go in 2 lanes and a transparent one."
    // Computed WITHOUT the drag exclusion above, purely for this purpose.
    final restingClusters = (widget.showHourLabels && !widget.disableClustering)
        ? detectOverlapClusters(tasks)
        : const <OverlapCluster>[];
    final slots = _dragLastOrder(
      _withClusterLanes(layoutOverlappingTasks(tasks), clusters),
    );
    final ghostSlots = _withClusterLanes(
      layoutOverlappingTasks(tasks),
      restingClusters,
    );
    final blockTops = _blockTops(slots, rangeStart, theme);
    // Timeline mode's height is the real elapsed span. Collapsed mode has
    // no span — its height is just however far the stack reached, plus
    // the last block's own height.
    final contentHeight = widget.showHourLabels
        ? rangeEnd.difference(rangeStart).inMinutes * _pixelsPerMinute
        : slots.fold<double>(
            0,
            (tallest, slot) => math.max(
              tallest,
              blockTops[slot.task.id]! +
                  _collapsedBlockHeight(slot.task, theme),
            ),
          );
    final pixelsPerMinute = widget.showHourLabels
        ? _pixelsPerMinute
        : _collapsedPixelsPerMinute(theme);
    // Collapses to 0 when the Settings toggle is off, so tasks/connectors/
    // the now-line reclaim the space rather than leaving a blank margin —
    // confirmed via AskUserQuestion over the alternative (keep the width
    // reserved but empty).
    final hourGutterWidth = widget.showHourLabels ? _hourGutterWidth : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // `_visibleRange` is deliberately dynamic (earliest task - 30min to
        // latest task + 30min, not a fixed calendar-day window — see the
        // comment above), so a day with few tasks produces a short
        // `contentHeight`. Without a floor, the SizedBox below (and the
        // timeline surface/gutter/markers painted inside it) stopped short
        // of the actual screen, reading as a "cut off" container that grew
        // only with task count — reported directly, confirmed via
        // AskUserQuestion to floor at the viewport height rather than
        // reverting to a fixed range. The vertical padding this
        // SingleChildScrollView applies below counts as part of the
        // viewport's consumed space, so it's subtracted from
        // constraints.maxHeight before comparing.
        final dayHeight = math.max(
          contentHeight,
          constraints.maxHeight - theme.spacingMd * 2,
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
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacingScreenPadding,
            vertical: theme.spacingMd,
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
                    pixelsPerMinute: _pixelsPerMinute,
                    controller: _placeLineController,
                    onPlaced: widget.onCreateAt,
                  ),
                if (widget.showHourLabels)
                  TaskBoundaryMarkers(
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    pixelsPerMinute: _pixelsPerMinute,
                    hideLabelNear: _now,
                  ),
                // A visible gray thread connecting every consecutive pair of
                // tasks, matching a reference design — requested directly.
                // Painted before the task blocks so the blocks sit on top.
                // Timeline mode only: the connector's whole job is to show
                // the run of real time between two tasks, which collapsed
                // mode deliberately doesn't represent.
                if (widget.showHourLabels)
                  _TimelineConnectors(
                    tasks: tasks,
                    theme: theme,
                    rangeStart: rangeStart,
                    pixelsPerMinute: _pixelsPerMinute,
                    hourGutterWidth: hourGutterWidth,
                  ),
                // A subtle labeled block for any gap of freeWindowThreshold or
                // longer between two tasks — requested directly: "no indicator
                // for small/normal gaps... a labeled, size-appropriate compact
                // block only for large gaps." Timeline mode only, same
                // reasoning as the connectors above: collapsed mode has no
                // time axis for a gap's size to mean anything against.
                if (widget.showHourLabels)
                  for (final window in findFreeWindows(
                    tasks,
                    // Mirrors the pill-height floor TaskCapsuleBlock applies
                    // (see _pillHeight above) — without this, a free window
                    // computed from raw scheduled times could start before a
                    // short task's actual RENDERED pill has finished, and the
                    // two visually overlapped. Reported directly.
                    minPillMinutes: _pillWidth(theme) / _pixelsPerMinute,
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
                              _pixelsPerMinute +
                          theme.spacingSm,
                      height:
                          window.duration.inMinutes * _pixelsPerMinute -
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
                    contentHidden: clusteredIds.contains(slot.task.id),
                    // Drag-to-reschedule needs a pixel->minute mapping, which
                    // collapsed mode doesn't have: vertical position there is
                    // stacking order, not time. Disabled rather than given a
                    // second, inconsistent meaning — confirmed via
                    // AskUserQuestion. "Edit time and duration" still works,
                    // and dragging returns as soon as hour labels are back on.
                    isDraggable: widget.showHourLabels,
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
                for (final cluster in restingClusters)
                  Positioned(
                    key: ValueKey(
                      'cluster-list-${cluster.tasks.map((task) => task.id).join('-')}',
                    ),
                    top: blockTops[cluster.tasks.first.id]!,
                    // Clears every lane's pill column — the pills themselves
                    // carry no checkbox any more (see
                    // TaskCapsuleBlock.contentHidden), so only the pill width
                    // needs clearing, not a trailing checkbox column too.
                    left:
                        hourGutterWidth +
                        cluster.tasks.length *
                            (_pillWidth(theme) + _columnGap(theme)),
                    right: 0,
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
                      ),
                    ),
                  ),
                if (widget.showHourLabels)
                  for (final cluster in clusters)
                    OverlapClusterBoundaryLabels(
                      theme: theme,
                      cluster: cluster,
                      rangeStart: rangeStart,
                      pixelsPerMinute: _pixelsPerMinute,
                    ),
                // Timeline mode only: the now-line's position is meaningless
                // without a time axis to place it against — in collapsed mode
                // it would sit at an arbitrary point between two stacked
                // blocks and imply a scale that isn't there.
                if (widget.showHourLabels)
                  CurrentTimeIndicator(
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    pixelsPerMinute: _pixelsPerMinute,
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
                    pixelsPerMinute: _pixelsPerMinute,
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
  /// so the timeline and collapsed modes share one rendering path rather
  /// than branching at each of the half-dozen places a `top` is needed.
  ///
  /// Timeline mode maps real elapsed time to pixels. Collapsed mode
  /// ignores elapsed time entirely and stacks each block directly after
  /// the previous one (its own proportional height plus a fixed gap),
  /// which is the whole point: with no hour labels on screen the gaps
  /// reference nothing, so a sparse day shouldn't scroll through empty
  /// space. Overlapping tasks share a row in collapsed mode — they're
  /// laid out side by side by column, so only the first of a group
  /// advances the cursor.
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
              _pixelsPerMinute,
      };
    }

    final tops = <String, double>{};
    final gap = _collapsedBlockGap(theme);
    var cursor = 0.0;
    var rowHeight = 0.0;
    DateTime? rowStart;

    for (final slot in slots) {
      // A new row starts whenever this task isn't part of the same
      // overlap group as the previous one. Column 0 always begins a
      // group (see layoutOverlappingTasks).
      if (rowStart != null && slot.column == 0) {
        cursor += rowHeight + gap;
        rowHeight = 0.0;
      }
      rowStart ??= slot.task.scheduledAt;
      if (slot.column == 0) rowStart = slot.task.scheduledAt;

      tops[slot.task.id] = cursor;
      final height = _collapsedBlockHeight(slot.task, theme);
      if (height > rowHeight) rowHeight = height;
    }

    return tops;
  }

  /// A block's rendered height in collapsed mode — the same
  /// duration-proportional value [TaskCapsuleBlock] computes internally,
  /// mirrored here so the stacking cursor knows how far to advance.
  double _collapsedBlockHeight(Task task, AmbleTheme theme) => math.max(
    task.durationMinutes! * _collapsedPixelsPerMinute(theme),
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

  @override
  ConsumerState<_DraggableTaskBlock> createState() =>
      _DraggableTaskBlockState();
}

class _DraggableTaskBlockState extends ConsumerState<_DraggableTaskBlock> {
  double _dragOffset = 0;
  bool _isDragging = false;

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
    final columnOffset =
        slot.column * (_pillWidth(widget.theme) + _columnGap(widget.theme));

    // AnimatedPositioned, not a plain Positioned: a zero duration while
    // the finger is down (so tracking is 1:1 with no lag), and a real
    // eased duration while settling, which is what makes the drop glide
    // into its snapped slot instead of jumping. The ghost is still
    // rendered by the parent (_DayTimelineState) as a sibling, via
    // widget.onDraggingChanged, specifically so this widget's own
    // hit-testable footprint stays badge-sized rather than inflating to
    // the full day-column height. See the comment on
    // _DayTimelineState._draggingTaskId for the bug that caused.
    return AnimatedPositioned(
      // Zero ONLY while this block is the one under the finger — dragging
      // has to track 1:1 with no lag. Every other repositioning eases:
      // this block settling into its snapped slot after a drop, and (the
      // case that matters for neighbours) a task the cascade pushed out of
      // the way, which now slides to its new time instead of teleporting.
      duration: _isDragging ? Duration.zero : widget.theme.motionNormal,
      curve: Curves.easeOut,
      top: top,
      left: widget.left + columnOffset,
      right: 0,
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
      child: TweenAnimationBuilder<double>(
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
            // When a task shares its slot, its text has to stop
            // before the next column's pill starts, or titles run
            // under neighbours.
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
