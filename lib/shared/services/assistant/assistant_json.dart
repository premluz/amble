import '../../../features/task_detail/task_recurrence_days.dart';
import '../../models/category.dart';
import '../../models/external_calendar_event.dart';
import '../../models/task.dart';
import '../../models/zone.dart';
import '../availability.dart';
import 'assistant_args.dart';
import 'assistant_task_edit.dart';

/// The shapes the assistant sees. Times are local (`2026-10-14T09:30`);
/// field names are snake_case, as is usual for tool output.
Map<String, Object?> taskJson(Task task, Map<String, Category> categories) => {
  'id': task.id,
  'title': task.title,
  'start': localStamp(task.scheduledStart),
  'end': localStamp(task.scheduledEnd),
  'duration_minutes': task.durationMinutes,
  'status': task.status.name,
  'important': task.isImportant,
  'category': categories[task.categoryId]?.name,
  'repeats': task.isRecurring,
  if (task.recurrenceRule case final rule?)
    'repeat_days': repeatDayNames(daysFromRecurrenceRule(rule)),
};

Map<String, Object?> eventJson(ExternalCalendarEvent event) => {
  'title': event.title,
  'start': localStamp(event.start),
  'end': localStamp(event.end),
  'calendar': event.sourceCalendarName,
  'read_only': true,
};

Map<String, Object?> zoneJson(Zone zone, DateTime day) => {
  'name': zone.title,
  'date': localDate(day),
  'start': localStamp(_at(day, zone.startMinutes)),
  'end': localStamp(_at(day, zone.endMinutes)),
};

Map<String, Object?> windowJson(FreeWindow window) => {
  'start': localStamp(window.start),
  'end': localStamp(window.end),
  'minutes': window.minutes,
  'zones': window.zoneNames,
};

DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));

/// Each local day in [from]..[to) (half-open).
Iterable<DateTime> daysIn(DateTime from, DateTime to) sync* {
  for (
    var day = DateTime(from.year, from.month, from.day);
    day.isBefore(to);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    yield day;
  }
}
