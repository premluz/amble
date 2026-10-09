import '../models/local_date.dart';
import '../models/recurrence_frequency.dart';
import '../models/recurrence_rule.dart';
import '../models/series.dart';
import 'recurrence_generator.dart' show recurrenceRuleIncludesWeekday;

/// Longest range one expansion may cover. Infinite series need finite
/// queries (contract §10); anything longer is a caller bug, not a request
/// to silently truncate.
const maxExpansionDays = 400;

/// Whether [series] expects an occurrence on [date], judged by the revision
/// that applied on that date (D4a).
bool isExpectedOn(Series series, LocalDate date) {
  final revision = series.revisionOn(date);
  if (revision == null) return false;
  final seriesEnd = series.endsAfter;
  if (seriesEnd != null && date.isAfter(seriesEnd)) return false;
  final ruleEnd = revision.rule.endDate;
  if (ruleEnd != null && date.isAfter(LocalDate.fromDateTime(ruleEnd))) {
    return false;
  }
  return _matchesCadence(revision.rule, series.anchor, date);
}

/// Every date in [from]..[to] (inclusive) the series expects.
Iterable<LocalDate> expectedDates(
  Series series,
  LocalDate from,
  LocalDate to,
) sync* {
  final span = from.daysUntil(to);
  if (span < 0 || span > maxExpansionDays) {
    throw RangeError(
      'Expansion range $from..$to is outside 0..'
      '$maxExpansionDays days',
    );
  }
  var date = from;
  while (!date.isAfter(to)) {
    if (isExpectedOn(series, date)) yield date;
    date = date.addDays(1);
  }
}

/// Cadence is counted from the series [anchor], never a revision's start,
/// so an every-other-week rhythm survives a later time change (§8 q1). Same
/// cadence rules as the existing materializing generator.
bool _matchesCadence(RecurrenceRule rule, LocalDate anchor, LocalDate date) {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      return anchor.daysUntil(date) % rule.interval == 0;
    case RecurrenceFrequency.weekly:
      final onWeekday = recurrenceRuleIncludesWeekday(
        rule,
        weekday: date.weekday,
        anchorWeekday: anchor.weekday,
      );
      if (!onWeekday) return false;
      final weeks =
          anchor.startOfWeek.daysUntil(date.startOfWeek) ~/
          DateTime.daysPerWeek;
      return weeks % rule.interval == 0;
  }
}
