import '../models/scheduled_block.dart';
import '../models/task.dart';

/// A contiguous run of 2+ [ScheduledBlock]s that genuinely intersect in
/// time — candidates for the Timeline's aggregate [OverlapClusterBlock]
/// instead of individual capsule blocks.
///
/// **Generalized 2026-09-07** (confirmed directly: "the imported tasks
/// should also stack in the same way as native tasks... otherwise exactly
/// the same, with different styling") from a `List<Task>`-only shape, so
/// an [ExternalCalendarEvent] can be pulled into a cluster's flat row list
/// alongside real tasks instead of being excluded from clustering
/// entirely. [tasks] stays as a filtered convenience getter for the
/// common all-real-tasks case; [blocks] is the authoritative member list
/// the render layer actually iterates, since a cluster mixing tasks and
/// events needs to render each member differently.
class OverlapCluster {
  const OverlapCluster({
    required this.start,
    required this.end,
    required this.blocks,
  });

  /// `min(scheduledStart)` across every member in the cluster.
  final DateTime start;

  /// `max(scheduledEnd)` across every member in the cluster.
  final DateTime end;

  /// The cluster's members, chronological by `scheduledStart` — the order
  /// both the icon stack (earliest member's icon on top) and the row list
  /// read off directly, so this list's order IS the display order. Mixed
  /// [Task]s and [ExternalCalendarEvent]s in one run share one cluster —
  /// there's no separate "event cluster."
  final List<ScheduledBlock> blocks;

  /// Convenience view of [blocks] narrowed to real tasks only — every
  /// caller written before events joined clustering used this shape
  /// directly; kept so that code is unaffected while new code (row
  /// rendering, id lookups) that needs the FULL member list uses [blocks].
  List<Task> get tasks => blocks.whereType<Task>().toList();
}

/// Finds every genuine time-overlap cluster of 2+ blocks among
/// [blocks] — pure and widget-free, same shape as
/// `recurrence_generator.dart`'s `generateRecurrenceInstances`, so the
/// grouping logic is unit-testable without touching a widget tree.
///
/// A cluster is a maximal run of consecutive (by start time) blocks where
/// each overlaps the running window opened by the ones before it —
/// mirrors `task_overlap_layout.dart`'s own grouping sweep, but this
/// function only cares about WHICH blocks share a window, not how to lay
/// them out side by side; that split is deliberate, since spatial layout
/// (columns) and "should these render as one aggregate object" are
/// different questions answered by different callers.
///
/// EVERY run of 2 or more clusters, with no upper bound — corrected
/// directly ("all should overlap as cluster mode"), reversing an earlier
/// cap of 3 that left a run of 4+ rendering as plain side-by-side
/// capsules and so produced two different overlap treatments on one day.
/// Every [Task] in [blocks] must be scheduled (`isScheduled == true`);
/// callers get their tasks from `tasksForSelectedDayProvider`, which
/// already guarantees this. An [ExternalCalendarEvent] is always
/// scheduled by construction.
List<OverlapCluster> detectOverlapClusters(List<ScheduledBlock> blocks) {
  if (blocks.length < 2) return const [];

  final sorted = [...blocks]
    ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

  final clusters = <OverlapCluster>[];
  var groupStart = 0;
  var groupEnd = sorted.first.scheduledEnd;

  for (var i = 1; i <= sorted.length; i++) {
    final startsNewGroup =
        i == sorted.length || !sorted[i].scheduledStart.isBefore(groupEnd);

    if (startsNewGroup) {
      final group = sorted.sublist(groupStart, i);
      // No upper bound: EVERY overlapping run clusters, however deep.
      // Corrected directly ("all should overlap as cluster mode") — an
      // earlier pass capped clusters at 3 and let a run of 4+ fall back to
      // plain side-by-side capsules, which is why the same day showed two
      // different overlap treatments. See docs/DECISIONS.md.
      if (group.length >= 2) {
        clusters.add(
          OverlapCluster(
            start: group.first.scheduledStart,
            end: group
                .map((b) => b.scheduledEnd)
                .reduce((a, b) => a.isAfter(b) ? a : b),
            blocks: group,
          ),
        );
      }
      if (i == sorted.length) break;
      groupStart = i;
      groupEnd = sorted[i].scheduledEnd;
    } else {
      final end = sorted[i].scheduledEnd;
      if (end.isAfter(groupEnd)) groupEnd = end;
    }
  }

  return clusters;
}

/// Every block id that belongs to one of [clusters] — the Timeline's
/// render pass uses this to decide which individual capsule/event blocks
/// to skip in favour of the aggregate block. Covers both real tasks and
/// imported events; the name is kept ("TaskIds") since every existing
/// call site already reads this as "ids to exclude from individual
/// rendering," which is equally true for an event id now included here.
Set<String> clusteredTaskIds(List<OverlapCluster> clusters) => {
  for (final cluster in clusters)
    for (final block in cluster.blocks) block.id,
};
