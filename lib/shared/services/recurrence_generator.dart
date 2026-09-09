import '../models/category.dart';
import '../models/recurrence_frequency.dart';
import '../models/recurrence_rule.dart';
import '../models/task.dart';

/// How far ahead recurring instances are materialized.
///
/// A rolling window rather than generating to `endDate`, per
/// CONSTITUTION.md — an open-ended daily recurrence would otherwise
/// produce unbounded rows. Eight weeks is far enough that a user swiping
/// forward never hits the edge in normal use, and small enough that a
/// daily series costs ~56 rows rather than thousands.
const int recurrenceWindowWeeks = 8;

/// Materializes the [Task] instances a series still needs.
///
/// Pure and widget-free so the date arithmetic is unit-testable in
/// isolation. It **returns** new tasks rather than persisting them — the
/// caller writes them through `taskListProvider`/`TaskRepository`, so
/// generation never bypasses the normal write path.
///
/// [template] is the instance carrying the rule. [existingInstances] must
/// be every already-persisted task sharing the template's `recurrenceId`
/// (including the template itself); occurrences already covered by one are
/// skipped, which is what makes calling this repeatedly — e.g. on every app
/// launch — idempotent rather than duplicate-producing.
///
/// Returns an empty list if [template] carries no rule, or if the window is
/// already fully materialized.
List<Task> generateRecurrenceInstances({
  required Task template,
  required List<Task> existingInstances,
  required DateTime now,
  int windowWeeks = recurrenceWindowWeeks,
}) {
  final rule = template.recurrenceRule;
  final seriesId = template.recurrenceId;
  final anchor = template.scheduledAt;
  if (rule == null || seriesId == null || anchor == null) return const [];

  final windowEnd = now.add(Duration(days: windowWeeks * 7));

  // An occurrence is "already materialized" if some instance of this
  // series already occupies that CALENDAR DAY — matched per-day, not per
  // exact `DateTime`.
  //
  // Per-day rather than exact-slot is what makes generation safe against
  // the series' anchor time-of-day moving. Real bug, reported directly
  // ("see duplicates, sometimes even 2") and confirmed from an exported
  // backup: matching exact `DateTime`s meant that changing a series' time
  // (07:05 -> 08:00) shifted every occurrence slot, so NONE of the
  // already-materialized instances matched any longer and the generator
  // produced a complete parallel 8-week series on top of the existing one.
  // Repeated edits stacked up three full generations of the same daily
  // series (56 rows each, one `recurrenceId`, at 05:00 / 06:30 / 07:05),
  // 232 stranded rows in total. Per-day matching makes that structurally
  // impossible: the day is already claimed regardless of what time the
  // occupant sits at, so no second row can be fabricated for it — including
  // via the launch top-up (`materializeDueRecurrences`), which deliberately
  // does not prune and so previously refilled the whole window on every
  // restart after any anchor drift.
  //
  // A moved instance claims BOTH the day it VACATED
  // (`originalScheduledAt`) and the day it now occupies (`scheduledAt`),
  // so moving one onto another day never leaves its old day looking
  // unfilled. An unmoved instance has `originalScheduledAt == null` and
  // simply claims its own day twice over, which the Set collapses.
  //
  // Safe because one-occurrence-per-day-per-series is a real invariant of
  // the current model, not an assumption: [RecurrenceFrequency] is only
  // `daily | weekly`, and sub-daily/RRULE-style patterns are explicitly
  // deferred in SCOPE.md. A future twice-daily rule would need this keyed
  // on (day, occurrence-index) instead — flagged here so it can't be
  // missed if that ever ships.
  final takenDays = <DateTime>{
    for (final task in existingInstances) ...[
      ?_dayOf(task.originalScheduledAt),
      ?_dayOf(task.scheduledAt),
    ],
  };

  final generated = <Task>[];
  for (final occurrence in _occurrences(
    rule: rule,
    anchor: anchor,
    windowEnd: windowEnd,
  )) {
    if (takenDays.contains(_dayOf(occurrence))) continue;
    generated.add(
      Task.create(
          title: template.title,
          notes: template.notes,
          scheduledAt: occurrence,
          durationMinutes: template.durationMinutes ?? _fallbackDurationMinutes,
          categoryId: template.categoryId ?? BuiltInCategoryIds.general,
          recurrenceId: seriesId,
          // Deliberately null: only the template carries the rule.
        )
        // A recurring series linked to a tracked behavior means every
        // occurrence is an instance of that behavior, so the link is
        // inherited — per CONSTITUTION.md, the two systems compose without
        // special-casing. `actualAmount` is deliberately NOT copied: each
        // occurrence records its own outcome.
        ..behaviorId = template.behaviorId,
    );
  }
  return generated;
}

/// The calendar day [at] falls on, with its time-of-day discarded — the
/// key [generateRecurrenceInstances] matches occupancy on. Null in, null
/// out, so an unscheduled task simply claims no day at all.
DateTime? _dayOf(DateTime? at) =>
    at == null ? null : DateTime(at.year, at.month, at.day);

/// Duration used if a template somehow lacks one. Templates are always
/// created scheduled (the detail form sets time and duration together), so
/// this is a defensive floor rather than an expected path.
const int _fallbackDurationMinutes = 30;

/// Every occurrence start from [anchor] up to and including [windowEnd],
/// honouring the rule's interval, weekday set, and end date.
Iterable<DateTime> _occurrences({
  required RecurrenceRule rule,
  required DateTime anchor,
  required DateTime windowEnd,
}) sync* {
  final hardStop = rule.endDate;

  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      var current = anchor;
      while (!current.isAfter(windowEnd)) {
        if (hardStop != null && current.isAfter(_endOfDay(hardStop))) return;
        yield current;
        current = _addDaysPreservingTime(current, rule.interval);
      }

    case RecurrenceFrequency.weekly:
      // Null daysOfWeek means "same weekday as the template".
      final weekdays = (rule.daysOfWeek == null || rule.daysOfWeek!.isEmpty)
          ? <int>[anchor.weekday]
          : (rule.daysOfWeek!.toList()..sort());

      // Walk week by week from the anchor's week, emitting each selected
      // weekday within a week the interval actually lands on.
      var weekStart = _startOfWeek(anchor);
      while (!weekStart.isAfter(windowEnd)) {
        for (final weekday in weekdays) {
          final occurrence = _atTimeOf(
            anchor,
            weekStart.add(Duration(days: weekday - DateTime.monday)),
          );
          // Skip anything before the series actually starts, and anything
          // past the window or the rule's end date.
          if (occurrence.isBefore(anchor)) continue;
          if (occurrence.isAfter(windowEnd)) continue;
          if (hardStop != null && occurrence.isAfter(_endOfDay(hardStop))) {
            continue;
          }
          yield occurrence;
        }
        weekStart = _addDaysPreservingTime(weekStart, 7 * rule.interval);
      }
  }
}

/// Adds whole days without letting a DST shift move the wall-clock time —
/// `DateTime.add(Duration(days:))` adds 24h of absolute time, which lands
/// an hour off across a DST boundary. Rebuilding from calendar parts keeps
/// a 09:00 task at 09:00 year-round.
DateTime _addDaysPreservingTime(DateTime from, int days) => DateTime(
  from.year,
  from.month,
  from.day + days,
  from.hour,
  from.minute,
  from.second,
);

DateTime _startOfWeek(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day - (date.weekday - DateTime.monday),
);

DateTime _atTimeOf(DateTime timeSource, DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
  timeSource.hour,
  timeSource.minute,
  timeSource.second,
);

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59);
