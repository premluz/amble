import '../../shared/models/task.dart';
import '../../shared/models/task_status.dart';
import '../../shared/models/tracked_behavior.dart';

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The set of calendar days, within `[start, end]` inclusive, on which
/// [behavior] was completed — derived from [tasks] rather than a separate
/// completion log, since none exists: any [Task] linking back to this
/// behavior (`behaviorId == behavior.id`) whose [Task.status] is
/// [TaskStatus.completed] and whose [Task.scheduledAt] falls on a given
/// day counts as that day being done. A day with more than one completed,
/// linked task is still just one "done" day — this only answers yes/no
/// per day, not how many.
///
/// Returned as a `Set<DateTime>` of day-truncated (midnight, local)
/// dates, matching every other day-bucketing helper in this codebase
/// (`_isSameDay` in `day_strip.dart`/`zone_day_timeline.dart`).
Set<DateTime> completedDaysFor(
  TrackedBehavior behavior, {
  required List<Task> tasks,
  required DateTime start,
  required DateTime end,
}) {
  final completedDays = <DateTime>{};
  for (final task in tasks) {
    if (task.behaviorId != behavior.id) continue;
    if (task.status != TaskStatus.completed) continue;
    final scheduledAt = task.scheduledAt;
    if (scheduledAt == null) continue;
    final day = DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
    if (day.isBefore(start) || day.isAfter(end)) continue;
    completedDays.add(day);
  }
  return completedDays;
}

/// Whether [day] is completed, per [completedDays] — a plain lookup
/// helper so call sites don't each re-derive [_isSameDay] equality over a
/// `Set<DateTime>` (which works here only because every entry is already
/// truncated to midnight by [completedDaysFor], so direct `contains`
/// equality is safe).
bool isDayCompleted(Set<DateTime> completedDays, DateTime day) =>
    completedDays.contains(DateTime(day.year, day.month, day.day));

bool isToday(DateTime day, DateTime today) => _isSameDay(day, today);
