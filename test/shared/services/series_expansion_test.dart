import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/services/series_expansion.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recurrence_fixtures.dart';

List<LocalDate> _dates(Iterable<LocalDate> dates) => dates.toList();

void main() {
  test('daily every 2 days counts from the series start', () {
    final s = series([revision(rule: daily(interval: 2))]);
    expect(_dates(expectedDates(s, monday, monday.addDays(5))), [
      monday,
      monday.addDays(2),
      monday.addDays(4),
    ]);
  });

  test('weekly on chosen weekdays', () {
    final s = series([
      revision(
        rule: weekly([DateTime.monday, DateTime.wednesday, DateTime.friday]),
      ),
    ]);
    expect(_dates(expectedDates(s, monday, monday.addDays(6))), [
      monday,
      monday.addDays(2),
      monday.addDays(4),
    ]);
  });

  test('S25: every-other-week cadence survives a time change from week 5', () {
    final everyOtherMonday = weekly([DateTime.monday], interval: 2);
    final s = series([
      revision(rule: everyOtherMonday),
      revision(
        from: monday.addDays(28),
        rule: everyOtherMonday,
        start: eightAm,
      ),
    ]);
    // Weeks 0, 2, 4, 6 from the series start — week 5's revision does not
    // restart the count.
    expect(_dates(expectedDates(s, monday, monday.addDays(48))), [
      monday,
      monday.addDays(14),
      monday.addDays(28),
      monday.addDays(42),
    ]);
  });

  test('S21: changing daily to weekly keeps the past daily', () {
    final switchDay = monday.addDays(90);
    final s = series([
      revision(),
      revision(from: switchDay, rule: weekly([switchDay.weekday])),
    ]);
    expect(expectedDates(s, monday, switchDay.addDays(-1)), hasLength(90));
    expect(expectedDates(s, switchDay, switchDay.addDays(13)), hasLength(2));
  });

  test('nothing is expected after the series end or the rule end', () {
    final ended = series([revision()])
        .endedAfter(monday.addDays(1), now: DateTime.utc(2026));
    expect(expectedDates(ended, monday, monday.addDays(6)), hasLength(2));

    final ruleEnd = series([
      revision(
        rule: RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          endDate: DateTime(2026, 10, 7),
        ),
      ),
    ]);
    expect(expectedDates(ruleEnd, monday, monday.addDays(6)), hasLength(3));
  });

  test('ranges are bounded', () {
    final s = series([revision()]);
    expect(
      () =>
          expectedDates(s, monday, monday.addDays(maxExpansionDays + 1)).first,
      throwsRangeError,
    );
  });
}
