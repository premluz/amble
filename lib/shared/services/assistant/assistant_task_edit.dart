import 'assistant_tool.dart';

/// How far a change to a repeating task reaches, as in Amble's own editor.
enum AssistantEditScope {
  /// Only this occurrence; the rest of the series is unchanged.
  thisOnly,

  /// This occurrence and every later one (a new series revision from its
  /// date; earlier occurrences keep their history).
  thisAndFollowing,
}

/// The changes an assistant asked for. Null means "leave as is".
class AssistantTaskEdit {
  const AssistantTaskEdit({
    this.title,
    this.start,
    this.durationMinutes,
    this.categoryId,
    this.important,
    this.notes,
    this.reminder,
    this.done,
    this.repeatDays,
    this.scope = AssistantEditScope.thisOnly,
  });

  final String? title;
  final DateTime? start;
  final int? durationMinutes;
  final String? categoryId;
  final bool? important;

  /// The task's description; an empty string clears it.
  final String? notes;
  final bool? reminder;
  final bool? done;

  /// Weekdays the task repeats on (`DateTime.monday`..`DateTime.sunday`).
  /// An empty set turns repeating off.
  final Set<int>? repeatDays;
  final AssistantEditScope scope;

  bool get isEmpty =>
      title == null &&
      start == null &&
      durationMinutes == null &&
      categoryId == null &&
      important == null &&
      notes == null &&
      reminder == null &&
      done == null &&
      repeatDays == null;
}

const _dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Reads a repeat request: "never", "daily", "weekdays", "weekends", or a
/// list of day names ("mon", "Tuesday"...). Returns the weekday numbers;
/// empty means "does not repeat".
Set<int> parseRepeat(Object? value) {
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'never' || 'none' || 'no' || 'off':
        return {};
      case 'daily' || 'every day' || 'everyday':
        return {for (var d = DateTime.monday; d <= DateTime.sunday; d++) d};
      case 'weekdays':
        return {for (var d = DateTime.monday; d <= DateTime.friday; d++) d};
      case 'weekends':
        return {DateTime.saturday, DateTime.sunday};
    }
    return parseRepeat(value.split(RegExp(r'[,\s]+')));
  }
  if (value is List && value.isNotEmpty) {
    return {for (final day in value) _weekday(day)};
  }
  throw const AssistantToolError(
    '"repeat" must be "never", "daily", "weekdays", "weekends" or a list of '
    'days like ["mon", "wed", "fri"].',
  );
}

int _weekday(Object? day) {
  final text = day is String ? day.trim().toLowerCase() : '';
  final index = _dayNames.indexWhere(
    (name) => text.length >= 3 && name.startsWith(text.substring(0, 3)),
  );
  if (index < 0) throw AssistantToolError('"$day" is not a day of the week.');
  return index + DateTime.monday;
}

/// `Mon, Wed, Fri`, `every day`, or `never`.
String describeRepeat(Set<int> days) {
  if (days.isEmpty) return 'never';
  if (days.length == DateTime.daysPerWeek) return 'every day';
  final sorted = days.toList()..sort();
  return [for (final d in sorted) _dayLabels[d - DateTime.monday]].join(', ');
}

/// Lower-case day names, for the task JSON the assistant reads.
List<String> repeatDayNames(Set<int> days) => [
  for (final d in days.toList()..sort()) _dayNames[d - DateTime.monday],
];
