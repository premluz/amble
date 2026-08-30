import '../models/task.dart';

/// One task's move as part of a cascade — paired with the task's id (not the
/// [Task] object itself) so callers can look the live task up fresh before
/// writing, the same way every other mutator in this codebase resolves its
/// own `Task` reference immediately before a repository write.
class TaskMove {
  const TaskMove({required this.taskId, required this.newScheduledAt});

  final String taskId;
  final DateTime newScheduledAt;
}

/// Algorithm, worked out by hand against the two examples confirmed with the
/// user before this was implemented (see docs/DECISIONS.md for the full
/// derivation, including where the user's own restated numbers had a slip):
///
/// Existing task E (11:00–12:00, 60min) with a task dragged to a new start
/// of 11:45 (60min duration, so its new end is 12:45): the dragged task's
/// new *start* (11:45) is 15 minutes from E's end (12:00) and 45 minutes
/// from E's start (11:00) — E's end is the nearer edge, so E shifts
/// *earlier*, keeping its own 60-minute duration, so its end lands exactly
/// on the dragged task's new start: E becomes 10:45–11:45.
///
/// Same existing task, dragged instead to a new start of 10:15 (new end
/// 11:15): now E's start (11:00) is 45 minutes from the dragged new start
/// and E's end (12:00) is 105 minutes away — E's start is nearer, so E
/// shifts *later*. Because E must clear the whole dragged block (not just
/// its start), E's new start lands on the dragged task's new *end*
/// (11:15), so E becomes 11:15–12:15 — this is the case verified exactly
/// against the user's own worked numbers (their stated "12:115" is a typo
/// for 12:15).
///
/// So the rule is asymmetric by design, not an oversight: pushing a task
/// earlier only has to clear the mover's *start* (nothing after that start
/// belongs to the mover from E's new position), while pushing a task later
/// has to clear the mover's *end* (E is now sitting right after the whole
/// mover, not just its start).
///
/// Cascade: after E is placed at its new slot, if that slot now overlaps a
/// third task, that task is pushed the same way (comparing against E's own
/// new edges), and so on — in whichever direction the chain naturally
/// extends. A single visited-task-id guard (never push the same task twice
/// in one cascade) caps the chain length and prevents infinite loops from a
/// pathological cycle.
///
/// Day-boundary guard: if any resulting move would place a task starting
/// before 00:00 or ending after 24:00 of the day the dragged task started
/// on, the whole cascade is invalid — returns null so the caller can snap
/// the drag back as if it never happened. Nothing partially applies.
List<TaskMove>? computeCascadeMoves({
  required Task draggedTask,
  required DateTime newStart,
  required List<Task> sameDayTasks,
}) {
  final dayStart = DateTime(newStart.year, newStart.month, newStart.day);
  final dayEnd = dayStart.add(const Duration(days: 1));

  final draggedDuration = Duration(minutes: draggedTask.durationMinutes!);
  final draggedEnd = newStart.add(draggedDuration);
  if (newStart.isBefore(dayStart) || draggedEnd.isAfter(dayEnd)) return null;

  // Working slot table: taskId -> (start, end), seeded with every other
  // same-day scheduled task at its current slot, plus the dragged task at
  // its proposed new slot. The dragged task is looked up by id below so a
  // cascade can never re-push it.
  final slots = <String, (DateTime start, DateTime end)>{
    for (final task in sameDayTasks)
      task.id: (task.scheduledAt!, _endOf(task)),
  };
  slots[draggedTask.id] = (newStart, draggedEnd);

  final moves = <String, DateTime>{draggedTask.id: newStart};
  final pending = <String>[draggedTask.id];
  final visited = <String>{draggedTask.id};

  // Cap the chain at the number of participating tasks — a cascade can
  // never legitimately need to push more tasks than exist that day, so
  // exceeding this bound means a cycle, not a valid long chain.
  final maxChainLength = sameDayTasks.length + 1;

  while (pending.isNotEmpty) {
    if (visited.length > maxChainLength) return null;

    final moverId = pending.removeAt(0);
    final (moverStart, moverEnd) = slots[moverId]!;

    // Every task overlapping `moverId`'s slot must be pushed — but when
    // MULTIPLE tasks overlap the same mover simultaneously, they can't
    // each be computed independently from the mover's edges: a real bug
    // (confirmed by reproduction) did exactly that and let 3 same-
    // direction pushes all land on the identical slot, since none of them
    // was ever checked against the others, only against the shared mover.
    // Fixed by first computing which DIRECTION each conflicting task
    // pushes (still decided by its own distance to the mover's edges —
    // that part of the rule is unchanged), then chaining same-direction
    // pushes against one another in position order, so each one clears
    // the one before it rather than colliding with it.
    final earlierPushes = <Task>[];
    final laterPushes = <Task>[];
    for (final other in sameDayTasks) {
      if (visited.contains(other.id)) continue;
      final (otherStart, otherEnd) = slots[other.id]!;
      // Half-open interval overlap, matching task_overlap_layout.dart /
      // overlap_checker.dart's convention: back-to-back is not an overlap.
      final overlaps =
          moverStart.isBefore(otherEnd) && otherStart.isBefore(moverEnd);
      if (!overlaps) continue;

      final distanceToEnd = (moverStart.difference(otherEnd)).abs();
      final distanceToStart = (moverStart.difference(otherStart)).abs();
      if (distanceToEnd <= distanceToStart) {
        earlierPushes.add(other);
      } else {
        laterPushes.add(other);
      }
    }

    // Earlier-pushed tasks chain backward from the mover's new start,
    // nearest-original-end first — the task whose end was closest to the
    // mover lands immediately before it, and each one further out lands
    // immediately before THAT one, so the whole group shifts earlier as a
    // contiguous, non-overlapping block.
    earlierPushes.sort(
      (a, b) => slots[b.id]!.$2.compareTo(slots[a.id]!.$2),
    );
    var earlierEdge = moverStart;
    for (final task in earlierPushes) {
      // Preferred direction first (earlier, per this task's own proximity
      // to the mover's edges), then the OPPOSITE direction as a fallback.
      // Requested directly: a drop should never be rejected just because
      // the preferred side ran out of day — "can't think of case that
      // should not be allowed to drop to a busy already taken zone, it'd
      // just move other items up down or some up some down." Without the
      // fallback, a cluster late in the evening rejected the whole drag
      // even though shifting those tasks earlier would have fit fine.
      final placed =
          _findFreeSlot(
            slots,
            visited,
            taskId: task.id,
            edge: earlierEdge,
            duration: slots[task.id]!.$2.difference(slots[task.id]!.$1),
            searchEarlier: true,
            dayStart: dayStart,
            dayEnd: dayEnd,
          ) ??
          _findFreeSlot(
            slots,
            visited,
            taskId: task.id,
            edge: moverEnd,
            duration: slots[task.id]!.$2.difference(slots[task.id]!.$1),
            searchEarlier: false,
            dayStart: dayStart,
            dayEnd: dayEnd,
          );
      // Genuinely unsatisfiable — no room anywhere in the day, in either
      // direction. Only reachable when the day is packed close to its
      // full 24 hours, which a 2h-per-task cap makes rare.
      if (placed == null) return null;

      slots[task.id] = placed;
      moves[task.id] = placed.$1;
      visited.add(task.id);
      pending.add(task.id);
      earlierEdge = placed.$1;
    }

    // Same idea forward: later-pushed tasks chain from the mover's new
    // end, nearest-original-start first.
    laterPushes.sort(
      (a, b) => slots[a.id]!.$1.compareTo(slots[b.id]!.$1),
    );
    var laterEdge = moverEnd;
    for (final task in laterPushes) {
      // Mirror of the earlier-direction block above, same fallback.
      final placed =
          _findFreeSlot(
            slots,
            visited,
            taskId: task.id,
            edge: laterEdge,
            duration: slots[task.id]!.$2.difference(slots[task.id]!.$1),
            searchEarlier: false,
            dayStart: dayStart,
            dayEnd: dayEnd,
          ) ??
          _findFreeSlot(
            slots,
            visited,
            taskId: task.id,
            edge: moverStart,
            duration: slots[task.id]!.$2.difference(slots[task.id]!.$1),
            searchEarlier: true,
            dayStart: dayStart,
            dayEnd: dayEnd,
          );
      if (placed == null) return null;

      slots[task.id] = placed;
      moves[task.id] = placed.$1;
      visited.add(task.id);
      pending.add(task.id);
      laterEdge = placed.$2;
    }

    if (visited.length > maxChainLength) return null;
  }

  return [
    for (final entry in moves.entries)
      TaskMove(taskId: entry.key, newScheduledAt: entry.value),
  ];
}

DateTime _endOf(Task task) =>
    task.scheduledAt!.add(Duration(minutes: task.durationMinutes!));

/// The slot of the first already-placed (`visited`) task — other than
/// [excludeId], the one currently being positioned — that overlaps
/// [start]..[end]. Null means the candidate slot is genuinely clear. Only
/// checks `visited` entries: an unvisited task hasn't been assigned a
/// final slot yet, so it can't meaningfully "block" a placement — it's
/// still waiting to be pushed itself.
/// Finds a free slot of [duration] for [taskId], starting at [edge] and
/// walking away from it — backward when [searchEarlier], forward
/// otherwise — past any already-placed task in the way, until either the
/// slot is genuinely clear or the search runs off the end of the day.
///
/// Returns null when no free slot exists in that direction, which is the
/// caller's signal to try the opposite direction before giving up.
(DateTime, DateTime)? _findFreeSlot(
  Map<String, (DateTime, DateTime)> slots,
  Set<String> visited, {
  required String taskId,
  required DateTime edge,
  required Duration duration,
  required bool searchEarlier,
  required DateTime dayStart,
  required DateTime dayEnd,
}) {
  var start = searchEarlier ? edge.subtract(duration) : edge;
  var end = start.add(duration);

  while (true) {
    if (start.isBefore(dayStart) || end.isAfter(dayEnd)) return null;

    final collision = _firstOccupiedOverlap(
      slots,
      visited,
      excludeId: taskId,
      start: start,
      end: end,
    );
    if (collision == null) return (start, end);

    // Skip past the blocking task, continuing in the same direction.
    if (searchEarlier) {
      end = collision.$1;
      start = end.subtract(duration);
    } else {
      start = collision.$2;
      end = start.add(duration);
    }
  }
}

(DateTime, DateTime)? _firstOccupiedOverlap(
  Map<String, (DateTime, DateTime)> slots,
  Set<String> visited, {
  required String excludeId,
  required DateTime start,
  required DateTime end,
}) {
  for (final id in visited) {
    if (id == excludeId) continue;
    final (occupiedStart, occupiedEnd) = slots[id]!;
    // Half-open interval overlap, matching the rest of this file's
    // back-to-back-is-not-an-overlap convention.
    if (start.isBefore(occupiedEnd) && occupiedStart.isBefore(end)) {
      return (occupiedStart, occupiedEnd);
    }
  }
  return null;
}
