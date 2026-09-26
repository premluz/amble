import '../../core/widgets/what_matters_motion.dart';

import 'package:flutter/material.dart';

import '../../core/tokens/semantic_theme.dart';
import '../../core/widgets/app_swipe_actions.dart';
import '../../shared/models/category.dart';
import '../../shared/models/external_calendar_event.dart';
import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/models/zone.dart';
import '../task_detail/category_visual.dart';
import 'completion_checkbox.dart';
import 'duration_label.dart';
import 'external_event_block.dart' show showExternalCalendarEventInfo;
import 'external_event_capsule_block.dart' show DashedPillRail;
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

/// The exact "start - end (duration)" text a Zone view row shows for one
/// task's schedule — factored out of [_ZoneTaskRow]'s own build method so
/// [ZoneDayTimeline]'s unzoned-task rows can render an identical leading
/// time column (same format, same three independent toggles) rather than
/// duplicating this logic. See [_ZoneTaskRow]'s own former inline comment
/// for the toggle-priority reasoning this preserves unchanged:
/// `startTimeOnlyVisible` wins outright over `timeRangeVisible`/
/// `durationVisible` when more than one is set.
String zoneTaskTimeLabel(
  BuildContext context, {
  required DateTime? scheduledAt,
  required int? durationMinutes,
  required bool timeRangeVisible,
  required bool durationVisible,
  required bool startTimeOnlyVisible,
}) {
  if (startTimeOnlyVisible) {
    return scheduledAt == null
        ? '--:--'
        : TimeOfDay.fromDateTime(scheduledAt).format(context);
  }
  if (!timeRangeVisible) {
    return durationVisible && durationMinutes != null
        ? '(${formatDurationLabel(durationMinutes)})'
        : '';
  }
  if (scheduledAt == null) return '--:--';
  if (durationMinutes == null) {
    return TimeOfDay.fromDateTime(scheduledAt).format(context);
  }
  final startTime = TimeOfDay.fromDateTime(scheduledAt);
  final endTime = TimeOfDay.fromDateTime(
    scheduledAt.add(Duration(minutes: durationMinutes)),
  );
  return durationVisible
      ? '${startTime.format(context)} - ${endTime.format(context)} '
            '(${formatDurationLabel(durationMinutes)})'
      : '${startTime.format(context)} - ${endTime.format(context)}';
}

/// The reserved on-screen distance a [ZoneRowTimeLabel]'s text sits from
/// the TRUE screen edge — 16px, matching the spatial Task view's own hour
/// labels EXACTLY (`TaskBoundaryMarkers`, called from `timeline_screen.dart`
/// with `leftInset: theme.spacingSm` (8) plus that widget's own further
/// `theme.spacingSm` (8) internal text padding — 8 + 8 = 16). Kept as one
/// named constant, not a scattered `spacingSm * 2` at each caller, so both
/// this file and `zone_day_timeline.dart` read from the identical value.
///
/// **Must equal [AmbleTheme.spacingScreenPadding].** This is the hour
/// label's distance from the true screen edge, and the spatial view puts
/// its own labels at exactly that token — so the two views only line up
/// while these agree. A top-level `const` cannot read the theme, so the
/// equality is pinned by `horizontal_spacing_system_test.dart` instead of
/// being expressible in the type system.
///
/// See docs/DESIGN_SYSTEM.md's "Horizontal spacing" section for the rule,
/// and its "Zone row hour label" section for the full reasoning behind
/// this widget's existence and shape.
const zoneRowTimeLabelEdgeInset = 16.0;

/// The horizontal space a [ZoneRowTimeLabel] reserves in its caller's own
/// `Row`.
///
/// **2026-09-20 — 66 → 0.** Clarified directly: the hour LABELS and the
/// zone-card left edge stay aligned between the spatial and zone views
/// (that's [zoneContentLeftInset]'s job, unchanged), but where a task
/// starts INSIDE its zone is independent of the spatial view — "tasks sit
/// in containers with the same left padding as top (so small space)."
/// This box used to mirror the spatial view's own 66px hour gutter,
/// pushing a zone row's badge a further 66px right of the card's own
/// `spacingMd` padding, so tasks sat nowhere near the card's left edge.
///
/// Zero works because the label text does not live in this box at all —
/// it escapes to [zoneRowTimeLabelEdgeInset] via a negative
/// `Positioned.left` (see [ZoneRowTimeLabel]'s class doc comment), so
/// nothing needs to hold space for it. A task now begins at the card's
/// own `spacingMd` left padding, matching its `spacingMd` top padding;
/// unzoned rows reach that same x by their own matching inset, just with
/// no card drawn around them.
const zoneRowTimeLabelReservedWidth = 0.0;

/// How far from the TRUE screen edge Zone view's own content (a zone
/// card, an unzoned row) starts — matching the spatial Task view's own
/// column 2 (`AmbleTheme.timelineZoneLeft`), since the non-spatial view
/// has no separate pill-lane column of its own: one card IS this view's
/// zone-plus-content, merged.
///
/// Requested directly against a screenshot with two guide lines drawn
/// from the spatial view: "the left line is the left edge of the hour in
/// the day timeline, the second line is the left edge of the position of
/// the zone. It's obviously misaligned." Zone view previously started its
/// cards at just the page inset, with no time-column width reserved at
/// all, well left of where the spatial view's zone band begins.
///
/// The [ZoneRowTimeLabel]s inside those rows still escape back out to
/// [zoneRowTimeLabelEdgeInset], the same position the spatial view's own
/// hour labels sit at — so the two views agree on both guide lines, not
/// just the label one.
///
/// **2026-09-23 — reads [AmbleTheme.timelineZoneLeft], not a frozen
/// constant.** Rebuilt on the three-column contract (see
/// `TimelineColumns`'s own doc comment in `semantic_theme.dart` for the
/// full history of why the old hardcoded value stopped decomposing into
/// anything real once the underlying tokens changed) — a top-level
/// function, not a `const double`, since [AmbleTheme] isn't available at
/// compile time. `test/core/tokens/horizontal_spacing_system_test.dart`
/// pins the two views' agreement at every viewport width.
double zoneContentLeftInset(AmbleTheme theme, [BuildContext? context]) =>
    context == null
    ? theme.timelineZoneLeft
    : theme.timelineZoneLeftFor(context);

/// Zone view's own hour label — the leading time text on a task row
/// (zoned via [_ZoneTaskRow], or unzoned via `ZoneDayTimeline`'s own
/// unzoned-task row) — styled and positioned to read as the SAME element
/// as the spatial Task view's [zoneRowTimeLabelEdgeInset]-inset hour
/// labels, even though the two views can't share the same LAYOUT
/// mechanism to get there.
///
/// **Why not just reuse `TaskBoundaryMarkers` directly**: that widget
/// [Positioned]s its labels against ONE shared, continuous, absolutely-
/// positioned `Stack` spanning the whole day — every task block in the
/// spatial Task view is a sibling in that same `Stack`, all keyed to one
/// `pixelsPerMinute` coordinate space. Zone view has no such shared space:
/// its rows are children of a `ListView.separated`, flowing one after
/// another with no absolute Y a label could be `Positioned` against
/// (and nested arbitrarily inside a zone card's own `Padding`, unlike the
/// spatial view's flat Stack). A [Positioned] escaping to the literal
/// screen edge would require one `Stack` spanning the ENTIRE scrolling
/// list — but a label `Positioned` there wouldn't scroll WITH its own
/// row, only sit fixed relative to the viewport, which is wrong for a
/// per-row label.
///
/// **What this widget does instead**: a small `Stack` scoped to just this
/// ONE row, with the label `Positioned` at a NEGATIVE `left` reaching
/// back out through whatever padding this specific row sits inside
/// (passed in as [leftPaddingToEscape]) to land at the same
/// [zoneRowTimeLabelEdgeInset] the spatial view's labels sit at. This
/// scrolls correctly (it's still an ordinary descendant of the row, which
/// is itself an ordinary list item) while reaching visually all the way
/// to the screen edge — the closest a per-row, list-flowed layout can get
/// to genuinely sharing the spatial view's own [Positioned] mechanism,
/// rather than faking the end position with `Transform.translate` (the
/// widget this replaces — see docs/ERROR_LOG.md's entry on why a negative
/// `Container(margin:)` broke this row's own `IntrinsicWidth` outright).
///
/// [reservedWidth] still occupies real space in the row's own `Row` (via
/// [SizedBox]) — the label's own `Positioned` doesn't participate in that
/// row's layout at all, so something still has to hold the gap between
/// the escaped label and whatever comes after it (the category badge, or
/// the title).
class ZoneRowTimeLabel extends StatelessWidget {
  const ZoneRowTimeLabel({
    super.key,
    required this.theme,
    required this.text,
    required this.leftPaddingToEscape,
    required this.reservedWidth,
  });

  final AmbleTheme theme;
  final String text;

  /// How far LEFT of this row's own left edge the true screen edge sits —
  /// i.e. every padding layer between this row and the screen, summed.
  /// The label is pulled back out by exactly this much via a negative
  /// `Positioned.left`, landing at [zoneRowTimeLabelEdgeInset] regardless
  /// of how deep this specific row happens to be nested.
  final double leftPaddingToEscape;

  /// The horizontal space this widget claims in its caller's own `Row` —
  /// callers size this to whatever gap they want between the escaped
  /// label and the next element (the category badge/title), independent
  /// of the label text's own (now off-layout) width.
  final double reservedWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: reservedWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: zoneRowTimeLabelEdgeInset - leftPaddingToEscape,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                text,
                // `textTaskEdgeTime` keeps task start/time text at the same
                // compact scale as spatial and Edit edge labels. The
                // hour-axis labels themselves remain `textCaptionMono`.
                style: theme.textTaskEdgeTime.copyWith(
                  color: theme.colorTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    this.onAddNote,
    this.draggingTaskId,
    this.onRowDragStart,
    this.onRowDragUpdate,
    this.onRowDragEnd,
    this.durationVisible = true,
    this.timeRangeVisible = true,
    this.startTimeOnlyVisible = false,
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
    this.whatMattersEnabled = false,
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

  /// The "Show start time" dev toggle (`DevZoneTaskStartTimeVisible`) —
  /// requested directly: "add control show time Start time (zone view),
  /// this will add task start time only." Threaded to every [_ZoneTaskRow]
  /// ONLY (confirmed via AskUserQuestion) — this container's own [_Header]
  /// and [_ZoneExternalEventRow] are unaffected, keeping their existing
  /// [timeRangeVisible] behavior regardless of this toggle.
  final bool startTimeOnlyVisible;

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

  /// The "What Matters" lens — a real user setting, not a dev toggle. Each
  /// member [_ZoneTaskRow] with `task.isImportant == false` fades and
  /// collapses via [WhatMattersRow] when this is true, rather than being
  /// filtered out of [tasks] before it reaches this widget.
  final bool whatMattersEnabled;

  // No TagColorStyle field here — see `_ZoneTaskRow`'s own doc comment on
  // why its badge (the only category-colored surface this container
  // renders) has nothing for that setting to switch between.

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

  /// Swipe-right action for each [_ZoneTaskRow] — mirrors
  /// `ZoneDayTimeline`'s own unzoned-row wiring
  /// (`onAddNote: () => showAddTaskNoteSheet(context, row)`). Requested
  /// directly: "wire for zoned" (swipe-to-reveal, previously scoped out
  /// for tasks inside a zone container — see docs/DECISIONS.md).
  final ValueChanged<Task>? onAddNote;

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
            //
            // LEFT is `spacingLg` (24), not `spacingMd` (16) — widened
            // one rung up the spacing scale, requested directly against a
            // two-view annotated screenshot: the gap between the card's
            // own outer edge and its first pill lane read as visibly
            // missing/too thin against the spatial view's own equivalent
            // gap (zone band edge to first pill), which this card is
            // meant to match.
            padding: flatStyle
                ? EdgeInsets.zero
                : EdgeInsets.fromLTRB(
                    theme.spacingLg,
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
                  // `SizedBox(width: double.infinity)`, not `_Header`
                  // directly — the parent `Column` uses `CrossAxisAlignment
                  // .start`, which gives every child LOOSE (not tight)
                  // width constraints, so `_Header`'s own `Row` had no real
                  // width to divide its `Expanded` title against and could
                  // overflow instead of ellipsizing. Surfaced directly by
                  // widening this card's own left padding (`spacingMd` ->
                  // `spacingLg`, above) trimmed just enough available width
                  // to tip a short title + time-range combination over —
                  // this fixes the underlying missing-width-constraint,
                  // not just that one padding change.
                  child: SizedBox(
                    width: double.infinity,
                    child: _Header(
                      theme: theme,
                      zone: zone,
                      durationMinutes: durationMinutes,
                      timeRangeVisible: timeRangeVisible,
                    ),
                  ),
                ),
                SizedBox(height: theme.spacingSm),
                for (final (index, row) in _mergedRows().indexed) ...[
                  if (index > 0) SizedBox(height: theme.spacingXs),
                  if (row is Task)
                    // Keyed by task id (moved onto this outer
                    // WhatMattersRow wrapper, above _ZoneTaskRow) so a
                    // rebuild mid-drag (the drag's own setState fires one
                    // on every pointer move) matches this row's element
                    // by TASK rather than by list position — the rows
                    // re-sort by time as a drag commits, and a position-
                    // matched element would hand the active gesture to
                    // whichever task happened to land on that index.
                    WhatMattersRow(
                      key: ValueKey(row.id),
                      theme: theme,
                      hidden: whatMattersEnabled && !row.isImportant,
                      child: Opacity(
                        opacity: row.id == draggingTaskId ? 0.0 : 1.0,
                        child: _ZoneTaskRow(
                          theme: theme,
                          task: row,
                          category: row.categoryId == null
                              ? null
                              : categoriesById[row.categoryId],
                          onTap: onTaskTap == null
                              ? null
                              : () => onTaskTap!(row),
                          onToggleComplete: onToggleComplete == null
                              ? null
                              : () => onToggleComplete!(row),
                          onAddNote: onAddNote == null
                              ? null
                              : () => onAddNote!(row),
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
                          startTimeOnlyVisible: startTimeOnlyVisible,
                          showCompletionCheckbox: showCompletionCheckbox,
                          flatStyle: flatStyle,
                        ),
                      ),
                    )
                  else if (row is ExternalCalendarEvent)
                    WhatMattersMotion(
                      key: ValueKey(row.id),
                      hidden: whatMattersEnabled,
                      collapse: true,
                      child: _ZoneExternalEventRow(
                        key: ValueKey(row.id),
                        theme: theme,
                        event: row,
                        durationVisible: durationVisible,
                        timeRangeVisible: timeRangeVisible,
                        startTimeOnlyVisible: startTimeOnlyVisible,
                      ),
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
            top: 0,
            left: 0,
            right: 0,
            child: ResizeHandle(
              theme: theme,
              // `barAlignment` wired here too — reported directly: "on
              // zones the dot circle is still inner, almost fully." This
              // caller never set it, so `ResizeHandle`'s own outward push
              // (keyed off `barAlignment.y.sign`) was a no-op at the
              // default `Alignment.center`, leaving the dot at the
              // MIDDLE of this already-overhanging box — visually still
              // mostly over the block, not fully clear of it.
              barAlignment: Alignment.topCenter,
              // 1.5, not the default 1.0 — corrected directly: "on zones
              // still inside not middle with part outside." This
              // container carries no clipping ancestor (unlike
              // TaskCapsuleBlock's frosted wrapper), so there's no
              // ceiling on how far the dot can be pushed — a full-
              // diameter shift measured as genuinely clear of the
              // block's edge but still read as too subtle at real
              // screen density to look "outside," so it's now pushed
              // half again as far.
              onDragStart: onResizeTopStart,
              onDragUpdate: onResizeTopUpdate,
              onDragEnd: onResizeTopEnd,
            ),
          ),
        // Bottom-edge handle — changes Zone.endMinutes only.
        if (editModeEnabled && onResizeBottomEnd != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ResizeHandle(
              theme: theme,
              barAlignment: Alignment.bottomCenter,
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
      // center, not start — matches the task rows inside this same zone
      // (and standalone task rows outside a zone), which default to
      // Row's own center alignment. `start` here had no stated reason and
      // top-anchored the title/time-range text, reading as visibly lower/
      // misaligned relative to a task row's title one row down. Reported
      // directly from a screenshot comparison.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            // No parentheses around the duration — requested directly:
            // "remove brackets from duration in zone names."
            '${zone.title} ${formatDurationLabel(durationMinutes)}',
            // colorTextTertiary — requested directly ("make zone names
            // even subtler color"). The time-range text beside it shares
            // the same tertiary color, preserving the earlier confirmed
            // pairing ("matching the time-range text on the same row").
            //
            // **2026-09-26 — textZoneName, not textTaskTitleZone.**
            // Reported directly: "zone names in zone view should resolve
            // to same size" as the spatial Timeline's own rotated zone
            // name (`zone_background_block.dart`) and the Edit screen's
            // zone grid (`zone_grid_block.dart`) — both already render on
            // `textZoneName` (11px). This header had drifted to
            // `textTaskTitleZone` (14px) as a side effect of an earlier,
            // unrelated change: "every textTaskTitle use in this whole
            // file moved to textTaskTitleZone together," which correctly
            // resized actual TASK titles but swept this ZONE header along
            // with them even though it was never a task title to begin
            // with. `textZoneName` is already regular-weight/subtler than
            // a task title by design, matching this header's own
            // "container label, not a task" intent.
            style: theme.textZoneName.copyWith(
              color: theme.colorTextTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (timeRangeVisible) ...[
          SizedBox(width: theme.spacingSm),
          Flexible(
            child: Text(
              '${start.format(context)} - ${end.format(context)}',
              // A zone range is a temporal value; keep it on the 12px mono
              // axis style. The compact 11px task-time token is reserved for
              // the leading task column and live edge pills.
              style: theme.textCaptionMono.copyWith(
                color: theme.colorTextTertiary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
    this.startTimeOnlyVisible = false,
    this.showCompletionCheckbox = true,
    this.flatStyle = false,
    this.onAddNote,
  });

  final AmbleTheme theme;
  final Task task;
  final Category? category;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;

  /// Swipe-right action — mirrors `TaskCapsuleBlock.onAddNote`'s exact
  /// "null disables" contract. Null here would mean this row's swipe
  /// start-side is disabled; every real call site wires it (see
  /// `ZoneContainerBlock.onAddNote`), matching `TaskCapsuleBlock`'s own
  /// unconditional wiring for tasks outside a zone.
  final VoidCallback? onAddNote;
  final GlobalKey stackAncestorKey;
  final void Function(Task task, double restingTop)? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;

  // No TagColorStyle field here, deliberately — this row's badge is
  // ALREADY the "icon-only" visual by construction: its fill is
  // `iconColor` (the tag's full-saturation color), and the whole shape
  // is one fixed small square with no extending rail behind it the way
  // TaskCapsuleBlock's pill has. There is no separate "pale rail" region
  // to paint here, so TagColorStyle has nothing to switch between for
  // this specific row type.

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

  /// The "Show start time" dev toggle
  /// (`DevZoneTaskStartTimeVisibleProvider`) — requested directly: "add
  /// control show time Start time (zone view), this will add task start
  /// time only (we have similar show start end time switch, but this one
  /// only start time)." A SEPARATE toggle from [timeRangeVisible]
  /// (confirmed via AskUserQuestion), not a third value replacing it — if
  /// both happen to be true, this one WINS (also confirmed), since it's
  /// the more specific request; see [timeLabel]'s own branch order.
  /// Defaults false so a caller that doesn't wire it up renders unchanged
  /// from before this parameter existed.
  final bool startTimeOnlyVisible;

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
    // Real bug, reported directly: "some items when selected as 'done' in
    // zone view are not crossed out and greyed out, while they are on
    // task view spatial." The checkbox below already read
    // `task.status == TaskStatus.completed` correctly (it toggled fine) —
    // the row's own TITLE simply never referenced this at all, so
    // completing a task in Zone view changed the checkbox but nothing
    // else. Matches `TaskCapsuleBlock`'s own `isCompleted` treatment.
    final isCompleted = task.status == TaskStatus.completed;

    // Matches TaskCapsuleBlock's own "start - end (duration)" format
    // exactly — requested directly, replacing this row's previous
    // start-time-only + separate-duration-chip display. `timeRangeVisible`
    // and `durationVisible` are two independent pieces (either, both, or
    // neither can be on) — requested directly: "Hide/show start end should
    // also affect zone view," matching TaskCapsuleTextRow's own contract.
    // `startTimeOnlyVisible` wins outright over the other two — see
    // [zoneTaskTimeLabel]'s own doc comment.
    final timeLabel = zoneTaskTimeLabel(
      context,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      timeRangeVisible: timeRangeVisible,
      durationVisible: durationVisible,
      startTimeOnlyVisible: startTimeOnlyVisible,
    );

    // Was `final emoji = category?.emoji;`, used below purely as a proxy
    // for "does this task have a category at all" (`category?.emoji` is
    // only ever null when `category` itself is — `Category.emoji` is a
    // non-nullable String on every real row, "General" included). Renamed
    // now that the badge glyph is a Tabler icon rather than that emoji
    // string directly — see `categoryIconFor`/`CategoryGlyph`
    // (`task_detail/category_visual.dart`).
    final hasCategory = category != null;
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

    // Swipe-to-reveal — requested directly ("wire for zoned"), matching
    // TaskCapsuleBlock's own unconditional wiring exactly: swipe-left
    // reuses onToggleComplete (the same action the trailing checkbox
    // performs), swipe-right opens the same add-note sheet. This row has
    // no Edit Mode concept at all (same as ZoneDayTimeline's own unzoned
    // rows), so unlike TaskCapsuleBlock there is no `editModeEnabled`
    // gate to null the actions out under — swipe is always active here.
    // AppSwipeActions only claims HORIZONTAL drag (see its own doc
    // comment), so it coexists with this row's existing VERTICAL
    // move-to-reschedule drag without contending for the same gesture.
    return AppSwipeActions(
      startAction: onAddNote == null
          ? null
          : AppSwipeAction(
              icon: Icons.edit_note_rounded,
              background: theme.colorAccent,
              semanticLabel: 'Add note',
              onActivate: onAddNote!,
            ),
      endAction: onToggleComplete == null
          ? null
          : AppSwipeAction(
              icon: isCompleted ? Icons.replay_rounded : Icons.check_rounded,
              background: isCompleted
                  ? theme.colorTextSecondary
                  : theme.colorAccent,
              semanticLabel: isCompleted ? 'Mark undone' : 'Mark done',
              onActivate: onToggleComplete!,
            ),
      child: SizedBox(
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
            // Fallback drag handle for the one case with nowhere else to
            // put it: an uncategorised task, which has no badge at all
            // (`category` is null, so the badge-level drag handle below
            // never renders). Whole-row drag here is exactly what the
            // time-column comment below says to avoid (fighting the
            // Timeline's vertical scroll), but only for this uncommon
            // case — every categorised row keeps its narrow badge handle.
            //
            // **2026-09-20** — no longer also conditioned on
            // `timeLabel.isEmpty`: the time column stopped being a viable
            // grip entirely once [zoneRowTimeLabelReservedWidth] went to
            // 0 (a zero-width box can't be hit-tested), so whether a
            // label is showing no longer has any bearing on where drag
            // lives.
            onVerticalDragStart: !hasCategory
                ? (details) => _handleDragStart(context, details)
                : null,
            onVerticalDragUpdate: !hasCategory ? onDragUpdate : null,
            onVerticalDragEnd: !hasCategory ? onDragEnd : null,
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
                // Escapes back out to the spatial Task view's own hour-
                // label position via [ZoneRowTimeLabel]'s `Positioned` —
                // see that widget's own class doc comment for the full
                // "why not just reuse TaskBoundaryMarkers directly"
                // reasoning, and docs/DESIGN_SYSTEM.md's "Zone row hour
                // label" section. Replaces an earlier `Transform.translate`
                // approach that worked but was a coordinate hack rather
                // than a shared structure — requested directly, again,
                // once the negative-margin version above it was already
                // found to break layout outright (see docs/ERROR_LOG.md).
                //
                // [leftPaddingToEscape] is EVERY padding layer between
                // this row and the true screen edge: [zoneContentLeftInset]
                // (`ZoneDayTimeline`'s own list inset — `theme
                // .timelineZoneLeft`, so this view's cards line up with
                // the spatial view's zone band) + `spacingLg` (24,
                // [ZoneContainerBlock]'s own card LEFT padding).
                //
                // **2026-09-20 — no longer wrapped in a `GestureDetector`.**
                // With [zoneRowTimeLabelReservedWidth] at 0 this box has no
                // width to hit-test against (the text paints outside it via
                // `Positioned`), so a gesture wrapper here was silently
                // dead. Drag-to-reschedule moved to the badge below, which
                // always carries it now — see its own comment.
                if (timeLabel.isNotEmpty)
                  ZoneRowTimeLabel(
                    theme: theme,
                    text: timeLabel,
                    leftPaddingToEscape:
                        zoneContentLeftInset(theme, context) + theme.spacingLg,
                    reservedWidth: zoneRowTimeLabelReservedWidth,
                  ),
                if (hasCategory) ...[
                  // Small colored rounded-square badge behind the emoji —
                  // requested directly, matching the badge every task pill
                  // already shows elsewhere (this view's own bare emoji
                  // read as visually inconsistent with the rest of the app).
                  // Uses the same iconColor this row's own completion
                  // checkbox ring already resolves, rather than the pill's
                  // own pale fill color, so the badge and the ring agree.
                  // Sized and shaped to match `badgeSize`'s own comment
                  // above — the SAME `theme.sizeTaskBadge` and
                  // `theme.radiusPill` TaskCapsuleBlock's own pill rail
                  // uses, not a separate enlarged circle.
                  //
                  // **2026-09-20 — the badge now ALWAYS carries
                  // drag-to-reschedule**, not just when the time label is
                  // absent. [zoneRowTimeLabelReservedWidth] went to 0 (see
                  // that constant's own doc comment) so a task sits at its
                  // zone card's own left padding — which means the time
                  // column no longer occupies any row width, and a
                  // zero-width box cannot be hit-tested. The label still
                  // PAINTS (it escapes via `Positioned`), so it looks
                  // unchanged, but it can't be a grip any more. The badge
                  // is the natural home: already narrow (so it doesn't
                  // fight the Timeline's vertical scroll, per the time
                  // column's own reasoning) and present on every
                  // categorised task.
                  GestureDetector(
                    // No `onTap` here — the outer row-level `GestureDetector`
                    // (this whole `_ZoneTaskRow`'s own build wrapper) already
                    // handles taps everywhere on the row, tap included; only
                    // the DRAG gesture needs a home, since drag must stay
                    // narrow (not span the whole row) or it fights the
                    // Timeline's own vertical scroll.
                    onVerticalDragStart: (details) =>
                        _handleDragStart(context, details),
                    onVerticalDragUpdate: onDragUpdate,
                    onVerticalDragEnd: onDragEnd,
                    behavior: HitTestBehavior.opaque,
                    child: Builder(
                      builder: (context) {
                        // Local copy, not the widget field directly — Dart
                        // doesn't retain a field's null-check promotion
                        // across the closure below.
                        final resolvedCategory = category;
                        final badgeColor = resolvedCategory == null
                            ? theme.colorTextSecondary
                            : resolveCategoryVisual(
                                theme: theme,
                                category: resolvedCategory,
                              ).iconColor;
                        return Container(
                          width: badgeSize,
                          height: badgeSize,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            // theme.radiusPill, not BoxShape.circle —
                            // requested directly ("make actually same shape
                            // as timeline, not circle but rounded square").
                            // Matches TaskCapsuleBlock's own pill rail
                            // exactly, and tracks the SAME "Pill shape"
                            // setting it does — see radiusPill's own doc
                            // comment on AmbleTheme.
                            borderRadius: BorderRadius.circular(
                              theme.radiusPill,
                            ),
                          ),
                          // Tabler icon via CategoryGlyph — glyphColorOn
                          // rather than this badge's own `iconColor`
                          // directly, matching TaskCapsuleBlock's identical
                          // reasoning: a CUSTOM category's iconColor is the
                          // same swatch as this badge's own fill.
                          // No glyph for "no category" — see
                          // CategoryBadge's own 2026-09-23 comment on the
                          // same change.
                          child: resolvedCategory == null
                              ? null
                              : CategoryGlyph(
                                  category: resolvedCategory,
                                  color: glyphColorOn(badgeColor),
                                  size: badgeSize * 0.55,
                                ),
                        );
                      },
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
                    // **2026-09-20 — back to textTaskTitle, not
                    // textTaskTitleZone.** Reported directly against a
                    // screenshot: an in-zone task's title read too large
                    // next to an unzoned task's own title just below it
                    // (which uses `textTaskTitle` via `TaskCapsuleBlock`)
                    // — confirmed the outside-zone size is the one to
                    // keep, reversing the earlier "one rung up" decision
                    // `textTaskTitleZone` itself documents.
                    style: theme.textTaskTitle.copyWith(
                      color: isCompleted
                          ? theme.colorTextSecondary
                          : theme.colorTextPrimary,
                      fontWeight: FontWeight.w700,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: theme.colorTextSecondary,
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
                    isCompleted: isCompleted,
                    onToggle: onToggleComplete,
                  ),
                ],
              ],
            ),
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
    this.startTimeOnlyVisible = false,
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

  /// See [ZoneContainerBlock.startTimeOnlyVisible]. **2026-09-20 — now
  /// also reaches event rows**, not just `_ZoneTaskRow`. Reported
  /// directly: with `timeRangeVisible`'s own dev toggle back to its
  /// default OFF, an imported event's start time stopped showing at all
  /// — unlike a native task row, which was never actually dependent on
  /// that toggle in the first place (`startTimeOnlyVisible` wins outright
  /// over it there, and defaults true). This brings event rows to the
  /// same real behavior task rows already had, rather than the two kinds
  /// of row disagreeing about whether the "Show time" toggle can hide a
  /// start time entirely.
  final bool startTimeOnlyVisible;

  @override
  Widget build(BuildContext context) {
    final durationMinutes = event.end.difference(event.start).inMinutes;
    // Reuses the same helper `_ZoneTaskRow`/the unzoned task row already
    // compute their own time label with — `scheduledAt`/`durationMinutes`
    // are generic enough that this event's own start/duration slot in
    // directly, rather than this row hand-rolling an equivalent
    // computation that could silently drift from the task rows' own.
    final timeLabel = zoneTaskTimeLabel(
      context,
      scheduledAt: event.start,
      durationMinutes: durationMinutes,
      timeRangeVisible: timeRangeVisible,
      durationVisible: durationVisible,
      startTimeOnlyVisible: startTimeOnlyVisible,
    );

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
            // **2026-09-20 — now uses [ZoneRowTimeLabel], same as
            // `_ZoneTaskRow`.** Reported directly: an imported event's
            // time never got the same left-pulled treatment native
            // tasks' own time labels do — this row rendered its time as
            // ordinary in-flow text instead of escaping back to
            // [zoneRowTimeLabelEdgeInset], so it visibly sat further
            // right than a task row's time beside it. `leftPaddingToEscape`
            // is the identical value `_ZoneTaskRow` uses (this row lives
            // inside the same zone card), and the `SizedBox(height:
            // theme.sizeTaskBadge)` wrapper matches that same fix's own
            // vertical-alignment half — the label centers against the
            // badge's height, not the row's full height.
            if (timeLabel.isNotEmpty)
              SizedBox(
                height: theme.sizeTaskBadge,
                child: ZoneRowTimeLabel(
                  theme: theme,
                  text: timeLabel,
                  leftPaddingToEscape:
                      zoneContentLeftInset(theme, context) + theme.spacingLg,
                  reservedWidth: zoneRowTimeLabelReservedWidth,
                ),
              ),
            // The same dashed calendar badge Task view's own imported
            // events already show — requested directly: "on the zone view,
            // the imported items from calendar should be rendered in the
            // same way as other events, other tasks, so with the circle,
            // and icon inside the circle is dotted, same as in the
            // timeline view." Sized to `theme.sizeTaskBadge` and gapped by
            // `spacingSm`, exactly like `_ZoneTaskRow`'s own category
            // badge sitting in this same position, so the two row kinds
            // line up in the merged list.
            DashedPillRail(
              theme: theme,
              width: theme.sizeTaskBadge,
              height: theme.sizeTaskBadge,
            ),
            SizedBox(width: theme.spacingSm),
            Expanded(
              flex: 3,
              child: Text(
                event.title,
                // Secondary (muted), not the primary/bold weight a real
                // task's title gets — the visual signal that this row is
                // read-only/external, not an editable Amble task.
                //
                // textTaskTitle, not textTaskTitleZone — see
                // `_ZoneTaskRow`'s own matching 2026-09-20 comment; this
                // row is built to visually line up with that one, so it
                // moved off the larger token together.
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

/// Shares the attention release with spatial pills, then collapses list space.
/// The child stays mounted and unclipped so hour labels outside its left edge
/// survive both the transition and restoration.
class WhatMattersRow extends StatelessWidget {
  const WhatMattersRow({
    super.key,
    required this.theme,
    required this.hidden,
    required this.child,
  });

  final AmbleTheme theme;
  final bool hidden;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      WhatMattersMotion(hidden: hidden, collapse: true, child: child);
}
