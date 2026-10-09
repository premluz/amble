import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many days the wide layout's Days page shows at once. Phones always
/// show one day.
enum CalendarSpan { day, week, month }

class CalendarSpanNotifier extends Notifier<CalendarSpan> {
  @override
  CalendarSpan build() => CalendarSpan.day;

  void set(CalendarSpan span) => state = span;
}

final calendarSpanProvider =
    NotifierProvider<CalendarSpanNotifier, CalendarSpan>(
      CalendarSpanNotifier.new,
    );

/// The Monday on or before [date] (weeks start on Monday, as the app's day
/// chips and the Patterns week do).
DateTime weekStartOf(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

/// The seven days of [date]'s week, Monday first.
List<DateTime> weekDaysOf(DateTime date) {
  final start = weekStartOf(date);
  return [
    for (var i = 0; i < DateTime.daysPerWeek; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// Whole weeks covering [date]'s month, Monday first: 4 to 6 rows of 7.
List<DateTime> monthGridOf(DateTime date) {
  final first = DateTime(date.year, date.month);
  final last = DateTime(date.year, date.month + 1, 0);
  final start = weekStartOf(first);
  final end = weekStartOf(last);
  final days = <DateTime>[];
  for (var d = start; !d.isAfter(end) || d.weekday != DateTime.monday;) {
    days.add(d);
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return days;
}

/// [date] moved one [span] forward ([direction] 1) or back (-1). A month
/// step keeps the day where it can, clamped to the new month's length.
DateTime stepBySpan(DateTime date, CalendarSpan span, int direction) =>
    switch (span) {
      CalendarSpan.day => DateTime(date.year, date.month, date.day + direction),
      CalendarSpan.week => DateTime(
        date.year,
        date.month,
        date.day + direction * DateTime.daysPerWeek,
      ),
      CalendarSpan.month => _monthStep(date, direction),
    };

DateTime _monthStep(DateTime date, int direction) {
  final lastDay = DateTime(date.year, date.month + direction + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;
  return DateTime(date.year, date.month + direction, day);
}

/// Short weekday names, Monday first (index `weekday - 1`). English only,
/// like the rest of the app's labels.
const weekdayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
