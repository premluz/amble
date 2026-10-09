import 'package:amble/shared/models/behavior_target_revision.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
import 'package:amble/shared/models/field_override.dart';
import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/models/occurrence_key.dart';
import 'package:amble/shared/models/occurrence_plan_overrides.dart';
import 'package:amble/shared/models/occurrence_record.dart';
import 'package:amble/shared/models/series.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/recurrence_fixtures.dart';

final _now = DateTime.utc(2026, 10, 12, 9);
const _key = OccurrenceKey(seriesId: seriesId, date: monday);

void main() {
  group('LocalDate', () {
    test('parses, formats and rejects impossible dates', () {
      expect(LocalDate.parse('2026-10-05'), monday);
      expect(monday.toIso(), '2026-10-05');
      expect(() => LocalDate.parse('2026-02-30'), throwsFormatException);
      expect(() => LocalDate.parse('5/10/2026'), throwsFormatException);
    });

    test('day arithmetic is unaffected by DST', () {
      const beforeFallBack = LocalDate(2026, 10, 24);
      expect(beforeFallBack.addDays(2), const LocalDate(2026, 10, 26));
      expect(monday.daysUntil(const LocalDate(2026, 11, 2)), 28);
      expect(const LocalDate(2026, 10, 8).startOfWeek, monday);
    });
  });

  group('OccurrenceRecord', () {
    test('round-trips every override state, outcome and value', () {
      final record = OccurrenceRecord(
        key: _key,
        updatedAt: _now,
        plan: OccurrencePlanOverrides(
          start: SetTo(OccurrenceStart(date: monday.addDays(4), minutes: 600)),
          title: const SetTo('Long run'),
          description: const Clear(),
        ),
        outcome: OccurrenceOutcome.done,
        completionDate: monday.addDays(4),
        outcomeRecordedAt: _now,
        measuredValue: 30,
        note: 'Felt good',
      );
      final restored = OccurrenceRecord.fromJson(record.toJson());

      expect(restored.key, _key);
      expect(restored.plan.start, isA<SetTo<OccurrenceStart>>());
      expect(restored.plan.title, isA<SetTo<String>>());
      expect(restored.plan.description, isA<Clear<String>>());
      expect(restored.plan.durationMinutes, isA<Inherit<int>>());
      expect(restored.outcome, OccurrenceOutcome.done);
      expect(restored.completionDate, monday.addDays(4));
      expect(restored.measuredValue, 30);
      expect(restored.note, 'Felt good');
    });

    test('a title cannot be stored as cleared', () {
      final json = OccurrenceRecord(key: _key, updatedAt: _now).toJson();
      (json['plan'] as Map<String, dynamic>)['title'] = {'clear': true};
      expect(() => OccurrenceRecord.fromJson(json), throwsFormatException);
    });

    test('D1: note, value and outcome never touch plan fields', () {
      final record = OccurrenceRecord(key: _key, updatedAt: _now)
          .withNote('Rainy', now: _now)
          .withMeasuredValue(20, now: _now)
          .withOutcome(OccurrenceOutcome.skipped, now: _now);

      expect(record.plan.isEmpty, isTrue);
      expect(record.hasContent, isTrue);
      expect(record.version, OccurrenceRecord.initialVersion + 3);
    });

    test('"done" requires a completion date, other outcomes forbid one', () {
      final record = OccurrenceRecord(key: _key, updatedAt: _now);
      expect(
        () => record.withOutcome(OccurrenceOutcome.done, now: _now),
        throwsArgumentError,
      );
      final undone = record
          .withOutcome(
            OccurrenceOutcome.done,
            now: _now,
            completionDate: monday,
          )
          .withOutcome(OccurrenceOutcome.none, now: _now);
      expect(undone.isEmpty, isTrue);
    });
  });

  group('Series', () {
    test('round-trips with its revision history', () {
      final s = series([
        revision(),
        revision(from: monday.addDays(14), start: eightAm, title: 'AM run'),
      ]);
      final restored = Series.fromJson(s.toJson());

      expect(restored.revisions, hasLength(2));
      expect(restored.revisionOn(monday.addDays(13))!.startMinutes, sevenAm);
      expect(restored.revisionOn(monday.addDays(14))!.defaults.title, 'AM run');
      expect(restored.revisionOn(monday.addDays(-1)), isNull);
    });

    test('a new revision replaces revisions on or after its date', () {
      final s =
          series([
            revision(),
            revision(from: monday.addDays(14), start: eightAm),
          ]).withRevision(
            revision(from: monday.addDays(7), title: 'X'),
            now: _now,
          );

      expect(s.revisions.map((r) => r.effectiveFrom), [
        monday,
        monday.addDays(7),
      ]);
      expect(s.version, Series.initialVersion + 1);
    });

    test('an edit from a past occurrence takes effect today (D4a)', () {
      final today = monday.addDays(10);
      expect(Series.effectiveDateFor(monday, today), today);
      expect(
        Series.effectiveDateFor(today.addDays(2), today),
        today.addDays(2),
      );
    });
  });

  test('S22: targets are judged by the occurrence date, not record time', () {
    final revisions = [
      BehaviorTargetRevision(
        behaviorId: 'b',
        effectiveFrom: monday,
        targetType: BehaviorTargetType.duration,
        targetAmount: 60,
      ),
      BehaviorTargetRevision(
        behaviorId: 'b',
        effectiveFrom: monday.addDays(1),
        targetType: BehaviorTargetType.duration,
        targetAmount: 30,
      ),
    ];
    final restored = revisions
        .map((r) => BehaviorTargetRevision.fromJson(r.toJson()))
        .toList();

    expect(
      behaviorTargetOn(restored, behaviorId: 'b', date: monday)!.targetAmount,
      60,
    );
    expect(
      behaviorTargetOn(
        restored,
        behaviorId: 'b',
        date: monday.addDays(2),
      )!.targetAmount,
      30,
    );
  });
}
