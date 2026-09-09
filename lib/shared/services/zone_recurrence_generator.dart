import '../models/recurrence_frequency.dart';
import '../models/recurrence_rule.dart';
import '../models/zone.dart';
import 'recurrence_generator.dart' show recurrenceWindowWeeks;

/// Materializes the [Zone] instances a series still needs — mirrors
/// [generateRecurrenceInstances] (`recurrence_generator.dart`) as closely
/// as possible, per CONSTITUTION.md's "materialized instances, not virtual
/// expansion" pattern, applied to Zone.
///
/// Pure and widget-free so the date arithmetic is unit-testable in
/// isolation. It **returns** new zones rather than persisting them — the
/// caller writes them through `zoneListProvider`/`ZoneRepository`, so
/// generation never bypasses the normal write path.
///
/// [template] is the instance carrying the rule (`Zone.recurrenceRule`) and
/// the series' anchor day (`Zone.anchorDate`). [existingInstances] must be
/// every already-persisted zone sharing the template's `recurrenceId`
/// (including the template itself); occurrences already covered by one are
/// skipped, which is what makes calling this repeatedly — e.g. on every app
/// launch — idempotent rather than duplicate-producing.
///
/// Every generated instance shares the template's `startMinutes`/
/// `endMinutes` uniformly — per-day-varying start/end times are explicitly
/// out of scope this session (CONSTITUTION.md's still-deferred
/// per-occurrence-adjustable-times fork).
///
/// Returns an empty list if [template] carries no rule, or if the window is
/// already fully materialized.
List<Zone> generateZoneRecurrenceInstances({
  required Zone template,
  required List<Zone> existingInstances,
  required DateTime now,
  int windowWeeks = recurrenceWindowWeeks,
}) {
  final rule = template.recurrenceRule;
  final seriesId = template.recurrenceId;
  final anchor = template.anchorDate;
  if (rule == null || seriesId == null || anchor == null) return const [];

  final windowEnd = now.add(Duration(days: windowWeeks * 7));

  // An occurrence is "already materialized" if some instance of this series
  // already occupies that CALENDAR DAY — matched per-day, exactly like
  // `generateRecurrenceInstances`'s own `takenDays` set. Zone resize (this
  // session) only ever changes an instance's `startMinutes`/`endMinutes`,
  // never which day it occupies, so there is no `originalScheduledAt`-
  // equivalent to also claim here — one field (`anchorDate`) is always the
  // full story for a Zone instance's day.
  final takenDays = <DateTime>{
    for (final zone in existingInstances)
      if (zone.anchorDate != null) _dayOnly(zone.anchorDate!),
  };

  final generated = <Zone>[];
  for (final occurrenceDay in _occurrenceDays(
    rule: rule,
    anchor: _dayOnly(anchor),
    windowEnd: windowEnd,
  )) {
    if (takenDays.contains(occurrenceDay)) continue;
    generated.add(
      Zone.create(
        title: template.title,
        startMinutes: template.startMinutes,
        endMinutes: template.endMinutes,
        notificationsEnabled: template.notificationsEnabled,
        recurrenceId: seriesId,
        anchorDate: occurrenceDay,
        // Deliberately null: only the template carries the rule.
      ),
    );
  }
  return generated;
}

DateTime _dayOnly(DateTime at) => DateTime(at.year, at.month, at.day);

/// Every occurrence day from [anchor] up to and including [windowEnd],
/// honouring the rule's interval, weekday set, and end date. Same shape as
/// `recurrence_generator.dart`'s private `_occurrences`, simplified to bare
/// calendar days since a Zone anchor carries no time-of-day of its own.
Iterable<DateTime> _occurrenceDays({
  required RecurrenceRule rule,
  required DateTime anchor,
  required DateTime windowEnd,
}) sync* {
  final hardStop = rule.endDate == null ? null : _dayOnly(rule.endDate!);

  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      var current = anchor;
      while (!current.isAfter(windowEnd)) {
        if (hardStop != null && current.isAfter(hardStop)) return;
        yield current;
        current = _addDays(current, rule.interval);
      }

    case RecurrenceFrequency.weekly:
      // Null daysOfWeek means "same weekday as the template".
      final weekdays = (rule.daysOfWeek == null || rule.daysOfWeek!.isEmpty)
          ? <int>[anchor.weekday]
          : (rule.daysOfWeek!.toList()..sort());

      var weekStart = _startOfWeek(anchor);
      while (!weekStart.isAfter(windowEnd)) {
        for (final weekday in weekdays) {
          final occurrence = weekStart.add(
            Duration(days: weekday - DateTime.monday),
          );
          if (occurrence.isBefore(anchor)) continue;
          if (occurrence.isAfter(windowEnd)) continue;
          if (hardStop != null && occurrence.isAfter(hardStop)) continue;
          yield occurrence;
        }
        weekStart = _addDays(weekStart, 7 * rule.interval);
      }
  }
}

/// Adds whole days without letting a DST shift move the wall-clock time —
/// same reasoning as `recurrence_generator.dart`'s own
/// `_addDaysPreservingTime`, simplified since a bare day has no time-of-day
/// to preserve.
DateTime _addDays(DateTime from, int days) =>
    DateTime(from.year, from.month, from.day + days);

DateTime _startOfWeek(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day - (date.weekday - DateTime.monday),
);
