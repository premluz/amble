import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feature_flags.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/providers/preferences_providers.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/tracked_behavior_providers.dart';
import '../../shared/services/cascade_reschedule.dart';
import '../../shared/services/overlap_checker.dart';
import '../tracked_behavior/behavior_outcome_prompt.dart';
import '../task_detail/task_action_sheet.dart';
import '../task_detail/task_detail_sheet.dart';
import 'current_time_indicator.dart';
import 'day_strip.dart';
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
                      showHourLabels: ref.watch(
                        showHourLabelsSettingProvider,
                      ),
                      onTaskTap: (task) =>
                          showTaskActionSheet(context, task: task),
                      onToggleComplete: (task) =>
                          _completeTask(context, ref, task),
                      onReschedule: (task, newScheduledAt) =>
                          taskNotifier.rescheduleTask(task, newScheduledAt),
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
    required this.showHourLabels,
    required this.onTaskTap,
    required this.onToggleComplete,
    required this.onReschedule,
  });

  final List<Task> tasks;
  final AmbleTheme theme;

  /// Whether the left-side hour gutter renders at all — the Settings
  /// toggle (`ShowHourLabelsSetting`), read once by [TimelineScreen] (the
  /// `ConsumerWidget` parent) and threaded down as a plain field, same as
  /// [theme]/[tasks], rather than making this `StatefulWidget` itself
  /// Riverpod-aware.
  final bool showHourLabels;
  final _TaskCallback onTaskTap;
  final _TaskCallback onToggleComplete;
  final _RescheduleCallback onReschedule;

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  final _scrollController = ScrollController();

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
  void dispose() {
    _minuteTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tasks = widget.tasks;
    // tasks is never empty here — the parent (TimelineScreen) renders
    // _EmptyDayState instead of _DayTimeline when there are no tasks.
    final (rangeStart, rangeEnd) = _visibleRange(tasks);
    final slots = _dragLastOrder(layoutOverlappingTasks(tasks));
    final blockTops = _blockTops(slots, rangeStart, theme);
    // Timeline mode's height is the real elapsed span. Collapsed mode has
    // no span — its height is just however far the stack reached, plus
    // the last block's own height.
    final dayHeight = widget.showHourLabels
        ? rangeEnd.difference(rangeStart).inMinutes * _pixelsPerMinute
        : slots.fold<double>(
            0,
            (tallest, slot) => math.max(
              tallest,
              blockTops[slot.task.id]! + _collapsedBlockHeight(slot.task, theme),
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
                      slot.column * (_pillWidth(theme) + _columnGap(theme)),
                  right: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.2,
                      child: TaskCapsuleBlock(
                        task: slot.task,
                        pixelsPerMinute: pixelsPerMinute,
                        maxTextWidth: slot.column < slot.columnCount - 1
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
                // Drag-to-reschedule needs a pixel->minute mapping, which
                // collapsed mode doesn't have: vertical position there is
                // stacking order, not time. Disabled rather than given a
                // second, inconsistent meaning — confirmed via
                // AskUserQuestion. "Edit time and duration" still works,
                // and dragging returns as soon as hour labels are back on.
                isDraggable: widget.showHourLabels,
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
          ],
        ),
      ),
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

  @override
  ConsumerState<_DraggableTaskBlock> createState() =>
      _DraggableTaskBlockState();
}

class _DraggableTaskBlockState extends ConsumerState<_DraggableTaskBlock> {
  double _dragOffset = 0;
  bool _isDragging = false;

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
      child: AnimatedScale(
        scale: _isDragging ? _liftScale : 1.0,
        duration: widget.theme.motionFast,
        curve: widget.theme.curveStandard,
        // Drag handlers now live on TaskCapsuleBlock's own icon-pill
        // GestureDetector (scoped to just the pill, not the whole row) —
        // requested directly, since dragging from the title/time text
        // fought the timeline's own vertical scroll gesture.
        child: TaskCapsuleBlock(
          task: widget.task,
          pixelsPerMinute: widget.pixelsPerMinute,
          onTap: widget.onTap,
          onToggleComplete: widget.onToggleComplete,
          dragPreviewStartsAt: _isDragging ? _previewStartsAt : null,
          isLifted: _isDragging,
          // When a task shares its slot, its text has to stop
          // before the next column's pill starts, or titles run
          // under neighbours.
          maxTextWidth: slot.column < slot.columnCount - 1
              ? _pillWidth(widget.theme)
              : null,
          // Null handlers in collapsed mode leave the pill tappable but
          // not draggable — see _DraggableTaskBlock.isDraggable.
          onDragStart: !widget.isDraggable ? null : (_) {
            setState(() => _isDragging = true);
            widget.onDraggingChanged(true);
          },
          onDragUpdate: !widget.isDraggable ? null : (details) {
            setState(() => _dragOffset += details.delta.dy);
          },
          onDragEnd: !widget.isDraggable ? null : (_) async {
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
