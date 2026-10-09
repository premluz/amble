import 'package:amble/shared/models/field_override.dart';
import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/models/occurrence_key.dart';
import 'package:amble/shared/models/occurrence_plan_overrides.dart';
import 'package:amble/shared/models/occurrence_record.dart';
import 'package:amble/shared/models/resolved_occurrence.dart';
import 'package:amble/shared/models/series.dart';
import 'package:amble/shared/services/occurrence_resolver.dart';
import 'package:amble/shared/services/occurrence_timing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recurrence_fixtures.dart';

final _written = DateTime.utc(2026, 10, 1);
final _weekdays = weekly([1, 2, 3, 4, 5]);
final _friday = monday.addDays(4);

OccurrenceKey _key(LocalDate date) =>
    OccurrenceKey(seriesId: seriesId, date: date);

OccurrenceRecord _record(LocalDate date) =>
    OccurrenceRecord(key: _key(date), updatedAt: _written);

OccurrenceRecord _movedTo(LocalDate from, LocalDate to, int minutes) =>
    _record(from).withPlan(
      OccurrencePlanOverrides(
        start: SetTo(OccurrenceStart(date: to, minutes: minutes)),
      ),
      now: _written,
    );

List<ResolvedOccurrence> _resolve(
  Series s,
  LocalDate from,
  OccurrenceClock clock, {
  LocalDate? to,
  List<OccurrenceRecord> records = const [],
  bool includeCancelled = false,
}) => resolveOccurrences(
  series: [s],
  records: records,
  from: from,
  to: to ?? from,
  clock: clock,
  includeCancelled: includeCancelled,
);

void main() {
  initTimeZones();
  final afterWeek = clockAt(monday.addDays(7), 12 * 60);

  group('identity & resolution', () {
    test('S1: a moved occurrence shows only on its new day, same key', () {
      final s = series([revision()]);
      final records = [_movedTo(monday, _friday, 6 * 60)];

      expect(_resolve(s, monday, afterWeek, records: records), isEmpty);
      final friday = _resolve(s, _friday, afterWeek, records: records);
      expect(friday.map((o) => o.key), [_key(monday), _key(_friday)]);
    });

    test('S2: 23:00–01:00 appears on both days, once each', () {
      final s = series([revision(start: 23 * 60, duration: 120)]);
      final tuesday = _resolve(s, monday.addDays(1), afterWeek);
      expect(tuesday.map((o) => o.key), [
        _key(monday),
        _key(monday.addDays(1)),
      ]);
    });

    test('S5/S8: a note survives a series time change, as one item', () {
      final thursday = monday.addDays(3);
      final s = series([revision()]).withRevision(
        revision(from: thursday, start: eightAm),
        now: _written,
      );
      final note = _record(thursday).withNote('Hills', now: _written);
      final result = _resolve(
        s,
        thursday,
        clockAt(monday, 9 * 60),
        records: [note],
      );

      expect(result, hasLength(1));
      expect(result.single.key, _key(thursday));
      expect(result.single.start, londonTime(thursday, 8));
      expect(result.single.note, 'Hills');
    });

    test('S6/S9: cancelled stays cancelled and is hidden, even if moved', () {
      final s = series([revision()]);
      final cancelled = _movedTo(
        monday,
        _friday,
        sevenAm,
      ).withOutcome(OccurrenceOutcome.cancelled, now: _written);
      expect(
        _resolve(s, _friday, afterWeek, records: [cancelled]),
        hasLength(1),
      );
      final all = _resolve(
        s,
        _friday,
        afterWeek,
        records: [cancelled],
        includeCancelled: true,
      );
      final moved = all.singleWhere((o) => o.key == _key(monday));
      expect(moved.status, OccurrenceStatus.cancelled);
    });

    test('S7: data on a dropped weekday stays visible outside the plan', () {
      final nextMonday = monday.addDays(7);
      final s =
          series([
            revision(rule: weekly([1, 3, 5])),
          ]).withRevision(
            revision(from: monday.addDays(1), rule: weekly([2, 4])),
            now: _written,
          );
      final records = [
        _record(nextMonday).withNote('Physio', now: _written),
        _movedTo(monday.addDays(9), monday.addDays(9), 600),
      ];
      final result = _resolve(
        s,
        nextMonday,
        clockAt(monday, 9 * 60),
        to: monday.addDays(9),
        records: records,
      );

      expect(result.map((o) => o.key.date), [nextMonday, monday.addDays(8)]);
      expect(result.first.outsideCurrentPlan, isTrue);
      expect(result.first.countsAsExpected, isFalse);
    });

    test('a duplicate record or a record without a series fails loudly', () {
      final s = series([revision()]);
      expect(
        () => _resolve(
          s,
          monday,
          afterWeek,
          records: [_record(monday), _record(monday)],
        ),
        throwsStateError,
      );
      final orphan = OccurrenceRecord(
        key: OccurrenceKey(seriesId: 'gone', date: monday),
        updatedAt: _written,
      );
      expect(
        () => _resolve(s, monday, afterWeek, records: [orphan]),
        throwsStateError,
      );
    });
  });

  group('inheritance', () {
    test('S10/S11: overridden and cleared fields ignore series changes', () {
      final thursday = monday.addDays(3);
      final s = series([revision(description: 'Easy')]).withRevision(
        revision(from: monday.addDays(2), title: 'Tempo', description: 'Hard'),
        now: _written,
      );
      final record = _record(thursday).withPlan(
        const OccurrencePlanOverrides(
          title: SetTo('Long run'),
          description: Clear(),
        ),
        now: _written,
      );
      final result = _resolve(s, thursday, afterWeek, records: [record]).single;
      expect(result.title, 'Long run');
      expect(result.description, isNull);
    });
  });

  group('outcomes & streak foundation', () {
    test('S12/S13: a week of facts, with expected = 4', () {
      final s = series([revision(rule: _weekdays)]);
      final records = [
        _record(monday).withOutcome(
          OccurrenceOutcome.done,
          now: _written,
          completionDate: monday,
        ),
        _record(monday.addDays(1)).withMeasuredValue(30, now: _written),
        _record(monday.addDays(2))
            .withOutcome(OccurrenceOutcome.skipped, now: _written),
        _record(monday.addDays(3))
            .withOutcome(OccurrenceOutcome.cancelled, now: _written),
        _record(_friday).withNote('Tired', now: _written),
      ];
      final week = _resolve(
        s,
        monday,
        afterWeek,
        to: _friday,
        records: records,
        includeCancelled: true,
      );

      expect(week.map((o) => o.status), [
        OccurrenceStatus.done,
        OccurrenceStatus.omitted,
        OccurrenceStatus.skipped,
        OccurrenceStatus.cancelled,
        OccurrenceStatus.omitted,
      ]);
      expect(week[1].measuredValue, 30);
      expect(week[4].note, 'Tired');
      expect(week.where((o) => o.countsAsExpected), hasLength(4));
    });

    test('S14: moved Monday done Friday keeps both dates', () {
      final s = series([revision()]);
      final record = _movedTo(monday, _friday, 6 * 60).withOutcome(
        OccurrenceOutcome.done,
        now: _written,
        completionDate: _friday,
      );
      final done = _resolve(s, _friday, afterWeek, records: [record]).first;
      expect(done.key.date, monday);
      expect(done.completionDate, _friday);
    });

    test('S15: 23:00–01:00 is upcoming at 00:30, omitted at 01:00', () {
      final s = series([revision(start: 23 * 60, duration: 120)]);
      final tuesday = monday.addDays(1);
      expect(
        _resolve(s, monday, clockAt(tuesday, 30)).first.status,
        OccurrenceStatus.upcoming,
      );
      expect(
        _resolve(s, monday, clockAt(tuesday, 60)).first.status,
        OccurrenceStatus.omitted,
      );
    });
  });

  group('history & time', () {
    test('S23: renaming the series keeps past titles', () {
      final today = monday.addDays(3);
      final s = series([revision()]).withRevision(
        revision(from: Series.effectiveDateFor(monday, today), title: 'AM run'),
        now: _written,
      );
      final result = _resolve(s, monday, clockAt(today, 9 * 60), to: today);
      expect(result.first.title, 'Run');
      expect(result.last.title, 'AM run');
    });

    test('S24: flying west never revives an omitted day', () {
      final s = series([revision()]);
      final clock = clockAt(
        monday,
        19 * 60 + 30,
        zone: newYork,
        history: [
          zoneEntry(const LocalDate(2026, 1, 1), london),
          zoneEntry(monday.addDays(1), newYork),
        ],
      );
      expect(
        _resolve(s, monday, clock).single.status,
        OccurrenceStatus.omitted,
      );
    });

    test('S27: future days float to the current zone', () {
      final s = series([revision()]);
      final clock = clockAt(
        monday,
        9 * 60,
        zone: newYork,
        history: [zoneEntry(const LocalDate(2026, 1, 1), london)],
      );
      final later = _resolve(s, monday.addDays(2), clock).single;
      expect(later.start.toUtc(), DateTime.utc(2026, 10, 7, 11));
    });

    test('S26: a time in the spring-forward gap shifts by the gap', () {
      const springForward = LocalDate(2026, 3, 29);
      final s = series([revision(from: springForward, start: 90)]);
      final result = _resolve(s, springForward, afterWeek).single;
      expect(result.start.toUtc(), DateTime.utc(2026, 3, 29, 1, 30));
    });

    test('a repeated fall-back time resolves to its first occurrence', () {
      const fallBack = LocalDate(2026, 10, 25);
      final s = series([revision(from: fallBack, start: 90, duration: 120)]);
      final result = _resolve(s, fallBack, afterWeek).single;
      expect(result.start.toUtc(), DateTime.utc(2026, 10, 25, 0, 30));
      expect(result.end.difference(result.start), const Duration(hours: 2));
    });
  });
}
