import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/services/day_label.dart';

void main() {
  // A Thursday, arbitrary but fixed — every case below is relative to it.
  final today = DateTime(2026, 9, 24);

  test('today reads as "Today"', () {
    expect(dayLabel(DateTime(2026, 9, 24), today: today), 'Today');
  });

  test('yesterday reads as "Yesterday"', () {
    expect(dayLabel(DateTime(2026, 9, 23), today: today), 'Yesterday');
  });

  test('2-6 days ago reads as a bare weekday name', () {
    expect(dayLabel(DateTime(2026, 9, 22), today: today), 'Tuesday');
    expect(dayLabel(DateTime(2026, 9, 18), today: today), 'Friday');
  });

  test('exactly 7 days ago falls back to a full date, not a bare weekday', () {
    // The week boundary itself — must NOT read as "Thursday" again,
    // which would be ambiguous with today.
    expect(dayLabel(DateTime(2026, 9, 17), today: today), 'Thu 17 Sep');
  });

  test('further in the past reads as "Weekday D Mon"', () {
    expect(
      dayLabel(DateTime(2026, 10, 12), today: DateTime(2026, 10, 20)),
      'Mon 12 Oct',
    );
  });

  test('a future day (edited/backdated data) still resolves, not throws', () {
    expect(dayLabel(DateTime(2026, 9, 30), today: today), 'Wed 30 Sep');
  });

  test(
    'time-of-day on either date is ignored — only the calendar day matters',
    () {
      final laterToday = DateTime(2026, 9, 24, 23, 59);
      expect(dayLabel(DateTime(2026, 9, 24, 0, 1), today: laterToday), 'Today');
    },
  );
}
