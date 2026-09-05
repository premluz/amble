import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/dev_config.dart';
import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/services/zone_containment.dart';
import 'current_time_indicator.dart';
import 'external_event_block.dart';
import 'task_boundary_markers.dart';
import 'task_capsule_block.dart';
import 'zone_background_block.dart'
    show zoneBackgroundGap, zoneBackgroundOffset;
import 'zone_container_block.dart';

const _hourGutterWidth = 56.0;

/// Half an hour of scrollable space before the first item and after the
/// last — matches `_DayTimeline`'s own `_rangePadding`, so switching modes
/// doesn't change how tightly the day is cropped at either edge.
const _rangePadding = Duration(minutes: 30);

/// How much a raw drag delta (in pixels) snaps to, converted through
/// [ZoneDayTimeline.pixelsPerMinute] — matches `_DayTimelineState`'s own
/// `_snapMinutes` exactly, so a task dragged in Zone view lands on the
/// same 5-minute grid it would in the Task view.
const _snapMinutes = 5;

typedef ZoneTaskCallback = void Function(Task task);

/// Fired when a drag commits: [zoneId] is the container the task was
/// dropped into (null if dropped back on the outer axis, clearing any
/// existing assignment) and [newScheduledAt] is the resulting time.
typedef ZoneReassignCallback = Future<void> Function(
  Task task,
  String? zoneId,
  DateTime newScheduledAt,
);

/// The Spatial Zone View's own day timeline: [Zone]s render as real
/// [ZoneContainerBlock] containers stacked in chronological order on an
/// outer time axis, each sized to at least its real duration (growing
/// taller than that when its member rows need more room — see
/// [zoneContainerRowHeight]); unzoned tasks (per
/// [resolveZoneContainment]) render as ordinary [TaskCapsuleBlock]s
/// interleaved at their own real spatial time position on that same
/// outer axis, exactly as they do in the Task view.
///
/// Shows the same left-side hour gutter ([TaskBoundaryMarkers]) as the
/// Task view — confirmed directly, so both modes share one time-reading
/// affordance.
///
/// Drag-and-drop: every task (whether an in-container row or an outer-axis
/// capsule) can be dragged vertically. Dropping it inside a container's
/// on-screen bounds sets its `zoneId` to that zone explicitly (confirmed
/// directly — a real, persisted assignment, not just a display fallback);
/// dropping it back on the outer axis clears `zoneId`. Vertical position
/// always sets real time (`scheduledAt`), snapped to 5 minutes, matching
/// the Task view's own drag feel — since Zone view has no overlap concept,
/// there is no cascade/cluster logic to carry over, only reordering.
class ZoneDayTimeline extends StatefulWidget {
  const ZoneDayTimeline({
    super.key,
    required this.tasks,
    required this.zones,
    this.externalEvents = const [],
    required this.theme,
    required this.categoryById,
    required this.selectedDate,
    this.devTextLayout = TimelineTaskTextLayout.stacked,
    this.showCompletionCheckbox = true,
    this.devIconsVisible = true,
    this.devDurationVisible = true,
    this.pixelsPerMinute = 3.0,
    required this.onTaskTap,
    required this.onToggleComplete,
    required this.onReassign,
    this.readViewedMinutes,
    this.onViewedMinutesChanged,
  });

  final List<Task> tasks;
  final List<Zone> zones;

  /// Read-only events fetched from whichever device calendars the user
  /// selected to display (Settings' Calendar section, Feature 1) — see
  /// CONSTITUTION.md's "Calendar" section. Rendered the same way as on the
  /// Task view: [ExternalEventBlock], positioned on this view's own outer
  /// time axis (same [rangeStart]/[pixelsPerMinute] every zone
  /// container/unzoned task already uses here), excluded from
  /// zone-containment resolution entirely — an external event can never be
  /// "inside" a Zone container, since containment is a Task/Zone concept.
  final List<ExternalCalendarEvent> externalEvents;

  final AmbleTheme theme;
  final Map<String, Category> categoryById;
  final DateTime selectedDate;

  /// Dev-only capsule display toggles (Settings' "Developer" section) —
  /// applied to this view's outer-axis `TaskCapsuleBlock`s so they match
  /// the Task view's own capsules, per the same providers. Defaults match
  /// the providers' own defaults, so a caller that doesn't wire them up
  /// (a dev scaffold, a test) still renders the current shipped look.
  final TimelineTaskTextLayout devTextLayout;
  final bool devIconsVisible;
  final bool devDurationVisible;

  /// Whether a task's trailing completion checkbox renders
  /// (`ShowCompletionCheckboxSetting`) — a real user setting, not a dev
  /// toggle, applied to BOTH this view's in-container rows and its
  /// outer-axis capsules, so one toggle covers all three views.
  final bool showCompletionCheckbox;

  /// Vertical scale for this view — independently configurable from the
  /// Task view's own scale (`DevTaskViewPixelsPerMinute`), per
  /// `DevZoneViewPixelsPerMinute` (Settings' Developer section). Defaults
  /// to double the Task view's original 1.5, confirmed directly: at the
  /// old shared 1.5 scale, a short (e.g. 30-minute) zone container barely
  /// fit its own header, forcing it to grow into — and collapse — the gap
  /// against its neighbour on nearly every zone, not just genuinely
  /// packed ones (reported as "missing gap between adjacent zones").
  final double pixelsPerMinute;

  final ZoneTaskCallback onTaskTap;
  final ZoneTaskCallback onToggleComplete;
  final ZoneReassignCallback onReassign;

  /// Reads the minutes-since-midnight last centered in EITHER spatial view
  /// (Task or Zone) — see `viewed_time_provider.dart`. Returns null when
  /// nothing has been recorded yet this session, in which case this view
  /// falls back to centering on "now".
  ///
  /// A CALLBACK rather than a plain value — see `_DayTimeline`'s own copy
  /// of this field for why passing the value meant `TimelineScreen` had to
  /// watch the provider, rebuilding the whole screen on every scroll.
  final int? Function()? readViewedMinutes;

  /// Reports this view's own center position (minutes-since-midnight)
  /// whenever it scrolls, so the Task view (and a future switch back to
  /// this one) can resume from it.
  final ValueChanged<int>? onViewedMinutesChanged;

  @override
  State<ZoneDayTimeline> createState() => _ZoneDayTimelineState();
}

class _ZoneDayTimelineState extends State<ZoneDayTimeline> {
  final _scrollController = ScrollController();

  /// The task currently being dragged, if any. Changed only at drag
  /// START and END (never per pointer move), so the one `setState` it
  /// drives happens twice per drag rather than on every frame.
  String? _draggingTaskId;

  /// The live finger offset, held in a [ValueNotifier] rather than in
  /// `setState` state on purpose: only the floating drag visual listens to
  /// it (via [ValueListenableBuilder]), so a pointer move rebuilds that
  /// ONE widget instead of this whole view.
  ///
  /// Rebuilding the root per move is what made dragging janky (reported
  /// directly): it re-ran `resolveZoneContainment` and `_visibleRange`,
  /// rebuilt every container and row, and forced each container's
  /// `IntrinsicHeight` to re-measure — all at pointer-event rate. The Task
  /// view avoids this structurally by keeping its own drag `setState` on
  /// a per-task leaf widget (`_DraggableTaskBlockState`) rather than on
  /// the day timeline; this notifier is the equivalent for a view whose
  /// dragged item can't own that state itself (a row's floating copy
  /// lives on the outer Stack, not in the row).
  final _dragOffsetY = ValueNotifier<double>(0);

  /// The zone the CURRENT drag would drop into if released now, or null
  /// when the drop would land outside every zone. Drives that container's
  /// highlight border — requested directly, so it's visible which zone a
  /// task is about to be assigned to before letting go.
  ///
  /// A separate notifier (rather than deriving it inside the drag card's
  /// own builder) so each container can listen for JUST its own id and
  /// rebuild only when its highlight actually flips, keeping the
  /// per-pointer-move cost off the rest of the view — same reasoning as
  /// [_dragOffsetY].
  final _hoveredZoneId = ValueNotifier<String?>(null);

  /// Set only when the drag originated on an in-container row (which has
  /// no meaningful position of its own on the outer axis to float from) —
  /// the task being dragged and the resting top used as this floating
  /// visual's starting point. An outer-axis capsule needs no such tracking
  /// since `TaskCapsuleBlock` already renders (and moves) itself in place.
  Task? _draggingRowTask;
  double _draggingRowRestingTop = 0;

  /// Key on this build's own outer Stack — the coordinate frame every
  /// `Positioned` child here is expressed in, and what an in-container
  /// row resolves its own position relative to on drag start (see
  /// `_ZoneTaskRow._handleDragStart`).
  final _stackKey = GlobalKey();

  /// The visible time range: the FULL calendar day (midnight to
  /// midnight), always — matching `_DayTimeline._visibleRange`'s own
  /// rule. Reported directly: a range derived from the day's own
  /// zones/tasks left whole stretches of the day unscrollable, and an
  /// empty day unscrollable entirely.
  ///
  /// Still widened by [_rangePadding] past anything that genuinely falls
  /// outside the calendar day (a zone or task running past midnight), so
  /// it stays reachable rather than clipped at the boundary.
  (DateTime start, DateTime end) _visibleRange() {
    final day = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    var earliest = day;
    var latest = day.add(const Duration(days: 1));
    void consider(DateTime start, DateTime end) {
      if (start.isBefore(earliest)) earliest = start.subtract(_rangePadding);
      if (end.isAfter(latest)) latest = end.add(_rangePadding);
    }

    for (final zone in widget.zones) {
      consider(
        day.add(Duration(minutes: zone.startMinutes)),
        day.add(Duration(minutes: zone.endMinutes)),
      );
    }
    for (final task in widget.tasks) {
      final start = task.scheduledAt;
      final duration = task.durationMinutes;
      if (start == null || duration == null) continue;
      consider(start, start.add(Duration(minutes: duration)));
    }

    return (earliest, latest);
  }

  /// [restingTop] is only needed for a row-originated drag (see
  /// [_draggingRowTask]) — an outer-axis capsule already knows its own
  /// resting top from [task.scheduledAt] at drop time, so it passes null.
  void _handleDragStart(Task task, {double? restingTop}) {
    _dragOffsetY.value = 0;
    _hoveredZoneId.value = _zoneIdContainingTime(_previewStartsAtFor(task));
    setState(() {
      _draggingTaskId = task.id;
      if (restingTop != null) {
        _draggingRowTask = task;
        _draggingRowRestingTop = restingTop;
      }
    });
  }

  /// Deliberately NOT `setState` — see [_dragOffsetY]'s own doc comment.
  /// Both notifiers updated here drive narrowly-scoped listeners only.
  void _handleDragUpdate(Task task, DragUpdateDetails details) {
    _dragOffsetY.value += details.delta.dy;
    _hoveredZoneId.value = _zoneIdContainingTime(_previewStartsAtFor(task));
  }

  /// Where the floating drag card is DRAWN from — a row's own measured
  /// on-screen position when the drag began on a container row (so the
  /// card appears exactly over the row it lifted from), otherwise the
  /// task's ordinary outer-axis position.
  ///
  /// This is a PAINT position only. It is deliberately not used to derive
  /// time — see [_timeAnchorTopFor].
  double _restingTopFor(Task task) {
    if (_draggingRowTask?.id == task.id) return _draggingRowRestingTop;
    return _timeAnchorTopFor(task);
  }

  /// Where the dragged task sits on the TIME axis, which is what a drop
  /// converts back into a `scheduledAt`.
  ///
  /// Always derived from the task's own `scheduledAt`, never from a row's
  /// measured position: a row is laid out inside its container (below the
  /// header, after any preceding rows), so its on-screen Y is unrelated to
  /// the time axis. Using it as the time anchor made a small drag resolve
  /// to a much later time than the row's real one, so a task dropped
  /// visually inside a zone often landed outside that zone's window —
  /// reported directly ("doesn't work even if hour matches zone period").
  double _timeAnchorTopFor(Task task) {
    final (rangeStart, _) = _visibleRange();
    return task.scheduledAt!.difference(rangeStart).inMinutes *
        widget.pixelsPerMinute;
  }

  /// The start time this drag would commit to if released right now,
  /// derived from the live drop position on the outer axis and snapped to
  /// [_snapMinutes].
  ///
  /// Shared by the floating visual's own time label and by the commit in
  /// [_handleDragEnd], so the time shown mid-drag can never disagree with
  /// the time actually saved — the same guarantee `_DraggableTaskBlock`'s
  /// own `_previewStartsAt` gives on the Task view.
  DateTime _previewStartsAtFor(Task task) {
    final droppedTop = _timeAnchorTopFor(task) + _dragOffsetY.value;
    final (rangeStart, _) = _visibleRange();
    return rangeStart.add(
      Duration(
        minutes:
            (droppedTop / widget.pixelsPerMinute / _snapMinutes).round() *
            _snapMinutes,
      ),
    );
  }

  Future<void> _handleDragEnd(Task task) async {
    final newScheduledAt = _previewStartsAtFor(task);
    final droppedZoneId = _zoneIdContainingTime(newScheduledAt);
    _dragOffsetY.value = 0;
    _hoveredZoneId.value = null;
    setState(() {
      _draggingTaskId = null;
      _draggingRowTask = null;
    });

    await widget.onReassign(task, droppedZoneId, newScheduledAt);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_reportViewedMinutes);
    _scrollToCurrentHourCentered();
  }

  @override
  void didUpdateWidget(ZoneDayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-centers only when the day being viewed changes — matches
    // `_DayTimeline`'s own behavior. Does NOT re-run on anything else, so
    // scroll position otherwise carries over/resumes from a remembered
    // value rather than resetting.
    if (widget.selectedDate != oldWidget.selectedDate) {
      _scrollToCurrentHourCentered();
    }
  }

  @override
  void dispose() {
    _dragOffsetY.dispose();
    _hoveredZoneId.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Reports this view's own center position (minutes-since-midnight,
  /// projected onto whichever day is being viewed) up to `TimelineScreen`
  /// via [ZoneDayTimeline.onViewedMinutesChanged] on every scroll — mirrors
  /// `_DayTimelineState._reportViewedMinutes` exactly, so switching to the
  /// Task view (which remounts fresh) resumes from here.
  void _reportViewedMinutes() {
    if (widget.onViewedMinutesChanged == null) return;
    if (!_scrollController.hasClients) return;
    final (rangeStart, _) = _visibleRange();
    // Subtract the scroll view's own top padding, and anchor the result on
    // the START OF THE VIEWED DAY rather than `rangeStart`'s own wall-clock
    // time — see `_DayTimelineState._reportViewedMinutes`'s own copy of
    // both, including why the `rangeStart.hour * 60` form was a real bug
    // once anything widened the range past midnight. This view widens its
    // range from zones AND tasks (Task view uses tasks only), so the two
    // genuinely can disagree about `rangeStart`; anchoring on the day is
    // what keeps the shared value meaning the same thing in both.
    final centerOffset =
        _scrollController.offset +
        (_scrollController.position.viewportDimension / 2) -
        widget.theme.spacingLg;
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
  /// viewport — mirrors `_DayTimelineState._scrollToCurrentHourCentered`
  /// exactly, including preferring [ZoneDayTimeline.readViewedMinutes]
  /// over "now" when a position was already remembered from the Task view.
  void _scrollToCurrentHourCentered() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final (rangeStart, rangeEnd) = _visibleRange();
      final remembered = widget.readViewedMinutes?.call();
      // Anchors on a TIME OF DAY projected onto the day being viewed, not
      // on `now` itself — see `_DayTimeline`'s own copy of this reasoning.
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

  /// The zone (if any) whose own time window contains [time], or null when
  /// the drop lands outside every zone (which clears the assignment).
  ///
  /// Resolved from the zones' own `startMinutes`/`endMinutes` rather than
  /// from measured container bounds: the measured version raced with
  /// layout — bounds were cleared on every build but only repopulated in a
  /// post-frame callback, so a drop landing between those two moments saw
  /// an empty map and never found its target (reported directly: a task
  /// could be dragged OUT of a zone but not back INTO one). Reading the
  /// same half-open window `resolveZoneContainment` uses also guarantees
  /// the drop target agrees with where the task will actually render.
  String? _zoneIdContainingTime(DateTime time) {
    final minutesSinceMidnight = time.hour * 60 + time.minute;
    for (final zone in widget.zones) {
      if (minutesSinceMidnight >= zone.startMinutes &&
          minutesSinceMidnight < zone.endMinutes) {
        return zone.id;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final result = resolveZoneContainment(
      tasks: widget.tasks,
      zones: widget.zones,
      day: widget.selectedDate,
      externalEvents: widget.externalEvents,
    );
    // Every external event already matched into a zone container above —
    // the outer-axis render loop below must skip these, or a matched
    // event would render twice (once inside its container, once again as
    // a floating outer-axis block). Requested directly: "on zone mode
    // tasks imported should be inside zones like other task[s]."
    final containedExternalEventIds = {
      for (final containment in result.containments)
        for (final event in containment.externalEvents) event.id,
    };
    final outerAxisExternalEvents = widget.externalEvents
        .where((event) => !containedExternalEventIds.contains(event.id))
        .toList();
    final (rangeStart, rangeEnd) = _visibleRange();
    final totalHeight =
        rangeEnd.difference(rangeStart).inMinutes * widget.pixelsPerMinute;

    double topFor(DateTime time) =>
        time.difference(rangeStart).inMinutes * widget.pixelsPerMinute;
    double topForZoneStart(Zone zone) => topFor(
      DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      ).add(Duration(minutes: zone.startMinutes)),
    );

    // ZoneDayTimeline mounts fresh every time the view-cycle button lands
    // on Zone view — it's a completely separate widget from Task/List
    // view's `_DayTimeline`, not a shared one, so there's no prior frame to
    // ease from. Everything (containers, capsules, the hour gutter) would
    // otherwise pop in on the same frame — reported directly as a
    // "flash," since the content is materially the same zones/tasks
    // Task view was just showing, so an abrupt swap reads as a
    // rendering glitch rather than a real content change. A one-shot
    // fade-in on first build reads as an intentional transition instead.
    // TweenAnimationBuilder, not AnimatedOpacity: there's no toggled
    // "target" opacity to react to after this, just a single play from 0
    // the moment this element is inserted into the tree — the pattern
    // `TaskCapsuleBlock` already uses for its own one-shot animations.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motionNormal,
      curve: Curves.easeOut,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: SingleChildScrollView(
        controller: _scrollController,
        // Vertical padding for the same reason `_DayTimeline` has it: every
        // hour label is centered ON its own tick line (TaskBoundaryMarkers'
        // -0.5 FractionalTranslation), so the labels at the range's first
        // and last ticks — both 00:00, now that the range is a full
        // calendar day — would otherwise be clipped at the scroll bounds.
        // Horizontal padding matches `_DayTimeline`'s own exactly
        // (spacingScreenPadding, not spacingMd — the two are different
        // token values) so switching between Task view and Zone view has no
        // horizontal jump. Reported directly.
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacingScreenPadding,
          vertical: theme.spacingLg,
        ),
        child: SizedBox(
          height: totalHeight,
          child: Stack(
            key: _stackKey,
            clipBehavior: Clip.none,
            children: [
              TaskBoundaryMarkers(
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                pixelsPerMinute: widget.pixelsPerMinute,
              ),
              // Read-only external calendar events (Feature 1) — same
              // background-layer treatment as the Task view's own
              // ExternalEventBlock usage, positioned on this view's real
              // outer time axis. Painted before zone containers/tasks so
              // those still visually sit on top if their times overlap.
              // Only events NOT already matched into a zone container
              // (see `outerAxisExternalEvents` above) — a matched event
              // renders inside its zone's row list instead, alongside its
              // member tasks, per the same containment rule a task uses.
              for (final event in outerAxisExternalEvents)
                ExternalEventBlock(
                  theme: theme,
                  event: event,
                  rangeStart: rangeStart,
                  pixelsPerMinute: widget.pixelsPerMinute,
                  left: _hourGutterWidth,
                  width:
                      MediaQuery.sizeOf(context).width -
                      _hourGutterWidth -
                      theme.spacingScreenPadding * 2,
                ),
              for (final containment in result.containments)
                _PositionedContainer(
                  theme: theme,
                  containment: containment,
                  categoriesById: widget.categoryById,
                  stackAncestorKey: _stackKey,
                  left: _hourGutterWidth,
                  top: topForZoneStart(containment.zone),
                  // Shrunk by zoneBackgroundGap — the same "always a gap,
                  // even back-to-back" rule ZoneBackgroundBlock already
                  // enforces on the Task view, reused here rather than a
                  // second value invented for this view. This is only a
                  // FLOOR: a genuinely overpacked short zone's real content
                  // still grows past it via IntrinsicHeight (confirmed
                  // directly — this container never clips a row), so the
                  // gap holds in the ordinary case and is allowed to
                  // collapse only when a zone truly has more tasks than fit.
                  strictHeight:
                      (containment.zone.endMinutes -
                              containment.zone.startMinutes) *
                          widget.pixelsPerMinute -
                      zoneBackgroundGap,
                  onTaskTap: widget.onTaskTap,
                  onToggleComplete: widget.onToggleComplete,
                  draggingTaskId: _draggingTaskId,
                  onRowDragStart: (task, restingTop) =>
                      _handleDragStart(task, restingTop: restingTop),
                  onDragUpdate: _handleDragUpdate,
                  onDragEnd: _handleDragEnd,
                  hoveredZoneId: _hoveredZoneId,
                  durationVisible: widget.devDurationVisible,
                  showCompletionCheckbox: widget.showCompletionCheckbox,
                ),
              for (final task in result.unzonedTasks)
                if (task.scheduledAt != null && task.durationMinutes != null)
                  Positioned(
                    key: ValueKey('unzoned-${task.id}'),
                    top: topFor(task.scheduledAt!),
                    left: _hourGutterWidth,
                    right: 0,
                    // Hidden via Opacity while dragging, NOT removed from
                    // the tree: this block owns the GestureDetector tracking
                    // the drag, so dropping it from the child list destroyed
                    // the active gesture on the first pointer move and left
                    // the floating copy stranded (reported directly as
                    // outside tasks freezing). Same always-present-tree rule
                    // `TaskCapsuleBlock` documents for its own conditional
                    // looks, and the same treatment the in-zone rows use.
                    child: Opacity(
                      opacity: task.id == _draggingTaskId ? 0.0 : 1.0,
                      child: TaskCapsuleBlock(
                        task: task,
                        category: task.categoryId == null
                            ? null
                            : widget.categoryById[task.categoryId],
                        pixelsPerMinute: widget.pixelsPerMinute,
                        // Unzoned tasks sit on the same real time axis as the
                        // Task view's own capsules and should read the same
                        // way — pill height scales with duration. Only
                        // IN-CONTAINER rows stay fixed-size (they already
                        // show duration as text at a fixed row height); this
                        // was previously forced to false for every outer-axis
                        // capsule including unzoned ones, reported directly
                        // as wrong.
                        durationIndicatedBySize: true,
                        textLayout: widget.devTextLayout,
                        iconsVisible: widget.devIconsVisible,
                        durationVisible: widget.devDurationVisible,
                        showCompletionCheckbox: widget.showCompletionCheckbox,
                        onTap: () => widget.onTaskTap(task),
                        onToggleComplete: () => widget.onToggleComplete(task),
                        onDragStart: (_) => _handleDragStart(task),
                        onDragUpdate: (details) =>
                            _handleDragUpdate(task, details),
                        onDragEnd: (_) => _handleDragEnd(task),
                      ),
                    ),
                  ),
              // LATE in the child list, deliberately — a Stack paints in
              // child-list order, so this has to come AFTER every zone
              // container and task capsule or those paint straight over the
              // "now" line and hide it. It was previously second (right
              // after TaskBoundaryMarkers), which is why the line was
              // reported missing from this view even though the widget was
              // present. Matches the Task view's own ordering, where
              // CurrentTimeIndicator likewise sits near the end.
              CurrentTimeIndicator(
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                pixelsPerMinute: widget.pixelsPerMinute,
                gutterWidth: _hourGutterWidth,
              ),
              // The single floating drag visual — covers BOTH an outer-axis
              // capsule mid-drag (hidden in place above via Opacity, still
              // mounted so its own gesture keeps tracking) and a row dragged
              // out of a container (which has no outer-axis slot of its own
              // to move in place). One shared visual keeps the two cases
              // from ever showing two different representations of the same
              // drag.
              if (_draggingTaskId != null) _floatingDragVisual(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _floatingDragVisual() {
    final draggingId = _draggingTaskId!;
    final rowTask = _draggingRowTask;
    final task = rowTask != null && rowTask.id == draggingId
        ? rowTask
        : widget.tasks.firstWhere((t) => t.id == draggingId);
    final restingTop = _restingTopFor(task);

    // The ONLY widget that rebuilds per pointer move — everything else in
    // this view stays put for the whole drag. See [_dragOffsetY].
    return ValueListenableBuilder<double>(
      valueListenable: _dragOffsetY,
      builder: (context, offsetY, child) => Positioned(
        // Follows the finger exactly (unsnapped) while the finger is
        // down, matching the Task view's own drag feel — only the TIME
        // LABEL reflects the snapped slot, which is what the drop
        // commits to.
        top: restingTop + offsetY,
        left: _hourGutterWidth,
        right: 0,
        child: IgnorePointer(
          child: TaskCapsuleBlock(
            task: task,
            category: task.categoryId == null
                ? null
                : widget.categoryById[task.categoryId],
            pixelsPerMinute: widget.pixelsPerMinute,
            // A row dragged out of a container stays fixed-size, matching
            // every in-container row; an outer-axis (unzoned) capsule
            // being dragged keeps scaling by duration, matching its own
            // resting size above — so the drag visual never changes size
            // out from under the task the moment a drag starts.
            durationIndicatedBySize: rowTask == null,
            textLayout: widget.devTextLayout,
            iconsVisible: widget.devIconsVisible,
            durationVisible: widget.devDurationVisible,
            showCompletionCheckbox: widget.showCompletionCheckbox,
            // Shows the time this drag would land on, live, instead of
            // the task's stale saved time — reported directly: the card's
            // own hours didn't track the drag. Same mechanism the Task
            // view already uses (`_DraggableTaskBlock._previewStartsAt`).
            dragPreviewStartsAt: _previewStartsAtFor(task),
            isLifted: true,
          ),
        ),
      ),
    );
  }
}

/// A single zone container positioned on the outer time axis, growing
/// past its strict time-span height when its own member rows need more
/// room than that — the container's header + padding + fixed-height rows
/// is measured by [LayoutBuilder]/intrinsic sizing (via [IntrinsicHeight])
/// rather than a hand-computed row count, so any future change to the
/// container's own header/padding automatically stays in sync with this
/// minimum-height floor.
class _PositionedContainer extends StatelessWidget {
  const _PositionedContainer({
    required this.theme,
    required this.containment,
    required this.categoriesById,
    required this.stackAncestorKey,
    required this.left,
    required this.top,
    required this.strictHeight,
    required this.onTaskTap,
    required this.onToggleComplete,
    required this.draggingTaskId,
    required this.onRowDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.hoveredZoneId,
    this.durationVisible = true,
    this.showCompletionCheckbox = true,
  });

  final AmbleTheme theme;
  final ZoneContainment containment;
  final Map<String, Category> categoriesById;
  final GlobalKey stackAncestorKey;
  final double left;
  final double top;

  /// Already shrunk by [zoneBackgroundGap] by the caller — the floor this
  /// container's [ConstrainedBox] enforces via `minHeight`.
  final double strictHeight;
  final ZoneTaskCallback onTaskTap;
  final ZoneTaskCallback onToggleComplete;

  final String? draggingTaskId;
  final void Function(Task task, double restingTop) onRowDragStart;
  final void Function(Task task, DragUpdateDetails details) onDragUpdate;
  final Future<void> Function(Task task) onDragEnd;

  /// The zone a drag would currently drop into — this container listens
  /// for just its own id, so only the highlighted/unhighlighted container
  /// rebuilds as a drag crosses zone boundaries.
  final ValueListenable<String?> hoveredZoneId;

  /// Dev-only toggle threaded straight through to [ZoneContainerBlock] —
  /// see its own doc comment for the full contract.
  final bool durationVisible;

  /// Threaded straight through to [ZoneContainerBlock] — see its own doc
  /// comment.
  final bool showCompletionCheckbox;

  @override
  Widget build(BuildContext context) {
    // Same insets ZoneBackgroundBlock applies on the Task view — reported
    // directly as a visible jump switching views, since a zone's container
    // previously sat exactly at its strict time/column position here but
    // inset on the Task view. [top]/[left] are already the STRICT position
    // (see the caller); this is the one place that applies the shared
    // inset, so both views render the same zone at the same pixel.
    //
    // `top` is the STRICT time position, unadjusted: a zone's top edge
    // lands exactly on its own start time, and the whole inter-zone gap
    // comes off the bottom instead — see ZoneBackgroundBlock's own
    // geometry comment for why (cusp precision, confirmed directly). The
    // horizontal -zoneBackgroundOffset is unchanged.
    return Positioned(
      top: top,
      left: left - zoneBackgroundOffset,
      right: zoneBackgroundGap,
      // No IntrinsicHeight: the container's own Column already sizes to
      // its content inside this minHeight floor, and an intrinsic pass
      // costs an EXTRA full layout of every row on every layout — which,
      // combined with the per-pointer-move rebuild this view used to do,
      // is what made dragging janky (reported directly).
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: strictHeight),
        child: ValueListenableBuilder<String?>(
          valueListenable: hoveredZoneId,
          builder: (context, hoveredId, child) => ZoneContainerBlock(
            theme: theme,
            zone: containment.zone,
            tasks: containment.tasks,
            externalEvents: containment.externalEvents,
            categoriesById: categoriesById,
            stackAncestorKey: stackAncestorKey,
            isDropTarget: hoveredId == containment.zone.id,
            onTaskTap: onTaskTap,
            onToggleComplete: onToggleComplete,
            draggingTaskId: draggingTaskId,
            onRowDragStart: onRowDragStart,
            onRowDragUpdate: onDragUpdate,
            // The resting top a row-originated drag needs is resolved
            // once, at drag START, by the row itself (see
            // `_ZoneTaskRow._handleDragStart`) and stored by
            // `_ZoneDayTimelineState` — `onDragEnd` reads it back from
            // there rather than needing it passed through here again.
            onRowDragEnd: onDragEnd,
            durationVisible: durationVisible,
            showCompletionCheckbox: showCompletionCheckbox,
          ),
        ),
      ),
    );
  }
}
