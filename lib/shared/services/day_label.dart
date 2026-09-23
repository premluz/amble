const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// A chat-style date-divider label for [day], relative to [today] —
/// requested directly for the Inbox's new day-grouped list: "Today" /
/// "Yesterday" / a bare weekday name for the rest of the last 7 days /
/// "Fri 12 Oct" beyond that, "similar pattern to chat messaging separating
/// messages belonging to that day."
///
/// [today] is a parameter (not read internally via `DateTime.now()`) so
/// this stays a pure, directly-testable function — the caller passes
/// `DateTime.now()` in production and a fixed date in tests, the same
/// "now is an input, not a hidden read" pattern already used elsewhere in
/// this codebase (e.g. `parseQuickCapture`'s own `now` parameter).
String dayLabel(DateTime day, {required DateTime today}) {
  final d = _dateOnly(day);
  final t = _dateOnly(today);
  final diff = t.difference(d).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  // A week is the boundary chat apps typically use for a bare weekday
  // name before falling back to a full date — confirmed via the user's
  // own example sequence ("Today / Yesterday / Wednesday / Fri 12 Oct").
  if (diff > 1 && diff < 7) return _weekdayNames[d.weekday - 1];

  return '${_weekdayNames[d.weekday - 1].substring(0, 3)} '
      '${d.day} ${_monthAbbreviations[d.month - 1]}';
}
