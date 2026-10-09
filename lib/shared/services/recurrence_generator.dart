import '../models/recurrence_frequency.dart';
import '../models/recurrence_rule.dart';

/// Whether [rule] would ever generate an occurrence on [weekday]
/// (`DateTime.monday`..`DateTime.sunday`), given the series' own anchor
/// weekday for a `weekly` rule with no explicit `daysOfWeek` ("same weekday
/// as the start"). Used by the task series expansion
/// (`series_expansion.dart`).
///
/// `daily` always returns true — every calendar day is a candidate
/// regardless of weekday.
bool recurrenceRuleIncludesWeekday(
  RecurrenceRule rule, {
  required int weekday,
  required int anchorWeekday,
}) {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      return true;
    case RecurrenceFrequency.weekly:
      final weekdays = (rule.daysOfWeek == null || rule.daysOfWeek!.isEmpty)
          ? <int>[anchorWeekday]
          : rule.daysOfWeek!;
      return weekdays.contains(weekday);
  }
}

/// How far ahead recurring ZONE instances are materialized
/// (`zone_recurrence_generator.dart`). Repeating tasks no longer materialize
/// at all — their occurrences are computed (docs/RECURRENCE_CONTRACT.md).
const int recurrenceWindowWeeks = 8;
