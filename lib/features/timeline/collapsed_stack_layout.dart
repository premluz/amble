/// One row's chronological identity for [computeCollapsedStackTops] — a
/// group of one or more items sharing the same vertical position (an
/// overlapping cluster of tasks shares a row; an external calendar event
/// is always alone in its own row), plus its own rendered height.
class CollapsedStackRow {
  const CollapsedStackRow({
    required this.ids,
    required this.start,
    required this.height,
  });

  /// Every id sharing this row's `top` — more than one for an overlapping
  /// task group, exactly one for an external event.
  final List<String> ids;

  final DateTime start;
  final double height;
}

/// List (collapsed) mode's single, unified stacking pass over BOTH task
/// rows and external-calendar-event rows — kept pure and widget-free (same
/// shape as `task_overlap_layout.dart`/`overlap_cluster.dart`) so the merge
/// itself is unit-testable without a widget tree.
///
/// Real bug, reported directly: "tasks on list view should not overlap
/// (the app tasks with the imported tasks should be one by one)." The
/// original implementation computed task rows' positions FIRST, entirely
/// unaware external events existed, then positioned external events in a
/// SEPARATE pass that only read those already-fixed task positions — so an
/// external event landing chronologically between two tasks could never
/// push the later task's row down to make room; it just visually
/// overlapped it. This function fixes that by walking [taskRows] and
/// [externalEventRows] together, ordered by each row's own start time,
/// with ONE shared cursor: whichever row comes next in time is the one
/// that advances the cursor, task or external, every time — so nothing
/// can land on top of anything else.
Map<String, double> computeCollapsedStackTops({
  required List<CollapsedStackRow> taskRows,
  required List<CollapsedStackRow> externalEventRows,
  required double gap,
}) {
  final sortedTaskRows = [...taskRows]
    ..sort((a, b) => a.start.compareTo(b.start));
  final sortedEventRows = [...externalEventRows]
    ..sort((a, b) => a.start.compareTo(b.start));

  final tops = <String, double>{};
  var cursor = 0.0;
  var taskIndex = 0;
  var eventIndex = 0;

  while (taskIndex < sortedTaskRows.length ||
      eventIndex < sortedEventRows.length) {
    final nextIsTask =
        eventIndex >= sortedEventRows.length ||
        (taskIndex < sortedTaskRows.length &&
            !sortedTaskRows[taskIndex].start.isAfter(
              sortedEventRows[eventIndex].start,
            ));
    final row = nextIsTask
        ? sortedTaskRows[taskIndex++]
        : sortedEventRows[eventIndex++];
    for (final id in row.ids) {
      tops[id] = cursor;
    }
    cursor += row.height + gap;
  }

  return tops;
}

/// A cluster's real rendered height in List (collapsed) mode: [memberCount]
/// stacked lines of `OverlapClusterBlock`'s own flat list (one line per
/// member — List mode always forces that widget's inline row layout), each
/// [lineHeight] tall, joined by [lineGap] between consecutive rows, inside
/// [verticalPadding] on both the top and bottom edge.
///
/// Real bug, reported directly from a screenshot: the collapsed stacking
/// cursor previously reserved only the TALLEST MEMBER PILL's own
/// badge-floored height for a whole cluster row — a couple of small icons'
/// worth of space — while the cluster's actual rendered content (every
/// member's own title+time line, plus this padding) is far taller. The
/// next real row down was positioned against that under-reserved height,
/// reading as an oversized or undersized gap depending on how many members
/// the cluster held.
///
/// Pure and widget-free, matching this file's own [computeCollapsedStackTops]/
/// [computeLabelTops] — so this formula is directly testable rather than a
/// private method with no test target.
double collapsedClusterHeight({
  required int memberCount,
  required double lineHeight,
  required double lineGap,
  required double verticalPadding,
}) =>
    lineHeight * memberCount +
    lineGap * (memberCount - 1) +
    verticalPadding * 2;

/// One task-name row's PREFERRED vertical position — the y its own pill's
/// icon sits at — plus how tall the rendered row is.
class LabelAnchor {
  const LabelAnchor({
    required this.id,
    required this.preferredTop,
    required this.height,
  });

  final String id;

  /// Where this label would sit if nothing else were in the way: level
  /// with its own pill's icon.
  final double preferredTop;

  final double height;
}

/// Places each task-name label at its own pill's icon, pushing a label
/// down ONLY when it would otherwise collide with the one above it.
///
/// Requested directly: "if we could detect the level and position the task
/// name so it's always lined up with the icon, only if two tasks are
/// starting at the same time or are too close to each other, then there
/// would be a mechanism preventing overlap, so they would stack ...
/// otherwise, if they are not too close, the title should be at the level
/// of the icon of the pill, but precisely lined up with the icon."
///
/// Distinct from [computeCollapsedStackTops], which packs every row
/// sequentially from zero and has no concept of a preferred position: that
/// is right for List (collapsed) mode, where there is no time axis to
/// align to, and wrong here, where each label has a real pill to point at.
///
/// The sweep is greedy in chronological order, which is what makes a run of
/// three near-simultaneous tasks fall back to reading one-after-another
/// (each pushed just clear of the last) while a well-separated pair both
/// keep their exact icon alignment. Pure and widget-free so the collision
/// arithmetic is unit-testable.
Map<String, double> computeLabelTops({
  required List<LabelAnchor> anchors,
  required double gap,
}) {
  final sorted = [...anchors]
    ..sort((a, b) => a.preferredTop.compareTo(b.preferredTop));

  final tops = <String, double>{};
  double? previousBottom;

  for (final anchor in sorted) {
    final top = previousBottom == null
        ? anchor.preferredTop
        // Never ABOVE its own icon — a label only ever gets pushed down.
        : (anchor.preferredTop < previousBottom
              ? previousBottom
              : anchor.preferredTop);
    tops[anchor.id] = top;
    previousBottom = top + anchor.height + gap;
  }

  return tops;
}
