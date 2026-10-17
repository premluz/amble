import 'assistant_tool.dart';

/// Reading and checking tool input. Every failure is an
/// [AssistantToolError] the assistant can act on.
extension AssistantArgsReading on AssistantArgs {
  String requireString(String key) {
    final value = this[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw AssistantToolError('"$key" is required.');
  }

  String? optionalString(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    throw AssistantToolError('"$key" must be text.');
  }

  int intOr(String key, int fallback, {required int min, required int max}) {
    final value = this[key] ?? fallback;
    if (value is! num || value != value.roundToDouble()) {
      throw AssistantToolError('"$key" must be a whole number.');
    }
    final whole = value.toInt();
    if (whole < min || whole > max) {
      throw AssistantToolError('"$key" must be between $min and $max.');
    }
    return whole;
  }

  bool boolOr(String key, bool fallback) {
    final value = this[key] ?? fallback;
    if (value is bool) return value;
    throw AssistantToolError('"$key" must be true or false.');
  }

  /// A local calendar date, `YYYY-MM-DD`.
  DateTime requireDate(String key) {
    final date = DateTime.tryParse(requireString(key));
    if (date == null) {
      throw AssistantToolError('"$key" must be a date like 2026-10-14.');
    }
    return DateTime(date.year, date.month, date.day);
  }

  /// A local date and time, `YYYY-MM-DDTHH:MM`. A time zone suffix is
  /// refused rather than silently converted: every time in Amble is local.
  DateTime requireLocalDateTime(String key) {
    final text = requireString(key);
    final parsed = DateTime.tryParse(text);
    if (parsed == null ||
        parsed.isUtc ||
        RegExp(r'[+-]\d\d:?\d\d$').hasMatch(text)) {
      throw AssistantToolError(
        '"$key" must be a local time like 2026-10-14T09:30, with no time zone.',
      );
    }
    return parsed;
  }

  /// A [from]..[to] date range (end date inclusive) as a half-open span,
  /// no longer than [AssistantLimits.maxRangeDays].
  (DateTime, DateTime) requireRange() {
    final from = requireDate('from');
    final to = requireDate('to');
    if (to.isBefore(from)) {
      throw const AssistantToolError('"to" must not be before "from".');
    }
    final end = DateTime(to.year, to.month, to.day + 1);
    if (end.difference(from).inDays > AssistantLimits.maxRangeDays) {
      throw const AssistantToolError(
        'Ask about ${AssistantLimits.maxRangeDays} days or fewer at a time.',
      );
    }
    return (from, end);
  }
}

/// `2026-10-14T09:30`, the local form the tools read and write.
String localStamp(DateTime time) =>
    '${_date(time)}T${_two(time.hour)}:${_two(time.minute)}';

String localDate(DateTime time) => _date(time);

/// `Tue 13 Oct, 10:00`: how a change reads in Amble's activity list and
/// Undo toast. Fixed English names, matching the app's other copy.
String friendlyTime(DateTime time) =>
    '${_weekdays[time.weekday - 1]} ${time.day} ${_months[time.month - 1]}, '
    '${_two(time.hour)}:${_two(time.minute)}';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
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

String _date(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}';

String _two(int value) => value.toString().padLeft(2, '0');
