import '../models/task.dart';

/// One task's trim as part of a drop resolution — a NEW start time (only
/// ever pushed forward, to clear whatever is in front of it) plus a NEW,
/// shrunken duration. Paired with the task's id, not the [Task] object
/// itself, matching [TaskMove]-style callers that look the live task up
/// fresh before writing (`cascade_reschedule.dart`'s own `TaskMove`).
class TaskTrim {
  const TaskTrim({
    required this.taskId,
    required this.newScheduledAt,
    required this.newDurationMinutes,
  });

  final String taskId;
  final DateTime newScheduledAt;
  final int newDurationMinutes;
}

/// A task trimmed below [minTrimmedDurationMinutes] reads as unusable on
/// the timeline (barely a sliver, no room for its own title) — the same
/// floor manual resize already enforces (`timeline_screen.dart`'s own
/// `_minDurationMinutes`, currently 5). A task that can't be shrunk to fit
/// this floor is pushed entirely past the conflict instead (its whole
/// slot moves later, duration unchanged) rather than trimmed into
/// something unusable.
const minTrimmedDurationMinutes = 5;

/// The "Trim" drop resolution: when a dropped/moved task's new slot
/// overlaps one or more existing same-day tasks, each directly-conflicting
/// task is shortened to start exactly where the thing in front of it now
/// ends, rather than being relocated (Push) or left overlapping (Overlap).
///
/// Walks forward through same-day tasks in start-time order, tracking a
/// single "frontier" — initially the dragged task's own new end. Any task
/// starting before the frontier and overlapping the claimed region (i.e.
/// ending after the dragged task's own new start — not merely after the
/// frontier, since a task fully CONTAINED within the claimed region still
/// conflicts even though it ends before the frontier) is resolved: its
/// start moves to the frontier, and either its duration shrinks by the
/// same amount (a trim) or, if that would shrink it below
/// [minTrimmedDurationMinutes] (including going negative, for a task
/// fully swallowed by the claimed region), it keeps its original duration
/// and is pushed wholesale instead (still starting at the frontier).
/// Either way the frontier then advances to that task's own new end, so a
/// task after it that only conflicted because of the FIRST task's
/// original position gets re-checked against the first task's new, later
/// end — this is the chaining: confirmed via AskUserQuestion to chain
/// through as many tasks as needed, mirroring Push all's own chaining,
/// rather than stopping at the first conflict.
///
/// Deliberately one-directional (forward only) — unlike
/// [computeCascadeMoves], which can push a task earlier OR later depending
/// on which edge is nearer. Trim's whole premise is "make room after the
/// drop by shortening what follows"; a task that starts before the dragged
/// task's own new start is never a candidate (the frontier walk simply
/// never reaches back before its own starting point).
///
/// Day-boundary guard: if resolving a conflict (whether by trim or by the
/// wholesale-push fallback) would push a task's end past 24:00 of the day
/// the dragged task started on, the whole trim is invalid — returns null
/// so the caller can fall back or snap back, exactly like
/// [computeCascadeMoves]'s own day-boundary rule. Nothing partially
/// applies.
List<TaskTrim>? computeTrimMoves({
  required Task draggedTask,
  required DateTime newStart,
  required List<Task> sameDayTasks,
}) {
  final dayStart = DateTime(newStart.year, newStart.month, newStart.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final draggedDuration = Duration(minutes: draggedTask.durationMinutes!);
  var frontier = newStart.add(draggedDuration);
  if (newStart.isBefore(dayStart) || frontier.isAfter(dayEnd)) return null;

  final candidates =
      sameDayTasks.where((t) => t.id != draggedTask.id).toList()
        ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

  final trims = <String, TaskTrim>{};
  final slotStart = <String, DateTime>{
    for (final t in candidates) t.id: t.scheduledAt!,
  };
  final slotEnd = <String, DateTime>{
    for (final t in candidates) t.id: _endOf(t),
  };

  for (final task in candidates) {
    final start = slotStart[task.id]!;
    final end = slotEnd[task.id]!;

    // Sorted by start, so once a task starts at/after the current
    // frontier, every remaining candidate does too — nothing left to
    // resolve.
    if (!start.isBefore(frontier)) break;

    // A task ending at/before the dragged task's own new start sits
    // entirely before the claimed region — no overlap (half-open
    // interval, matching cascade_reschedule.dart / overlap_checker.dart's
    // convention). Note this compares against the drop's own start, not
    // the walking frontier: a task fully CONTAINED within the claimed
    // region (e.g. starts and ends inside [newStart, frontier)) still
    // overlaps and must be resolved, even though its end is before the
    // current frontier.
    if (!end.isAfter(newStart)) continue;

    final originalDuration = end.difference(start);
    final trimmedMinutes = end.difference(frontier).inMinutes;

    final int newDurationMinutes;
    if (trimmedMinutes >= minTrimmedDurationMinutes) {
      // Trim: start moves to the frontier, end stays exactly where it was.
      newDurationMinutes = trimmedMinutes;
    } else {
      // Too short to trim in place — push the whole task past the
      // frontier instead, keeping its original duration.
      newDurationMinutes = originalDuration.inMinutes;
    }

    final resolvedStart = frontier;
    final resolvedEnd = resolvedStart.add(
      Duration(minutes: newDurationMinutes),
    );
    if (resolvedEnd.isAfter(dayEnd)) return null;

    trims[task.id] = TaskTrim(
      taskId: task.id,
      newScheduledAt: resolvedStart,
      newDurationMinutes: newDurationMinutes,
    );
    slotStart[task.id] = resolvedStart;
    slotEnd[task.id] = resolvedEnd;
    frontier = resolvedEnd;
  }

  return trims.values.toList();
}

DateTime _endOf(Task task) =>
    task.scheduledAt!.add(Duration(minutes: task.durationMinutes!));
