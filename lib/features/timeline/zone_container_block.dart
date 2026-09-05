import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../shared/models/category.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/models/zone.dart';
import '../task_detail/category_visual.dart';
import 'completion_checkbox.dart';
import 'duration_label.dart';
import 'external_event_block.dart' show showExternalCalendarEventInfo;

/// The minimum height a [ZoneContainerBlock] renders at even when its own
/// time span (per [Zone.startMinutes]/[Zone.endMinutes] at the outer
/// timeline's `pixelsPerMinute`) would be too short to fit its member
/// task rows without clipping. A short zone with several tasks inside it
/// still needs to show every row — per-row height is fixed (rows never
/// shrink to fit, matching the "no proportional sizing" rule below), so
/// the container itself grows to whatever its content actually needs
/// instead of clipping. Callers size the container as
/// `max(strict time-span height, minIntrinsicHeight)`.
const zoneContainerRowHeight = 44.0;

/// The Spatial Zone View's real layout container for one [Zone] — unlike
/// [ZoneBackgroundBlock] (the Spatial Task View's purely decorative
/// background treatment, unchanged by this widget), this genuinely owns
/// its child tasks' layout: a bounded region with the zone's title, total
/// duration, and time range in its header, and a flat list of member task
/// rows stacked inside — positioned relative to this container's own
/// coordinate frame, not the outer timeline's.
///
/// The inner row list deliberately mirrors `OverlapClusterBlock`'s
/// `_ClusterTaskRow` precedent, not `TaskCapsuleBlock`'s own pill: every
/// row is the SAME height regardless of the task's duration (no
/// proportional sizing), and the field order is start time -> duration ->
/// category glyph -> title — confirmed directly, and the reverse of the
/// capsule's own icon-first/time-below order.
class ZoneContainerBlock extends StatelessWidget {
  const ZoneContainerBlock({
    super.key,
    required this.theme,
    required this.zone,
    required this.tasks,
    this.externalEvents = const [],
    required this.categoriesById,
    required this.stackAncestorKey,
    this.isDropTarget = false,
    this.onTaskTap,
    this.onToggleComplete,
    this.draggingTaskId,
    this.onRowDragStart,
    this.onRowDragUpdate,
    this.onRowDragEnd,
    this.durationVisible = true,
    this.showCompletionCheckbox = true,
  });

  final AmbleTheme theme;
  final Zone zone;

  /// Read-only device-calendar events whose time falls inside this zone's
  /// window (see `ZoneContainment.externalEvents`/`resolveZoneContainment`)
  /// — rendered as their own rows inside this container's list, sorted
  /// together with [tasks] by time, per CONSTITUTION.md's "Calendar"
  /// section. Requested directly: "on zone mode tasks imported should be
  /// inside zones like other task[s]." Strictly read-only, same as every
  /// other `ExternalEventBlock`/Feature 1 usage — no checkbox, no drag, no
  /// edit; tapping a row still only opens the info sheet.
  final List<ExternalCalendarEvent> externalEvents;

  /// Dev-only toggle threaded straight through to each [_ZoneTaskRow] —
  /// see that widget's own doc comment for the full contract.
  final bool durationVisible;

  /// Whether each task row's trailing completion checkbox renders at all
  /// (`ShowCompletionCheckboxSetting`) — one setting spanning all three
  /// views. Never applies to [externalEvents]' own rows, which are
  /// read-only and carry no checkbox in the first place.
  final bool showCompletionCheckbox;

  /// Key on `ZoneDayTimeline`'s own outer Stack — a row resolves its
  /// current top RELATIVE TO THIS ancestor on drag start (see
  /// `_ZoneTaskRow`'s own doc comment), since that's the coordinate frame
  /// every `Positioned` drop-target/drag-visual calculation in
  /// `ZoneDayTimeline` is expressed in.
  final GlobalKey stackAncestorKey;

  /// This zone's member tasks, already resolved and ordered by
  /// `resolveZoneContainment` — this widget does no containment logic of
  /// its own.
  final List<Task> tasks;

  /// Resolved [Category] rows keyed by id, for the same reason
  /// `TaskCapsuleBlock.category` is passed in rather than looked up here:
  /// this is a plain `StatelessWidget` with no provider access. A task
  /// whose `categoryId` has no entry (null or unrecognised) falls back to
  /// [CategoryVisual]'s own null handling further down.
  final Map<String, Category> categoriesById;

  final ValueChanged<Task>? onTaskTap;
  final ValueChanged<Task>? onToggleComplete;

  /// The id of the row currently being dragged, if any — that row fades
  /// in place (same treatment `OverlapClusterBlock` gives a dragged
  /// member) while the actual moving visual is rendered by the caller
  /// (`ZoneDayTimeline`) on the outer Stack, since a dragged row has to
  /// move independently of this container's own bounded layout.
  /// True while a drag in progress would land inside THIS zone if
  /// released now — draws a border so it's visible which container the
  /// task is about to be assigned to (requested directly). False at rest,
  /// which is the ordinary borderless fill.
  final bool isDropTarget;

  final String? draggingTaskId;

  /// Fired with the row's own task and its CURRENT on-screen top, relative
  /// to the ancestor `ZoneDayTimeline`'s own Stack — resolved via
  /// `RenderBox.localToGlobal` against that ancestor at the moment the
  /// drag starts, since a row's position depends on the container's own
  /// (possibly grown-past-strict-height) layout and its index among
  /// sibling rows, neither of which this widget's caller can precompute.
  final void Function(Task task, double restingTop)? onRowDragStart;
  final void Function(Task task, DragUpdateDetails details)? onRowDragUpdate;
  final ValueChanged<Task>? onRowDragEnd;

  /// [tasks] and [externalEvents] merged into ONE chronological sequence —
  /// requested directly ("sorted together" — see the class's own doc
  /// comment). Both inputs already arrive pre-sorted by their own caller
  /// (`resolveZoneContainment`'s `_sortedByScheduledAt`/`_sortedByStart`);
  /// this only interleaves them by comparing each sequence's next start
  /// time, same merge shape as `computeCollapsedStackTops`
  /// (`collapsed_stack_layout.dart`) uses for the List-view equivalent of
  /// this exact problem. An unscheduled task (no `scheduledAt`) sorts
  /// after every real time, matching `_sortedByScheduledAt`'s own
  /// existing convention.
  List<Object> _mergedRows() {
    final rows = <Object>[];
    var taskIndex = 0;
    var eventIndex = 0;
    while (taskIndex < tasks.length || eventIndex < externalEvents.length) {
      final task = taskIndex < tasks.length ? tasks[taskIndex] : null;
      final event = eventIndex < externalEvents.length
          ? externalEvents[eventIndex]
          : null;
      final taskStart = task?.scheduledAt;
      final nextIsTask =
          event == null ||
          (task != null &&
              taskStart != null &&
              !taskStart.isAfter(event.start));
      if (nextIsTask) {
        rows.add(task!);
        taskIndex++;
      } else {
        rows.add(event);
        eventIndex++;
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final durationMinutes = zone.endMinutes - zone.startMinutes;

    return DecoratedBox(
      // Same fill, no outline, as ZoneBackgroundBlock's own treatment on
      // the Task view — confirmed directly: the reviewed reference was a
      // wireframe, not the final style, and Zone's rendered color should
      // stay consistent between the two views rather than diverge into a
      // second zone visual language.
      decoration: BoxDecoration(
        color: theme.colorZoneBackground,
        borderRadius: BorderRadius.circular(theme.radiusXl),
        // Only while this zone is the live drop target — the resting
        // state stays borderless (fill only), matching the Task view.
        border: isDropTarget
            ? Border.all(color: theme.colorTextPrimary, width: 2)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(theme: theme, zone: zone, durationMinutes: durationMinutes),
            SizedBox(height: theme.spacingSm),
            for (final (index, row) in _mergedRows().indexed) ...[
              if (index > 0) SizedBox(height: theme.spacingXs),
              if (row is Task)
                Opacity(
                  opacity: row.id == draggingTaskId ? 0.0 : 1.0,
                  child: _ZoneTaskRow(
                    // Keyed by task id so a rebuild mid-drag (the drag's
                    // own setState fires one on every pointer move)
                    // matches this row's element by TASK rather than by
                    // list position — the rows re-sort by time as a drag
                    // commits, and a position-matched element would hand
                    // the active gesture to whichever task happened to
                    // land on that index.
                    key: ValueKey(row.id),
                    theme: theme,
                    task: row,
                    category: row.categoryId == null
                        ? null
                        : categoriesById[row.categoryId],
                    onTap: onTaskTap == null ? null : () => onTaskTap!(row),
                    onToggleComplete: onToggleComplete == null
                        ? null
                        : () => onToggleComplete!(row),
                    stackAncestorKey: stackAncestorKey,
                    onDragStart: onRowDragStart,
                    onDragUpdate: onRowDragUpdate == null
                        ? null
                        : (details) => onRowDragUpdate!(row, details),
                    onDragEnd: onRowDragEnd == null
                        ? null
                        : (_) => onRowDragEnd!(row),
                    durationVisible: durationVisible,
                    showCompletionCheckbox: showCompletionCheckbox,
                  ),
                )
              else if (row is ExternalCalendarEvent)
                _ZoneExternalEventRow(
                  key: ValueKey(row.id),
                  theme: theme,
                  event: row,
                  durationVisible: durationVisible,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The container's header row: title + total duration on the left (e.g.
/// "Morning ritual (1h)"), the zone's own start-end time range right-
/// aligned on the same row — matching the reference layout exactly.
class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.zone,
    required this.durationMinutes,
  });

  final AmbleTheme theme;
  final Zone zone;
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    final start = TimeOfDay(
      hour: zone.startMinutes ~/ 60,
      minute: zone.startMinutes % 60,
    );
    final end = TimeOfDay(
      hour: zone.endMinutes ~/ 60,
      minute: zone.endMinutes % 60,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '${zone.title} (${formatDurationLabel(durationMinutes)})',
            // Not bold — confirmed directly: unlike a task title (which
            // is bold to read as the primary, actionable item), the zone
            // header is a label for the container itself, not a task, so
            // it stays at textTaskTitle's own regular weight. Grey
            // (colorTextSecondary), matching the time-range text on the
            // same row — reported directly: the title previously stood
            // out in colorTextPrimary while the time range next to it was
            // already grey. textTaskTitle, not textLabel directly — this
            // header's size is now the shared task-title base every
            // task-related label reads from (see AmbleTheme.textTaskTitle's
            // own doc comment: this header was the anchor those sizes
            // were confirmed against).
            style: theme.textTaskTitle.copyWith(
              color: theme.colorTextSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: theme.spacingSm),
        Text(
          '${start.format(context)} - ${end.format(context)}',
          style: theme.textCaption.copyWith(color: theme.colorTextSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// One task row inside a [ZoneContainerBlock] — start time, duration,
/// category glyph, then title, in that fixed order, at a fixed height
/// ([zoneContainerRowHeight]) regardless of the task's own duration.
/// Deliberately the reverse field order of `TaskCapsuleBlock`'s pill
/// (icon first, time/duration below) and deliberately non-proportional
/// (unlike the pill's duration-scaled height) — both confirmed directly
/// for this container's own inner list, distinct from the capsule.
class _ZoneTaskRow extends StatelessWidget {
  const _ZoneTaskRow({
    super.key,
    required this.theme,
    required this.task,
    required this.category,
    required this.onTap,
    required this.onToggleComplete,
    required this.stackAncestorKey,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.durationVisible = true,
    this.showCompletionCheckbox = true,
  });

  final AmbleTheme theme;
  final Task task;
  final Category? category;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;
  final GlobalKey stackAncestorKey;
  final void Function(Task task, double restingTop)? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  /// Dev-only toggle (Settings' Developer section,
  /// `DevTimelineTaskDurationVisibleProvider`) — matches
  /// `TaskCapsuleBlock.durationVisible`'s own contract exactly, threaded
  /// here so the Zone view's in-container rows respect the same setting
  /// its outer-axis (unzoned) task capsules already do. Defaults true so a
  /// caller that doesn't wire it up (a dev scaffold, a test) renders
  /// unchanged from before this parameter existed.
  final bool durationVisible;

  /// See [ZoneContainerBlock.showCompletionCheckbox].
  final bool showCompletionCheckbox;

  /// Resolves this row's own current top RELATIVE TO [stackAncestorKey],
  /// from the row's own [BuildContext] rather than a `GlobalKey` of its
  /// own.
  ///
  /// A `GlobalKey` created in this widget's constructor would be a NEW key
  /// on every rebuild — and since the drag's own `setState` rebuilds this
  /// row immediately, that tore the row's element down and recreated it
  /// mid-gesture, killing the active drag recognizer. Reported directly:
  /// dragging a row froze in place while the floating visual stayed
  /// lifted. Reading the context at drag-start time needs no key at all.
  void _handleDragStart(BuildContext context, DragStartDetails details) {
    final onDragStart = this.onDragStart;
    if (onDragStart == null) return;
    final rowBox = context.findRenderObject() as RenderBox?;
    final stackBox =
        stackAncestorKey.currentContext?.findRenderObject() as RenderBox?;
    if (rowBox == null || stackBox == null) return;
    final rowGlobalTop = rowBox.localToGlobal(Offset.zero).dy;
    final stackGlobalTop = stackBox.localToGlobal(Offset.zero).dy;
    onDragStart(task, rowGlobalTop - stackGlobalTop);
  }

  @override
  Widget build(BuildContext context) {
    final scheduledAt = task.scheduledAt;
    final durationMinutes = task.durationMinutes;

    // Matches TaskCapsuleBlock's own "start - end (duration)" format
    // exactly — requested directly, replacing this row's previous
    // start-time-only + separate-duration-chip display. `durationVisible`
    // (the dev-config toggle, see this row's own doc comment) still
    // decides whether the "(duration)" suffix appears at all, same
    // contract TaskCapsuleBlock already has.
    final String timeLabel;
    if (scheduledAt == null) {
      timeLabel = '--:--';
    } else if (durationMinutes == null) {
      timeLabel = TimeOfDay.fromDateTime(scheduledAt).format(context);
    } else {
      final startTime = TimeOfDay.fromDateTime(scheduledAt);
      final endTime = TimeOfDay.fromDateTime(
        scheduledAt.add(Duration(minutes: durationMinutes)),
      );
      timeLabel = durationVisible
          ? '${startTime.format(context)} - ${endTime.format(context)} '
                '(${formatDurationLabel(durationMinutes)})'
          : '${startTime.format(context)} - ${endTime.format(context)}';
    }

    final emoji = category?.emoji;
    // A real shared token now (theme.sizeTaskBadge, 20px) instead of the
    // old ad hoc `spacingXl * 0.9` (36px) mirrored from TaskCapsuleBlock —
    // requested directly ("circle should [be] smaller 20px... we need
    // config"). This row's badge is a genuinely separate small circle
    // (unlike TaskCapsuleBlock's own badgeSize, which IS the whole pill
    // shape and stays at its prior size — confirmed directly, not
    // touched by this change).
    final badgeSize = theme.sizeTaskBadge;

    return SizedBox(
      height: zoneContainerRowHeight,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Drag-to-reschedule is scoped to JUST the time/duration
            // column, never the whole row — the same reasoning
            // `TaskCapsuleBlock` scopes its own drag to the colored pill
            // alone: a full-width vertical-drag target fights the
            // timeline's own vertical scroll gesture in the arena, which
            // showed up as drags that intermittently froze or never
            // started at all (reported directly). Keeping the grip narrow
            // leaves the rest of the row free to scroll the day.
            // Flexible, not a fixed-width SizedBox: the combined
            // "start - end (duration)" string (matching TaskCapsuleBlock's
            // own format, requested directly) is far wider than the old
            // start-time-only label, and this row stays single-line/
            // fixed-height rather than growing to a second line (confirmed
            // directly) — so the time column gets a real but bounded share
            // of the row via `flex`, and ellipsizes rather than pushing
            // the title out entirely on a tight row.
            Flexible(
              flex: 2,
              child: GestureDetector(
                onTap: onTap,
                onVerticalDragStart: (details) =>
                    _handleDragStart(context, details),
                onVerticalDragUpdate: onDragUpdate,
                onVerticalDragEnd: onDragEnd,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  timeLabel,
                  style: theme.textTaskTitle.copyWith(
                    color: theme.colorTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: theme.spacingSm),
            if (emoji != null) ...[
              // Small colored circle badge behind the emoji — requested
              // directly, matching the small colored badge every task
              // pill already shows elsewhere (this view's own bare emoji
              // read as visually inconsistent with the rest of the app).
              // Uses the same iconColor this row's own completion
              // checkbox ring already resolves, rather than the pill's
              // own pale fill color, so the badge and the ring agree.
              // Sized to match — was noticeably smaller (spacingLg, 24px)
              // than the Task view's own badge (36px), reported directly.
              Container(
                width: badgeSize,
                height: badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: category == null
                      ? theme.colorTextSecondary
                      : resolveCategoryVisual(
                          theme: theme,
                          category: category!,
                        ).iconColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: badgeSize * 0.55),
                ),
              ),
              SizedBox(width: theme.spacingXs),
            ],
            // flex: 3 against the time column's flex: 2 — the title gets
            // the larger share of the row's remaining space, so a real
            // title still reads clearly even when the time label is at its
            // longest ("12:00 - 13:00 (3h 50m)").
            Expanded(
              flex: 3,
              child: Text(
                task.title,
                style: theme.textTaskTitle.copyWith(
                  color: theme.colorTextPrimary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Dropped from the Row when hidden
            // (`ShowCompletionCheckboxSetting`), reclaiming its space.
            // Safe to remove structurally, unlike TaskCapsuleBlock's own
            // copy: this row's drag gesture lives on the time column
            // above, and this checkbox is its sibling, not an ancestor —
            // so removing it can't disturb an in-flight drag's hit-test
            // ancestry.
            if (showCompletionCheckbox) ...[
              SizedBox(width: theme.spacingSm),
              CompletionCheckbox(
                theme: theme,
                // Fixed color (CompletionCheckbox's own default), not the
                // category's — see task_capsule_block.dart's own copy of
                // this reasoning. The row's own emoji badge above still
                // carries the category's color.
                isCompleted: task.status == TaskStatus.completed,
                onToggle: onToggleComplete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The read-only counterpart to [_ZoneTaskRow] for one
/// [ExternalCalendarEvent] whose time falls inside this zone's window —
/// see `ZoneContainerBlock.externalEvents`'s own doc comment. Same fixed
/// row height and time-then-title layout proportions as [_ZoneTaskRow]
/// (so the two read as one consistent list), but strictly read-only: no
/// completion checkbox, no drag, no category badge (an external event has
/// no Amble category) — tapping the row only opens the same read-only
/// info sheet [ExternalEventBlock] shows elsewhere
/// ([showExternalCalendarEventInfo]). The title renders in the muted
/// secondary color (not the bold primary color a real task's title
/// gets) — the same "must never look like an editable Amble object"
/// distinction `ExternalEventBlock` already makes visually elsewhere,
/// applied here so a glance down the merged row list can still tell the
/// two kinds of row apart even though they share one list now.
class _ZoneExternalEventRow extends StatelessWidget {
  const _ZoneExternalEventRow({
    super.key,
    required this.theme,
    required this.event,
    this.durationVisible = true,
  });

  final AmbleTheme theme;
  final ExternalCalendarEvent event;
  final bool durationVisible;

  @override
  Widget build(BuildContext context) {
    final startTime = TimeOfDay.fromDateTime(event.start);
    final endTime = TimeOfDay.fromDateTime(event.end);
    final durationMinutes = event.end.difference(event.start).inMinutes;
    final timeLabel = durationVisible
        ? '${startTime.format(context)} - ${endTime.format(context)} '
              '(${formatDurationLabel(durationMinutes)})'
        : '${startTime.format(context)} - ${endTime.format(context)}';

    return SizedBox(
      height: zoneContainerRowHeight,
      child: GestureDetector(
        onTap: () => showExternalCalendarEventInfo(
          context: context,
          theme: theme,
          event: event,
        ),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            // Same flex: 2 / flex: 3 time/title split as _ZoneTaskRow, so
            // the two row kinds visually line up in the merged list.
            Flexible(
              flex: 2,
              child: Text(
                timeLabel,
                style: theme.textTaskTitle.copyWith(
                  color: theme.colorTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: theme.spacingSm),
            Expanded(
              flex: 3,
              child: Text(
                event.title,
                // Secondary (muted), not the primary/bold weight a real
                // task's title gets — the visual signal that this row is
                // read-only/external, not an editable Amble task.
                style: theme.textTaskTitle.copyWith(
                  color: theme.colorTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
