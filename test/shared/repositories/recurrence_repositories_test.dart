import 'package:amble/shared/models/behavior_target_revision.dart';
import 'package:amble/shared/models/behavior_target_type.dart';
import 'package:amble/shared/models/occurrence_key.dart';
import 'package:amble/shared/models/occurrence_record.dart';
import 'package:amble/shared/repositories/behavior_target_history_repository.dart';
import 'package:amble/shared/repositories/occurrence_record_repository.dart';
import 'package:amble/shared/repositories/series_repository.dart';
import 'package:amble/shared/repositories/stale_write_exception.dart';
import 'package:amble/shared/repositories/zone_history_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/recurrence_fixtures.dart';

final _now = DateTime.utc(2026, 10, 5, 9);

void main() {
  late Box<dynamic> box;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_recurrence');
    box = await Hive.openBox<dynamic>(
      'recurrence_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() => box.deleteFromDisk());

  group('series', () {
    test('round-trips through storage', () async {
      final repository = HiveSeriesRepository(box);
      final s = series([revision()]);
      await repository.save(s);

      final stored = repository.get(seriesId)!;
      expect(stored.revisions.single.defaults.title, 'Run');
      expect(repository.getAll(), hasLength(1));
    });

    test('S29: a write from a stale version is rejected', () async {
      final repository = HiveSeriesRepository(box);
      final original = series([revision()]);
      await repository.save(original);

      final fromUi = original.endedAfter(monday, now: _now);
      final fromSiri = original.endedAfter(monday.addDays(1), now: _now);
      await repository.save(fromUi);

      expect(
        () => repository.save(fromSiri),
        throwsA(isA<StaleWriteException>()),
      );
      expect(repository.get(seriesId)!.endsAfter, monday);
    });
  });

  group('occurrence records', () {
    const key = OccurrenceKey(seriesId: seriesId, date: monday);

    test('one record per key: later writes update it', () async {
      final repository = HiveOccurrenceRecordRepository(box);
      final first = OccurrenceRecord(key: key, updatedAt: _now);
      await repository.save(first);
      await repository.save(first.withNote('Hills', now: _now));

      expect(repository.getAll(), hasLength(1));
      expect(repository.get(key)!.note, 'Hills');
    });

    test('a second "new" record for the same key is rejected', () async {
      final repository = HiveOccurrenceRecordRepository(box);
      await repository.save(OccurrenceRecord(key: key, updatedAt: _now));

      expect(
        () => repository.save(OccurrenceRecord(key: key, updatedAt: _now)),
        throwsA(isA<StaleWriteException>()),
      );
    });

    test('deleting a series history removes only its records', () async {
      final repository = HiveOccurrenceRecordRepository(box);
      const other = OccurrenceKey(seriesId: 'other', date: monday);
      await repository.save(OccurrenceRecord(key: key, updatedAt: _now));
      await repository.save(OccurrenceRecord(key: other, updatedAt: _now));
      await repository.deleteForSeries(seriesId);

      expect(repository.getAll().map((r) => r.key), [other]);
    });
  });

  test('behavior targets are stored by behavior and date', () async {
    final repository = HiveBehaviorTargetHistoryRepository(box);
    await repository.save(
      BehaviorTargetRevision(
        behaviorId: 'b',
        effectiveFrom: monday,
        targetType: BehaviorTargetType.duration,
        targetAmount: 60,
      ),
    );
    expect(repository.getForBehavior('b').single.targetAmount, 60);
    expect(repository.getForBehavior('x'), isEmpty);
  });

  group('zone history', () {
    test('first zone applies today; a change applies from tomorrow', () async {
      final repository = HiveZoneHistoryRepository(box);
      await repository.recordZone(london, monday);
      await repository.recordZone(london, monday.addDays(1));
      await repository.recordZone(newYork, monday.addDays(2));

      final entries = repository.load().entries;
      expect(entries.map((e) => e.zoneName), [london, newYork]);
      expect(entries.map((e) => e.effectiveFrom), [monday, monday.addDays(3)]);
      expect(
        repository.load().zoneNameOn(
          monday.addDays(2),
          today: monday.addDays(2),
          currentZone: newYork,
        ),
        london,
      );
    });
  });
}
