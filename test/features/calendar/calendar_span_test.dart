import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/calendar/calendar_span.dart';

/// The date arithmetic behind the wide layout's Week and Month views.
void main() {
  final wed = DateTime(2026, 10, 14);

  test('a week starts on its Monday and has seven days', () {
    expect(weekStartOf(wed), DateTime(2026, 10, 12));
    expect(weekStartOf(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
    expect(weekStartOf(DateTime(2026, 10, 18)), DateTime(2026, 10, 12));
    final days = weekDaysOf(wed);
    expect(days.first, DateTime(2026, 10, 12));
    expect(days.last, DateTime(2026, 10, 18));
  });

  test('a month grid is whole weeks covering the month, Monday first', () {
    final october = monthGridOf(wed);
    expect(october.first, DateTime(2026, 9, 28));
    expect(october.last, DateTime(2026, 11, 1));
    expect(october.length % DateTime.daysPerWeek, 0);
    expect(october.length, 35);
    // February 2027 starts on a Monday and ends on a Sunday: exactly 4 rows.
    expect(monthGridOf(DateTime(2027, 2, 10)).length, 28);
    // August 2026 needs 6 rows (starts Saturday, 31 days).
    expect(monthGridOf(DateTime(2026, 8, 1)).length, 42);
  });

  test('stepping moves by the shown span', () {
    expect(stepBySpan(wed, CalendarSpan.day, 1), DateTime(2026, 10, 15));
    expect(stepBySpan(wed, CalendarSpan.week, -1), DateTime(2026, 10, 7));
    expect(stepBySpan(wed, CalendarSpan.month, 1), DateTime(2026, 11, 14));
  });

  test('a month step clamps to the shorter month', () {
    expect(
      stepBySpan(DateTime(2027, 1, 31), CalendarSpan.month, 1),
      DateTime(2027, 2, 28),
    );
    expect(
      stepBySpan(DateTime(2026, 3, 31), CalendarSpan.month, -1),
      DateTime(2026, 2, 28),
    );
  });
}
