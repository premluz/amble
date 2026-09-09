import '../models/task.dart';
import 'cascade_reschedule.dart';

/// Computes a group move for Edit Mode's multi-task route (requested
/// directly: "moving one, they would move as a group") — the SAME time
/// delta applied to every selected task, never a per-member cascade push
/// against unselected tasks (confirmed via AskUserQuestion: the existing
/// push algorithm was derived for one dragged task vs. others, and running
/// it per member would let selected tasks push each other unpredictably).
///
/// Clamps rather than rejecting outright (confirmed via AskUserQuestion):
/// if the requested [deltaMinutes] would carry any member before 00:00 or
/// its end past 24:00 of that member's OWN day, [deltaMinutes] is shrunk
/// (toward zero) just enough that every member still fits its own day —
/// so a group spanning most of the day still moves by whatever the
/// tightest member allows, rather than the whole gesture doing nothing.
/// A group already sitting at zero room to move (deltaMinutes clamps to
/// exactly 0) returns an empty list — nothing to write.
List<TaskMove> computeGroupMoves({
  required List<Task> selectedTasks,
  required int deltaMinutes,
}) {
  if (selectedTasks.isEmpty || deltaMinutes == 0) return const [];

  var clampedDelta = deltaMinutes;
  for (final task in selectedTasks) {
    final start = task.scheduledAt!;
    final dayStart = DateTime(start.year, start.month, start.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final duration = Duration(minutes: task.durationMinutes!);

    if (clampedDelta > 0) {
      // Moving later — the binding constraint is the member's own END
      // landing past this day's midnight.
      final maxEnd = dayEnd.difference(start.add(duration)).inMinutes;
      if (maxEnd < clampedDelta) clampedDelta = maxEnd;
    } else {
      // Moving earlier — the binding constraint is the member's own
      // START landing before this day's midnight.
      final minStart = dayStart.difference(start).inMinutes;
      if (minStart > clampedDelta) clampedDelta = minStart;
    }
  }

  if (clampedDelta == 0) return const [];

  return [
    for (final task in selectedTasks)
      TaskMove(
        taskId: task.id,
        newScheduledAt: task.scheduledAt!.add(Duration(minutes: clampedDelta)),
      ),
  ];
}
