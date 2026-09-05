import '../models/task.dart';

/// A contiguous run of 2+ [Task]s that genuinely intersect in time —
/// candidates for the Timeline's aggregate [OverlapClusterBlock] instead of
/// individual capsule blocks.
class OverlapCluster {
  const OverlapCluster({
    required this.start,
    required this.end,
    required this.tasks,
  });

  /// `min(scheduledAt)` across every task in the cluster.
  final DateTime start;

  /// `max(scheduledAt + durationMinutes)` across every task in the cluster.
  final DateTime end;

  /// The cluster's tasks, chronological by `scheduledAt` — the order both
  /// the icon stack (earliest task's icon on top) and the row list read
  /// off directly, so this list's order IS the display order.
  final List<Task> tasks;
}

/// Finds every genuine time-overlap cluster of 2+ tasks among
/// [tasks] — pure and widget-free, same shape as
/// `recurrence_generator.dart`'s `generateRecurrenceInstances`, so the
/// grouping logic is unit-testable without touching a widget tree.
///
/// A cluster is a maximal run of consecutive (by start time) tasks where
/// each overlaps the running window opened by the ones before it —
/// mirrors `task_overlap_layout.dart`'s own grouping sweep, but this
/// function only cares about WHICH tasks share a window, not how to lay
/// them out side by side; that split is deliberate, since spatial layout
/// (columns) and "should these render as one aggregate object" are
/// different questions answered by different callers.
///
/// EVERY run of 2 or more clusters, with no upper bound — corrected
/// directly ("all should overlap as cluster mode"), reversing an earlier
/// cap of 3 that left a run of 4+ rendering as plain side-by-side
/// capsules and so produced two different overlap treatments on one day.
/// Every [tasks] entry must be scheduled (`isScheduled == true`); callers
/// get their tasks from `tasksForSelectedDayProvider`, which already
/// guarantees this.
List<OverlapCluster> detectOverlapClusters(List<Task> tasks) {
  if (tasks.length < 2) return const [];

  final sorted = [...tasks]
    ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

  final clusters = <OverlapCluster>[];
  var groupStart = 0;
  var groupEnd = _endOf(sorted.first);

  for (var i = 1; i <= sorted.length; i++) {
    final startsNewGroup =
        i == sorted.length || !sorted[i].scheduledAt!.isBefore(groupEnd);

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
            start: group.first.scheduledAt!,
            end: group.map(_endOf).reduce((a, b) => a.isAfter(b) ? a : b),
            tasks: group,
          ),
        );
      }
      if (i == sorted.length) break;
      groupStart = i;
      groupEnd = _endOf(sorted[i]);
    } else {
      final end = _endOf(sorted[i]);
      if (end.isAfter(groupEnd)) groupEnd = end;
    }
  }

  return clusters;
}

/// Every task id that belongs to one of [clusters] — the Timeline's render
/// pass uses this to decide which individual capsule blocks to skip in
/// favour of the aggregate block.
Set<String> clusteredTaskIds(List<OverlapCluster> clusters) => {
  for (final cluster in clusters)
    for (final task in cluster.tasks) task.id,
};

DateTime _endOf(Task task) =>
    task.scheduledAt!.add(Duration(minutes: task.durationMinutes!));
