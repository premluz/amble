import 'package:flutter/material.dart';

import '../calendar/calendar_span.dart';
import 'task_sheet_form.dart';

/// What the panel's repeat line says: "Repeat" while off, else "Every
/// day", "Weekdays", or the chosen days in week order.
String taskRepeatLabel(TaskSheetForm form) {
  if (!form.repeats) return 'Repeat';
  final days = form.selectedDays;
  if (days.length == DateTime.daysPerWeek) return 'Every day';
  if (days.length == _weekdays.length && days.containsAll(_weekdays)) {
    return 'Weekdays';
  }
  return (days.toList()..sort())
      .map((d) => weekdayShortNames[d - 1])
      .join(', ');
}

/// The clock time [minutes] after [start], wrapping past midnight.
TimeOfDay taskEndTime(TimeOfDay start, int minutes) {
  const day = Duration.minutesPerDay;
  final total =
      (start.hour * Duration.minutesPerHour + start.minute + minutes) % day;
  return TimeOfDay(
    hour: total ~/ Duration.minutesPerHour,
    minute: total % Duration.minutesPerHour,
  );
}

const _weekdays = {
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
};
