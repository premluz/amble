import 'dart:math' as math;

import '../../shared/models/scheduled_block.dart';
import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/services/zone_containment.dart';
import 'zone_background_block.dart' show zoneBackgroundGap;

/// Where a block sits horizontally when it shares time with others.
///
/// [block] is a [ScheduledBlock] rather than a bare [Task] — **generalized
/// 2026-09-07** (confirmed directly: "the imported tasks should also
/// stack in the same way as native tasks... otherwise exactly the same,
/// with different styling") so an [ExternalCalendarEvent] can occupy a
/// lane next to real tasks instead of positioning independently with no
/// overlap awareness. [task] stays as a convenience getter, non-null only
/// when [block] genuinely is a [Task] — every existing call site that
/// only ever handled tasks keeps working unchanged; new call sites that
/// need to render an event differently check [block] directly (or use
/// [task] with a null-check, per `timeline_screen.dart`'s own render-loop
/// branch on slot content).
///
/// This layout only ever applies to tasks the user didn't just drag — an
/// overlap left in place (created/edited via the modals, which reject
/// overlapping saves when the "Prevent overlapping tasks" preference is on)
/// or reached with the preference off, is shown side by side instead: the
/// conflict stays visible and the user decides what to do about it. When
/// the preference is on and the overlap arises from a drag specifically,
/// `cascade_reschedule.dart`'s push logic resolves it before this layout
/// ever sees the conflict — see docs/SCOPE.md. This is the standard
/// calendar treatment for the remaining cases and matches design principle
/// 1 (the plan is provisional, not a verdict). An [ExternalCalendarEvent]
/// is never draggable regardless of which lane it lands in — nothing about
/// this layout makes it so; it only decides where things sit.
class TaskLayoutSlot {
  const TaskLayoutSlot({
    required this.block,
    required this.column,
    required this.columnCount,
    required this.groupIndex,
  });

  final ScheduledBlock block;

  /// Non-null only when [block] is a real [Task] — the common case, and
  /// every call site written before events joined this layout. Null for
  /// an [ExternalCalendarEvent] slot.
  Task? get task => block is Task ? block as Task : null;

  /// 0-based horizontal position within this block's overlap group.
  final int column;

  /// How many columns the block's overlap group needs. 1 means the block
  /// overlaps nothing and takes the full width.
  final int columnCount;

  /// Which overlap group this block belongs to — blocks sharing a value
  /// are the ones that were laid out against each other.
  ///
  /// The reliable way to ask "do these share a row?", which [column] is
  /// NOT: a group packs blocks into the fewest columns it can, so column
  /// 0 is REUSED by any later block whose start clears column 0's last
  /// occupant. List mode used to treat `column == 0` as "starts a new
  /// row" and consequently split one group across two rows whenever that
  /// reuse happened (09:00-10:00, 09:30-10:30, 10:00-11:00 → columns 0,
  /// 1, 0), painting the two rows on top of each other. Reported directly
  /// from a screenshot: "on list view we have some important tasks
  /// overlap they seem duplicated... whatever the scenario should never
  /// overlap."
  final int groupIndex;

  /// Fraction of the available width this block occupies (1.0 when alone).
  double get widthFraction => 1 / columnCount;

  /// Fraction of the available width to offset this block from the left.
  double get leftFraction => column / columnCount;
}

/// Assigns each of [blocks] a horizontal column so overlapping blocks
/// render side by side rather than stacked invisibly on top of each
/// other.
///
/// Blocks that don't overlap anything get the full width. A set of blocks
/// that mutually overlap forms a group, and every block in that group is
/// laid out against the same column count — so two overlapping blocks each
/// take half the width, three take a third, and so on. Column count is
/// computed per group rather than globally, so one busy hour doesn't
/// narrow the whole day.
///
/// Every task must be scheduled (`isScheduled == true`); callers get their
/// tasks from `tasksForSelectedDayProvider`, which already guarantees this.
/// An [ExternalCalendarEvent] is always scheduled by construction (it has
/// no unscheduled state at all).
List<TaskLayoutSlot> layoutOverlappingTasks(List<ScheduledBlock> blocks) {
  if (blocks.isEmpty) return const [];

  final sorted = [...blocks]
    ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

  final slots = <TaskLayoutSlot>[];

  // Walk the day in time order, accumulating a group of blocks that overlap
  // each other. A group ends at the first block starting at or after the
  // group's latest end time — nothing after that point can overlap anything
  // already in the group.
  var groupStart = 0;
  var groupEnd = sorted.first.scheduledEnd;
  var groupIndex = 0;

  for (var i = 1; i <= sorted.length; i++) {
    final startsNewGroup =
        i == sorted.length || !sorted[i].scheduledStart.isBefore(groupEnd);

    if (startsNewGroup) {
      slots.addAll(_layoutGroup(sorted.sublist(groupStart, i), groupIndex));
      if (i == sorted.length) break;
      groupIndex++;
      groupStart = i;
      groupEnd = sorted[i].scheduledEnd;
    } else {
      final end = sorted[i].scheduledEnd;
      if (end.isAfter(groupEnd)) groupEnd = end;
    }
  }

  return slots;
}

/// Packs one overlap group into the fewest columns that keep every pair of
/// genuinely-overlapping blocks apart. A block reuses the first column
/// whose last occupant has already finished, so a group like 9:00-10:00,
/// 9:30-10:30, 10:00-11:00 needs two columns rather than three.
List<TaskLayoutSlot> _layoutGroup(List<ScheduledBlock> group, int groupIndex) {
  if (group.length == 1) {
    return [
      TaskLayoutSlot(
        block: group.single,
        column: 0,
        columnCount: 1,
        groupIndex: groupIndex,
      ),
    ];
  }

  final columnEndTimes = <DateTime>[];
  final assignedColumns = <int>[];

  for (final block in group) {
    var column = columnEndTimes.indexWhere(
      (end) => !end.isAfter(block.scheduledStart),
    );
    if (column == -1) {
      column = columnEndTimes.length;
      columnEndTimes.add(block.scheduledEnd);
    } else {
      columnEndTimes[column] = block.scheduledEnd;
    }
    assignedColumns.add(column);
  }

  final columnCount = columnEndTimes.length;
  return [
    for (var i = 0; i < group.length; i++)
      TaskLayoutSlot(
        block: group[i],
        column: assignedColumns[i],
        columnCount: columnCount,
        groupIndex: groupIndex,
      ),
  ];
}

/// The deepest overlap stack anywhere in [slots] — at least 1, even for
/// an empty day.
///
/// Drives BOTH the Spatial Task View's zone background width and the x its
/// text column starts at, so the two can never disagree. Deliberately one
/// value for the whole day rather than per zone: corrected directly ("all
/// zones same width even if only items over 1 zone stack" / "all text ...
/// always lined up even if one zone"). An earlier pass sized each zone to
/// its own deepest stack, which made zones visibly different widths down
/// the day and shifted the names beside them.
///
/// Reads the SAME [TaskLayoutSlot]s the capsules are positioned from,
/// rather than re-deriving overlap, so the background and the text column
/// can never disagree with the pills drawn between them.
int dayPillLanes(List<TaskLayoutSlot> slots) {
  var lanes = 1;
  for (final slot in slots) {
    if (slot.column + 1 > lanes) lanes = slot.column + 1;
  }
  return lanes;
}

/// The deepest overlap stack among only those [slots] whose task actually
/// falls inside the window [zoneStart]-[zoneEnd] — at least 1, even for a
/// zone holding no tasks at all.
///
/// NOT used by `timeline_screen.dart`'s `_zoneBackgroundWidth` as of the
/// "all zones widen to the same size" request — every zone band now reads
/// [dayPillLanes] instead, so a lane count from ANY overlap anywhere in
/// the visible day widens every band, not just the one holding it. Kept
/// (rather than deleted) for its own direct tests below and as the
/// building block for the earlier, now-superseded per-zone-width
/// behaviour this function used to drive: sizing ONE zone's own
/// background band so the visible space to the right of its pills read as
/// the same padding as the space to their left, requested directly at the
/// time ("still gap", twice, pointing at the band's right edge; clarified
/// as "I mean perceived padding right").
///
/// Half-open on both ends, matching `resolveZoneContainment`'s own window
/// rule: a task ending exactly when the zone starts, or starting exactly
/// when it ends, is outside it.
int zonePillLanes({
  required List<TaskLayoutSlot> slots,
  required DateTime zoneStart,
  required DateTime zoneEnd,
}) {
  var lanes = 1;
  for (final slot in slots) {
    // Zone bands are a TASK-only concept (a zone assignment is `Task.zoneId`
    // — an ExternalCalendarEvent has no such field), so an event slot never
    // widens a band. Skipped rather than erroring: `slot.task` is null for
    // one now that events share this same lane layout.
    final task = slot.task;
    if (task == null) continue;
    final start = task.scheduledAt;
    final duration = task.durationMinutes;
    if (start == null || duration == null) continue;
    final end = start.add(Duration(minutes: duration));
    if (!start.isBefore(zoneEnd) || !end.isAfter(zoneStart)) continue;
    if (slot.column + 1 > lanes) lanes = slot.column + 1;
  }
  return lanes;
}

/// The pixel width of [lanes] side-by-side pills, including the gaps
/// between them. Split from [zonePillLanes] so the lane count stays
/// testable without a theme.
double zoneBackgroundPillWidth({
  required int lanes,
  required double pillWidth,
  required double columnGap,
}) => lanes * pillWidth + (lanes - 1) * columnGap;

/// The `width` a zone background block needs so its rendered band pads the
/// pill column by [horizontalInset] on BOTH sides.
///
/// `ZoneBackgroundBlock` starts its band [horizontalInset] to the left of
/// the pill column and trims [trailingTrim] off whatever width it is
/// given, so landing the same inset on the right means carrying both
/// insets plus that trim. Requested directly: "gap from right (zone to
/// right task) should be same as left gap (padding)" — the call site
/// previously added a bare pill width instead, which happened to leave 8px
/// on the right against a 12px left inset.
///
/// Public (not inlined at the call site) specifically so this arithmetic
/// is testable against the real function rather than a copy of it — an
/// earlier version of this test recomputed the formula itself and so
/// passed even against a wrong implementation.
double zoneBackgroundWidthForPills({
  required double pillsSpan,
  required double horizontalInset,
  required double trailingTrim,
}) => pillsSpan + horizontalInset * 2 + trailingTrim;

/// The x a task pill's own box starts at, given its overlap [column].
///
/// This is deliberately just the lane's own offset — the box carries its
/// extra lift room on the RIGHT, never by starting further left. Real bug,
/// reported twice as "perceived padding right ... still too big": the box
/// used to start `spacingSm` earlier to reserve that room, relying on an
/// `Align(topCenter)` to push the rail back. That never happened (the
/// pill's content fills the box's width, so there was nothing to centre),
/// so every rail painted `spacingSm` left of its lane — inside a zone band
/// that read as 4px of padding on the left against 20px on the right.
///
/// Exposed so the invariant is testable against the real function rather
/// than a copy of its arithmetic.
double pillBoxLeftForColumn({
  required int column,
  required double pillWidth,
  required double columnGap,
}) => column * (pillWidth + columnGap);

/// One [Zone]'s rendered band in List (collapsed) mode: where its top and
/// height land in the SAME pixel space [_collapsedTops]'s gap-collapsing
/// stack cursor already positioned every task/external-event row in
/// (`timeline_screen.dart`).
class CollapsedZoneBand {
  const CollapsedZoneBand({
    required this.zone,
    required this.top,
    required this.height,
  });

  final Zone zone;
  final double top;
  final double height;
}

/// Derives every applicable zone's List-mode band from the collapsed tops
/// [_collapsedTops] already computed for its member tasks/events — NOT
/// from real time-to-pixel math, which [ZoneBackgroundBlock]'s own
/// formula uses for Task view and which has no relationship to List
/// mode's non-linear, gap-collapsing cursor positions.
///
/// [containments] is [ZoneContainmentResult.containments] — the existing,
/// already-shared "which tasks/events belong to which zone" resolution
/// (`resolveZoneContainment`), reused here unchanged rather than
/// duplicating containment logic for List mode specifically.
///
/// A zone WITH members bands from the earliest member's own top to the
/// latest member's own bottom, padded by [padding] on both edges — the
/// same visual inset Task view's own top/bottom task treatment uses
/// (`zoneBackgroundOffset`), applied here to the BAND itself since List
/// mode has no equivalent "inset the task" mechanism to lean on instead.
///
/// A zone with NO members (a real, confirmed case — Task view always
/// renders an empty zone against its own time range) has no real position
/// to derive from, so it renders a fixed-height placeholder
/// ([placeholderHeight] plus the same [padding]) slotted immediately
/// BEFORE the first row in [rowTopsByStartTime] whose own start time is at
/// or after the zone's start — or after the last row if none is. This is
/// a chronological approximation, not a real position: the placeholder is
/// a decorative overlay and does not shift or reserve space from any
/// other row, matching how [ZoneBackgroundBlock] never affects task
/// layout in Task view either.
///
/// Returns one band per entry in [containments], in the SAME order
/// (already chronological by `Zone.startMinutes`, per
/// `resolveZoneContainment`'s own doc comment).
///
/// [padding] is a REQUEST, not a guarantee: two zones separated by only a
/// small real gap (or a zone sitting close to a plain unzoned row) can
/// have their naive `top - padding`/`bottom + padding` bands overlap —
/// real bug, reported directly from a screenshot, once the collapsed
/// inter-row gap ([_collapsedBlockGap] in `timeline_screen.dart`) shrank
/// below double this padding. Each band's padding is clamped per edge to
/// AT MOST half the real gap to whatever sits immediately next to it in
/// [rowExtents] (a task/event row's own real top AND bottom) or another
/// band — so two neighbours never claim overlapping space, and each still
/// gets an equal share of a tight gap rather than one winning the whole
/// thing.
List<CollapsedZoneBand> collapsedZoneBands({
  required List<ZoneContainment> containments,
  required DateTime day,
  required Map<String, double> taskTops,
  required Map<String, double> taskHeights,
  required Map<String, double> externalEventTops,
  required Map<String, double> externalEventHeights,
  required List<MapEntry<DateTime, double>> rowTopsByStartTime,
  required List<(double top, double bottom)> rowExtents,
  required double padding,
  required double placeholderHeight,
}) {
  final sortedRows = [...rowTopsByStartTime]
    ..sort((a, b) => a.key.compareTo(b.key));
  final dayStart = DateTime(day.year, day.month, day.day);

  double placeholderTop(Zone zone) {
    if (sortedRows.isEmpty) return 0;
    final zoneStart = dayStart.add(Duration(minutes: zone.startMinutes));
    for (final row in sortedRows) {
      if (!row.key.isBefore(zoneStart)) return row.value;
    }
    return sortedRows.last.value;
  }

  // Pass 1: every band's RAW (unpadded) top/bottom — its members' own
  // wrap, or the placeholder's single point.
  final raw = [
    for (final containment in containments)
      if (containment.tasks.isEmpty && containment.externalEvents.isEmpty)
        (
          zone: containment.zone,
          top: placeholderTop(containment.zone),
          bottom: placeholderTop(containment.zone) + placeholderHeight,
        )
      else
        _rawMemberBand(
              containment,
              taskTops,
              taskHeights,
              externalEventTops,
              externalEventHeights,
            ) ??
            // Every member this containment lists was filtered out of the
            // top/height maps (see _rawMemberBand's own doc comment) — the
            // same placeholder treatment a genuinely empty zone gets above.
            (
              zone: containment.zone,
              top: placeholderTop(containment.zone),
              bottom: placeholderTop(containment.zone) + placeholderHeight,
            ),
  ];

  // Pass 2: clamp each edge to at most half the gap to its nearest
  // neighbour among every OTHER band's top/bottom AND every plain row's
  // own real top/bottom (not just its top) — whichever is closest on
  // that side. Using the real bottom (not just the start) is what stops
  // a band's padding from eating into a tall row's own body, not just
  // its top edge.
  final allEdges = <double>{
    for (final band in raw) ...[band.top, band.bottom],
    for (final extent in rowExtents) ...[extent.$1, extent.$2],
  }.toList()..sort();

  double clampedPaddingAbove(double top) {
    final aboveEdges = allEdges.where((edge) => edge < top);
    if (aboveEdges.isEmpty) return padding;
    final nearest = aboveEdges.last;
    return math.min(padding, (top - nearest) / 2);
  }

  double clampedPaddingBelow(double bottom) {
    final belowEdges = allEdges.where((edge) => edge > bottom);
    if (belowEdges.isEmpty) return padding;
    final nearest = belowEdges.first;
    return math.min(padding, (nearest - bottom) / 2);
  }

  // Index-keyed (not zone-keyed): [Zone] has no `==` override, so
  // matching bands back up by identity through a lookup would work but is
  // needlessly fragile — an index into `raw`/`containments` (both already
  // in one fixed, shared order) is simpler and can't misidentify two
  // zones that happen to be `identical()`-distinct-but-equal-looking.
  final padded = [
    for (var i = 0; i < raw.length; i++)
      (
        index: i,
        top: raw[i].top - clampedPaddingAbove(raw[i].top),
        bottom: raw[i].bottom + clampedPaddingBelow(raw[i].bottom),
      ),
  ];

  // Pass 3: guarantee at least `zoneBackgroundGap` between two bands that
  // ended up touching (or overlapping) after pass 2's clamp — real bug,
  // reported directly: List mode showed zero visible gap between two
  // adjacent zones, unlike Task view's own always-4px separation
  // (`zoneBackgroundGap`, see zone_background_block.dart). Pass 2's clamp
  // is "AT MOST half the real gap to a neighbour," which is correctly 0
  // when two zones' member rows are genuinely back-to-back with no real
  // gap at all — exactly the case that produced the bug, since "at most
  // half of zero" is still zero. This pass takes the shortfall entirely
  // off the LATER band's top, matching zoneBackgroundGap's own rule
  // ("taken entirely off a block's bottom edge, never its top... the
  // earlier zone yields the whole gap") — a zone's rendered TOP still
  // lands on its own real start, only a later zone's start may read as
  // slightly later than it in a collapsed, non-linear view anyway.
  //
  // Sorted by top first: bands can arrive in zone-start order, not
  // necessarily band-position order, once padding has shifted them.
  final byTop = [...padded]..sort((a, b) => a.top.compareTo(b.top));
  final adjustedTop = List<double>.filled(raw.length, 0);
  final adjustedBottom = List<double>.filled(raw.length, 0);
  double? previousBottom;
  for (final band in byTop) {
    var top = band.top;
    var bottom = band.bottom;
    if (previousBottom != null) {
      final realGap = top - previousBottom;
      if (realGap < zoneBackgroundGap) {
        final shortfall = zoneBackgroundGap - realGap;
        top += shortfall;
        bottom += shortfall;
      }
    }
    adjustedTop[band.index] = top;
    adjustedBottom[band.index] = bottom;
    previousBottom = bottom;
  }

  return [
    for (var i = 0; i < raw.length; i++)
      CollapsedZoneBand(
        zone: raw[i].zone,
        top: adjustedTop[i],
        height: adjustedBottom[i] - adjustedTop[i],
      ),
  ];
}

/// Null when NONE of [containment]'s members actually appear in the
/// top/height maps — not the same as `containment.tasks`/`externalEvents`
/// both being empty (that's the placeholder case, handled by the caller
/// before this is ever called). A List-view-only dev filter (see
/// `DevHideImportedTasks`/`DevTimelineListOnlyImportant` in
/// `core/dev_config.dart`) can hide every one of a zone's members from
/// `blockTops` while [containment] itself, computed from the unfiltered
/// task/event lists, still lists them — this is the caller's own signal
/// to fall back to the placeholder band instead, exactly like a genuinely
/// empty zone does.
({Zone zone, double top, double bottom})? _rawMemberBand(
  ZoneContainment containment,
  Map<String, double> taskTops,
  Map<String, double> taskHeights,
  Map<String, double> externalEventTops,
  Map<String, double> externalEventHeights,
) {
  double? minTop;
  double? maxBottom;

  void consider(double top, double height) {
    if (minTop == null || top < minTop!) minTop = top;
    final bottom = top + height;
    if (maxBottom == null || bottom > maxBottom!) maxBottom = bottom;
  }

  for (final task in containment.tasks) {
    final top = taskTops[task.id];
    final height = taskHeights[task.id];
    if (top != null && height != null) consider(top, height);
  }
  for (final event in containment.externalEvents) {
    final top = externalEventTops[event.id];
    final height = externalEventHeights[event.id];
    if (top != null && height != null) consider(top, height);
  }

  if (minTop == null || maxBottom == null) return null;
  return (zone: containment.zone, top: minTop!, bottom: maxBottom!);
}
