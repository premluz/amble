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
import 'resize_handle.dart';

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
    this.timeRangeVisible = true,
    this.showCompletionCheckbox = true,
    this.editModeEnabled = false,
    this.onResizeTopStart,
    this.onResizeTopUpdate,
    this.onResizeTopEnd,
    this.onResizeBottomStart,
    this.onResizeBottomUpdate,
    this.onResizeBottomEnd,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.onHeaderTap,
    this.flatStyle = false,
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

  /// The List view "Show time (from-to)" dev toggle
  /// (`DevTimelineTaskTimeRangeVisible`) — requested directly: "Hide/show
  /// start end should also affect zone view." Independent of
  /// [durationVisible] (either, both, or neither can be on), threaded
  /// through to this container's own [_Header] and to every
  /// [_ZoneTaskRow]/[_ZoneExternalEventRow] it renders.
  final bool timeRangeVisible;

  /// Whether each task row's trailing completion checkbox renders at all
  /// (`ShowCompletionCheckboxSetting`) — one setting spanning all three
  /// views. Never applies to [externalEvents]' own rows, which are
  /// read-only and carry no checkbox in the first place.
  final bool showCompletionCheckbox;

  /// Whether Edit Mode is active — gates both resize handles' visibility.
  /// See `TaskCapsuleBlock.editModeEnabled`'s own doc comment for why this
  /// is a plain field rather than a Riverpod watch (this is a
  /// `StatelessWidget` with no provider access).
  final bool editModeEnabled;

  /// The TOP-edge handle's drag handlers — changes [Zone.startMinutes]
  /// only (the zone's end stays fixed). Null callbacks mean "no handle
  /// rendered here," matching [TaskCapsuleBlock.onResizeStart]'s own
  /// "null means not resizable" contract.
  final GestureDragStartCallback? onResizeTopStart;
  final GestureDragUpdateCallback? onResizeTopUpdate;
  final GestureDragEndCallback? onResizeTopEnd;

  /// The BOTTOM-edge handle's drag handlers — changes [Zone.endMinutes]
  /// only. A Zone (unlike a Task) gets handles at BOTH edges per
  /// CONSTITUTION.md, since either edge is independently a real thing to
  /// change (a Task has no equivalent "start" resize — its start is
  /// `scheduledAt`, a reschedule, not a resize).
  final GestureDragStartCallback? onResizeBottomStart;
  final GestureDragUpdateCallback? onResizeBottomUpdate;
  final GestureDragEndCallback? onResizeBottomEnd;

  /// Whole-block MOVE handlers — Edit Mode only, requested directly
  /// (reversing CONSTITUTION.md's earlier "zone reposition remains
  /// deferred" lock). Deliberately scoped to just the HEADER row (title/
  /// time/duration), not the whole container: matches how Task move is
  /// scoped to only its icon pill, avoiding a fight with this container's
  /// own row-list scroll/drag detectors underneath. Null callbacks mean
  /// "not movable here," same "null means not draggable" contract every
  /// other optional gesture in this codebase already uses.
  final GestureDragStartCallback? onMoveStart;
  final GestureDragUpdateCallback? onMoveUpdate;
  final GestureDragEndCallback? onMoveEnd;

  /// Taps the header. Two distinct callers, both still valid:
  /// - Task view's Edit Mode, multi-task route (`DevMultiTaskEditMode`):
  ///   selects this zone instead of moving it — mutually exclusive with
  ///   [onMoveEnd] at any one time (the caller never wires both together
  ///   for the same zone), matching `ZoneBackgroundBlock.onHeaderTap`'s
  ///   identical Task-view contract. Only reachable while [editModeEnabled]
  ///   is true, same as the resize/move handles.
  /// - The non-spatial Zone view (`ZoneDayTimeline`, **made non-spatial**:
  ///   requested directly, "current zone view make non spatial.. just list
  ///   of zones one by one"): the list is read-only outside of this tap —
  ///   no move, no resize — so this must fire regardless of
  ///   [editModeEnabled], which that caller always leaves false. Confirmed
  ///   directly: editing a zone's fields happens through
  ///   `showZoneFormScreen` from here instead.
  ///
  /// Gated behind `editModeEnabled` ONLY when a move/resize contract is
  /// also wired ([onMoveEnd] non-null) — the two cases above never overlap
  /// in practice (either both `onMoveEnd`/`onHeaderTap` under Edit Mode, or
  /// only `onHeaderTap` with `editModeEnabled: false` from the
  /// non-spatial list), so a bare `onHeaderTap` (no move contract) always
  /// fires the tap regardless of Edit Mode.
  final VoidCallback? onHeaderTap;

  /// The dev-only `DevZoneCardFlat` toggle — when true, strips this
  /// container's own background fill/border AND its padding, leaving just
  /// the bare title/duration header directly above its row list with no
  /// card chrome around either. See that provider's own doc comment for
  /// the full request. Defaults to false so every caller that doesn't
  /// wire it up (dev scaffolds, tests) renders unchanged from before this
  /// parameter existed.
  final bool flatStyle;

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

    // Wrapped in a Stack (a genuinely new, always-present ancestor, same
    // discipline as TaskCapsuleBlock's own resize-handle wrap) so the two
    // resize handles can overlay this container's top/bottom edges
    // without touching anything inside the DecoratedBox's own subtree —
    // in particular, never nested inside any row's own drag detector.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          // Same fill, no outline, as ZoneBackgroundBlock's own treatment on
          // the Task view — confirmed directly: the reviewed reference was a
          // wireframe, not the final style, and Zone's rendered color should
          // stay consistent between the two views rather than diverge into a
          // second zone visual language.
          //
          // Plain, non-colored surface as of 2026-09-10 — matches the Zone
          // list row (Settings → Manage → Zones) and the Tracked behavior
          // card, requested directly: "the zone card make the color of the
          // card [same as] on manage... as card on tracked... non colored."
          // Was `colorZoneBackground`, a distinct zone-tint fill.
          //
          // [flatStyle] (DevZoneCardFlat) drops the fill entirely —
          // requested directly: "removes the background from zones."
          // The drop-target border stays regardless (still functionally
          // meaningful feedback, not decorative chrome), so it's the ONE
          // thing this decoration always keeps.
          decoration: BoxDecoration(
            color: flatStyle ? null : theme.colorSurfaceSecondary,
            borderRadius: BorderRadius.circular(theme.radiusXl),
            // Only while this zone is the live drop target — the resting
            // state stays borderless (fill only), matching the Task view.
            border: isDropTarget
                ? Border.all(color: theme.colorTextPrimary, width: 2)
                : null,
          ),
          child: Padding(
            // [flatStyle] drops the padding too — requested directly:
            // "padding as well[;] so what's left is a title... and
            // underneath the tasks."
            // No RIGHT padding: the trailing completion checkbox has to
            // line up with the checkbox on a task row that sits OUTSIDE a
            // zone, and those rows are inset only by the page padding.
            // Reported directly — a nested checkbox sat 40px from the
            // screen edge (24 page + 16 card) against a standalone one's
            // 24px, which is the "checkbox not right" regression in Zone
            // view. The row itself supplies the breathing room its own
            // trailing edge needs.
            padding: flatStyle
                ? EdgeInsets.zero
                : EdgeInsets.fromLTRB(
                    theme.spacingMd,
                    theme.spacingMd,
                    0,
                    theme.spacingMd,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Edit Mode only — outside it the header is a plain,
                // non-interactive label, matching the resize handles'
                // own Edit-Mode gating. `HitTestBehavior.opaque` so the
                // whole header row (including the empty space beside the
                // text) is a drag surface, not just the text glyphs.
                // `onTap`/`onVerticalDrag*` are mutually exclusive per
                // the caller's own contract (see `onHeaderTap`'s doc
                // comment) — never both wired for the same zone at once.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // See [onHeaderTap]'s own doc comment: gated behind Edit
                  // Mode only when a move contract also exists (Task
                  // view's multi-task select/move split) — the non-spatial
                  // Zone view wires ONLY onHeaderTap, with no move
                  // contract and editModeEnabled always false, and must
                  // still fire.
                  onTap: onMoveStart == null || editModeEnabled
                      ? onHeaderTap
                      : null,
                  onVerticalDragStart: editModeEnabled ? onMoveStart : null,
                  onVerticalDragUpdate: editModeEnabled ? onMoveUpdate : null,
                  onVerticalDragEnd: editModeEnabled ? onMoveEnd : null,
                  child: _Header(
                    theme: theme,
                    zone: zone,
                    durationMinutes: durationMinutes,
                    timeRangeVisible: timeRangeVisible,
                  ),
                ),
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
                        timeRangeVisible: timeRangeVisible,
                        showCompletionCheckbox: showCompletionCheckbox,
                        flatStyle: flatStyle,
                      ),
                    )
                  else if (row is ExternalCalendarEvent)
                    _ZoneExternalEventRow(
                      key: ValueKey(row.id),
                      theme: theme,
                      event: row,
                      durationVisible: durationVisible,
                      timeRangeVisible: timeRangeVisible,
                    ),
                ],
              ],
            ),
          ),
        ),
        // Top-edge handle — changes Zone.startMinutes only. Rendered
        // ABOVE the container's own top edge (negative offset), same
        // "handle sits just outside the block it resizes" placement
        // TaskCapsuleBlock's bottom handle uses.
        if (editModeEnabled && onResizeTopEnd != null)
          Positioned(
            top: -theme.spacingXs,
            left: 0,
            right: 0,
            child: ResizeHandle(
              theme: theme,
              onDragStart: onResizeTopStart,
              onDragUpdate: onResizeTopUpdate,
              onDragEnd: onResizeTopEnd,
            ),
          ),
        // Bottom-edge handle — changes Zone.endMinutes only.
        if (editModeEnabled && onResizeBottomEnd != null)
          Positioned(
            bottom: -theme.spacingXs,
            left: 0,
            right: 0,
            child: ResizeHandle(
              theme: theme,
              onDragStart: onResizeBottomStart,
              onDragUpdate: onResizeBottomUpdate,
              onDragEnd: onResizeBottomEnd,
            ),
          ),
      ],
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
    this.timeRangeVisible = true,
  });

  final AmbleTheme theme;
  final Zone zone;
  final int durationMinutes;

  /// The List view "Show time (from-to)" dev toggle
  /// (`DevTimelineTaskTimeRangeVisible`) — requested directly: "Hide/show
  /// start end should also affect zone view." Hides ONLY this header's own
  /// `start - end` time range; the title's own `(duration)` suffix is a
  /// separate concept and stays regardless, unaffected by this toggle
  /// (same split [_ZoneTaskRow]/[_ZoneExternalEventRow] make between their
  /// own time range and duration pieces).
  final bool timeRangeVisible;

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
            // No parentheses around the duration — requested directly:
            // "remove brackets from duration in zone names."
            '${zone.title} ${formatDurationLabel(durationMinutes)}',
            // Not bold — confirmed directly: unlike a task title (which
            // is bold to read as the primary, actionable item), the zone
            // header is a label for the container itself, not a task, so
            // it stays at textTaskTitleZone's own regular weight.
            //
            // colorTextTertiary, not colorTextSecondary — requested
            // directly ("make zone names even subtler color"). The
            // time-range text beside it moves to the same tertiary color
            // rather than staying on secondary, preserving the earlier
            // confirmed pairing ("matching the time-range text on the same
            // row" — the two were deliberately made to match once already;
            // this keeps them matching at the new, subtler value).
            //
            // textTaskTitleZone, not textTaskTitle — requested directly
            // ("Size of text in zone view (task name one scale up)"),
            // reversing an earlier decision that Zone view's rows/header
            // track the Task-size setting with no relative step. Every
            // textTaskTitle use in this whole file moved to this token
            // together — the task row's time/title AND the read-only
            // external-event row's own time/title, since those two row
            // kinds are built to visually line up in the merged list.
            style: theme.textTaskTitleZone.copyWith(
              color: theme.colorTextTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (timeRangeVisible) ...[
          SizedBox(width: theme.spacingSm),
          Text(
            '${start.format(context)} - ${end.format(context)}',
            style: theme.textCaption.copyWith(color: theme.colorTextTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
    this.timeRangeVisible = true,
    this.showCompletionCheckbox = true,
    this.flatStyle = false,
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

  /// The `DevZoneCardFlat` dev toggle — when true, wraps this row in its
  /// own card (`theme.colorSurfaceSecondary` fill, `theme.radiusXl`
  /// corners), matching the "Manage" screens' own row style (e.g.
  /// `ZoneListScreen`'s `_ZoneRow`). Requested directly: "tasks should be
  /// in 'card' like they are in manage (but keep size of them as they are
  /// in zone view atm)" — the card adds NO internal padding of its own
  /// (confirmed directly, over growing the row taller to fit Manage's own
  /// `spacingMd` padding): content stays pixel-identical to the bare row,
  /// only a card background appears behind it, still constrained to the
  /// same fixed [zoneContainerRowHeight]. Only applied in flat style —
  /// confirmed directly — since normal style already has the zone's own
  /// container card as the visual wrapper; double-carding there would be
  /// redundant.
  final bool flatStyle;

  /// Dev-only toggle (Settings' Developer section,
  /// `DevTimelineTaskDurationVisibleProvider`) — matches
  /// `TaskCapsuleBlock.durationVisible`'s own contract exactly, threaded
  /// here so the Zone view's in-container rows respect the same setting
  /// its outer-axis (unzoned) task capsules already do. Defaults true so a
  /// caller that doesn't wire it up (a dev scaffold, a test) renders
  /// unchanged from before this parameter existed.
  final bool durationVisible;

  /// The "Show time (from-to)" dev toggle
  /// (`DevTimelineTaskTimeRangeVisibleProvider`) — requested directly:
  /// "Hide/show start end should also affect zone view." Independent of
  /// [durationVisible], same contract as `TaskCapsuleTextRow.timeRangeVisible`.
  /// Defaults true so a caller that doesn't wire it up renders unchanged
  /// from before this parameter existed.
  final bool timeRangeVisible;

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
    // start-time-only + separate-duration-chip display. `timeRangeVisible`
    // and `durationVisible` are two independent pieces (either, both, or
    // neither can be on) — requested directly: "Hide/show start end should
    // also affect zone view," matching TaskCapsuleTextRow's own contract.
    final String timeLabel;
    if (!timeRangeVisible) {
      timeLabel = durationVisible && durationMinutes != null
          ? '(${formatDurationLabel(durationMinutes)})'
          : '';
    } else if (scheduledAt == null) {
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
    // **2026-09-12 — back to theme.sizeTaskBadge, and shrunk further still
    // by moving off sizeTaskBadgeXl.** Requested directly, this time:
    // "the emoji and circle... smaller" and "make actually same shape as
    // timeline" — `theme.sizeTaskBadge` is the SAME active, resolved size
    // TaskCapsuleBlock's own pill rail already uses (see its own
    // `badgeSize` at task_capsule_block.dart), so this row now matches the
    // Task view's badge in both size and shape rather than being enlarged
    // and circular on its own separate scale. An earlier session went the
    // other direction (this comment used to explain the enlargement to
    // sizeTaskBadgeXl) — reversed by this session's own direct request.
    final badgeSize = theme.sizeTaskBadge;

    return SizedBox(
      height: zoneContainerRowHeight,
      child: DecoratedBox(
        // Flat style only — see [flatStyle]'s own doc comment. Plain
        // BoxDecoration() (no color/radius) is the same visual no-op the
        // row always had, so this never affects normal style at all.
        decoration: flatStyle
            ? BoxDecoration(
                color: theme.colorSurfaceSecondary,
                borderRadius: BorderRadius.circular(theme.radiusXl),
              )
            : const BoxDecoration(),
        child: GestureDetector(
          onTap: onTap,
          // Fallback drag handle for the one combination with nowhere else
          // to put it: time hidden AND no category (an uncategorised task
          // has no badge at all — `emoji` is null, so the badge-level drag
          // handle below never renders either). Whole-row drag here is
          // exactly what the time-column comment below says to avoid
          // (fighting the Timeline's vertical scroll), but only for this
          // narrow, uncommon combination — every other state keeps its
          // narrow handle.
          onVerticalDragStart: (timeLabel.isEmpty && emoji == null)
              ? (details) => _handleDragStart(context, details)
              : null,
          onVerticalDragUpdate: (timeLabel.isEmpty && emoji == null)
              ? onDragUpdate
              : null,
          onVerticalDragEnd: (timeLabel.isEmpty && emoji == null)
              ? onDragEnd
              : null,
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
              // `Flexible` is loose, but a `GestureDetector` has no
              // intrinsic width of its own, so it expanded to the full 2/5
              // share regardless — measured on an 800px row, this column
              // occupied 221px for an ~88px string, and that surplus is
              // exactly what stranded the checkbox mid-row. `IntrinsicWidth`
              // holds the column to the width its text actually needs,
              // while `Flexible` still caps it (so a long
              // "9:00 - 12:50 (3h 50m)" ellipsizes rather than pushing the
              // title out). The freed slack falls to the trailing `Spacer`,
              // which is what pins the checkbox to the row's right edge.
              //
              // Collapsed entirely (`SizedBox.shrink`) when there's no time
              // text to show — reported directly: with time/duration both
              // hidden, `timeLabel` is `''`, but the empty `Text` inside
              // `IntrinsicWidth` still measured ~23px (line-height/padding
              // don't vanish just because the string is empty), plus the
              // trailing gap below, so the badge sat 31px in instead of
              // flush with the zone name above it. Drag-to-reschedule moves
              // to the badge itself in this case (see below) — per direct
              // instruction ("drag should be pill only") — rather than
              // leaving a dead invisible strip just to keep a hit target.
              if (timeLabel.isNotEmpty) ...[
                Flexible(
                  flex: 2,
                  child: IntrinsicWidth(
                    child: GestureDetector(
                      onTap: onTap,
                      onVerticalDragStart: (details) =>
                          _handleDragStart(context, details),
                      onVerticalDragUpdate: onDragUpdate,
                      onVerticalDragEnd: onDragEnd,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        timeLabel,
                        style: theme.textTaskTitleZone.copyWith(
                          color: theme.colorTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: theme.spacingSm),
              ],
              if (emoji != null) ...[
                // Small colored rounded-square badge behind the emoji —
                // requested directly, matching the badge every task pill
                // already shows elsewhere (this view's own bare emoji
                // read as visually inconsistent with the rest of the app).
                // Uses the same iconColor this row's own completion
                // checkbox ring already resolves, rather than the pill's
                // own pale fill color, so the badge and the ring agree.
                // Sized and shaped to match `badgeSize`'s own comment
                // above — the SAME `theme.sizeTaskBadge` and `radiusSm`
                // TaskCapsuleBlock's own pill rail uses, not a separate
                // enlarged circle.
                //
                // Carries the drag-to-reschedule gesture ONLY when the time
                // column above is gone (see its own comment) — with a
                // visible time label, the time column keeps that job
                // unchanged, exactly as before.
                GestureDetector(
                  // No `onTap` here — the outer row-level `GestureDetector`
                  // (this whole `_ZoneTaskRow`'s own build wrapper) already
                  // handles taps everywhere on the row, tap included; only
                  // the DRAG gesture needs a home when the time column is
                  // gone, since drag must stay narrow (not span the whole
                  // row) or it fights the Timeline's own vertical scroll —
                  // same reasoning the time column's own doc comment gives.
                  onVerticalDragStart: timeLabel.isEmpty
                      ? (details) => _handleDragStart(context, details)
                      : null,
                  onVerticalDragUpdate: timeLabel.isEmpty ? onDragUpdate : null,
                  onVerticalDragEnd: timeLabel.isEmpty ? onDragEnd : null,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
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
                      // radiusSm, not BoxShape.circle — requested directly
                      // ("make actually same shape as timeline, not
                      // circle but rounded square"). Matches
                      // TaskCapsuleBlock's own pill rail exactly (see its
                      // own borderRadius comment for why radiusSm rather
                      // than a fully-round radiusTaskPill was chosen
                      // there).
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                    ),
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: badgeSize * 0.55),
                    ),
                  ),
                ),
                // spacingSm, not spacingXs — matches the gap between the
                // pill and the title text for a task OUTSIDE a zone
                // (TaskCapsuleBlock's own `SizedBox(width:
                // textCollapsed ? 0 : theme.spacingSm)`). Requested
                // directly: "add larger gap between 'pill' and name in
                // tasks inside zones... same gap as in tasks outside
                // zones."
                SizedBox(width: theme.spacingSm),
              ],
              // `Expanded`: the title takes ALL the row's leftover width,
              // which both left-aligns it against the badge and pushes the
              // trailing checkbox to the right edge — one widget doing the
              // job the title/Spacer pair was doing badly. An earlier fix
              // paired `Flexible(flex: 3)` with a `Spacer(flex: 100)` to
              // pin the checkbox; that worked for the checkbox but starved
              // the title to ~7px, so task names disappeared entirely
              // (reported directly: "Cant see task names on zone view").
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTaskTitleZone.copyWith(
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
    this.timeRangeVisible = true,
  });

  final AmbleTheme theme;
  final ExternalCalendarEvent event;
  final bool durationVisible;

  /// See [ZoneContainerBlock.timeRangeVisible]. Independent of
  /// [durationVisible] — requested directly: "Hide/show start end should
  /// also affect zone view." Unlike List view's own imported-event rows
  /// (which never show time/duration at all regardless of either toggle —
  /// see `_ClusterEventRow`'s own doc comment), Zone view's event rows
  /// were never scoped out of that decision and keep respecting both
  /// toggles normally.
  final bool timeRangeVisible;

  @override
  Widget build(BuildContext context) {
    final startTime = TimeOfDay.fromDateTime(event.start);
    final endTime = TimeOfDay.fromDateTime(event.end);
    final durationMinutes = event.end.difference(event.start).inMinutes;
    final timeRange = timeRangeVisible
        ? '${startTime.format(context)} - ${endTime.format(context)}'
        : null;
    final durationLabel = durationVisible
        ? '(${formatDurationLabel(durationMinutes)})'
        : null;
    final timeLabel = [?timeRange, ?durationLabel].join(' ');

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
                style: theme.textTaskTitleZone.copyWith(
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
                style: theme.textTaskTitleZone.copyWith(
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
