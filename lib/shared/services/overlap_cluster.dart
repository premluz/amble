import '../models/task.dart';

/// The most tasks one [OverlapCluster] can hold. A 4th task overlapping an
/// existing cluster's window is left OUT of the cluster entirely (rendered
/// as its own ordinary capsule, still spatially overlapping the cluster) —
/// this is a deliberate, narrow choice for a case the visual design never
/// specified a treatment for, not a general "clusters cap at 3, extras
/// vanish" rule. See docs/DECISIONS.md for the reasoning.
const overlapClusterCap = 3;

/// A contiguous run of 2–3 [Task]s that genuinely intersect in time —
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

/// Finds every genuine time-overlap cluster of 2–3 tasks among
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
/// A run longer than [overlapClusterCap] is NOT clustered at all — see
/// [overlapClusterCap]'s own doc comment for why a 4th overlapping task
/// is left out of clustering entirely rather than guessing a treatment.
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
      if (group.length >= 2 && group.length <= overlapClusterCap) {
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
