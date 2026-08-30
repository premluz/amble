import '../models/task.dart';

/// Pure, widget-free check for whether a candidate time slot overlaps any
/// other scheduled task — the data-side counterpart to
/// `features/timeline/task_overlap_layout.dart`'s side-by-side rendering.
/// That file assumes overlaps are allowed and lays them out visually; this
/// one is used only when the "Prevent overlapping tasks" preference is on,
/// to reject a create/move before it's written. Same half-open interval
/// semantics as `_layoutGroup`/`_endOf` there, mirrored rather than shared
/// since the two live in different layers (this is `shared/services/`, that
/// is a `features/timeline/` rendering concern).
///
/// Completed tasks still count as blocking — the point of the preference is
/// a realistic view of what's actually occupying the day, and a completed
/// task occupied its slot just as much as a pending one. Only the candidate
/// itself (via [excludeTaskId]) is ever excluded.
bool overlapsExistingTask({
  required DateTime scheduledAt,
  required int durationMinutes,
  required List<Task> existingTasks,
  String? excludeTaskId,
}) {
  final candidateEnd = scheduledAt.add(Duration(minutes: durationMinutes));

  for (final other in existingTasks) {
    if (other.id == excludeTaskId) continue;
    if (!other.isScheduled) continue;

    final otherStart = other.scheduledAt!;
    if (otherStart.year != scheduledAt.year ||
        otherStart.month != scheduledAt.month ||
        otherStart.day != scheduledAt.day) {
      continue;
    }

    final otherEnd = otherStart.add(Duration(minutes: other.durationMinutes!));
    // Half-open interval: back-to-back tasks (one ending exactly when the
    // other starts) do not count as overlapping.
    if (scheduledAt.isBefore(otherEnd) && otherStart.isBefore(candidateEnd)) {
      return true;
    }
  }

  return false;
}
