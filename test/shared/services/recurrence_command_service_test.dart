import 'package:amble/shared/models/field_override.dart';
import 'package:amble/shared/models/occurrence_key.dart';
import 'package:amble/shared/models/occurrence_plan_overrides.dart';
import 'package:amble/shared/models/occurrence_record.dart';
import 'package:amble/shared/models/recurrence_command.dart';
import 'package:amble/shared/models/record_aspect.dart';
import 'package:amble/shared/models/series_revision.dart';
import 'package:amble/shared/repositories/command_log_repository.dart';
import 'package:amble/shared/repositories/occurrence_record_repository.dart';
import 'package:amble/shared/repositories/series_repository.dart';
import 'package:amble/shared/repositories/stale_write_exception.dart';
import 'package:amble/shared/services/recurrence_command_service.dart';
import 'package:amble/shared/services/recurrence_undo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/recurrence_fixtures.dart';

const _key = OccurrenceKey(seriesId: seriesId, date: monday);
final _today = monday.addDays(3);

void main() {
  late Box<dynamic> seriesBox;
  late Box<dynamic> recordBox;
  late Box<dynamic> logBox;
  late HiveSeriesRepository seriesRepo;
  late HiveOccurrenceRecordRepository records;
  late HiveCommandLogRepository log;
  late RecurrenceCommandService service;
  late DateTime now;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_recurrence_commands');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    seriesBox = await Hive.openBox<dynamic>('s_$stamp');
    recordBox = await Hive.openBox<dynamic>('r_$stamp');
    logBox = await Hive.openBox<dynamic>('l_$stamp');
    seriesRepo = HiveSeriesRepository(seriesBox);
    records = HiveOccurrenceRecordRepository(recordBox);
    log = HiveCommandLogRepository(logBox);
    now = DateTime.utc(2026, 10, 8, 9);
    service = RecurrenceCommandService(
      series: seriesRepo,
      records: records,
      log: log,
      now: () => now,
      today: () => _today,
    );
    await seriesRepo.save(series([revision()]));
  });

  tearDown(() async {
    await seriesBox.deleteFromDisk();
    await recordBox.deleteFromDisk();
    await logBox.deleteFromDisk();
  });

  Future<void> run(RecurrenceCommand command) => service.execute(command);

  SetOutcome done(String id, {int? expected}) => SetOutcome(
    id,
    key: _key,
    expectedVersion: expected,
    outcome: OccurrenceOutcome.done,
    completionDate: monday,
  );

  group('retry & concurrency', () {
    test('S28: the same command id is applied once', () async {
      await run(SetNote('c1', key: _key, expectedVersion: null, note: 'A'));
      final retry = await service.execute(
        SetNote('c1', key: _key, expectedVersion: null, note: 'A'),
      );
      expect(retry.alreadyApplied, isTrue);
      expect(records.get(_key)!.version, OccurrenceRecord.initialVersion);
    });

    test('S29: a command based on a stale version is rejected', () async {
      await run(done('ui'));
      expect(
        () => run(SetNote('siri', key: _key, expectedVersion: null, note: 'B')),
        throwsA(isA<StaleWriteException>()),
      );
    });

    test(
      'creating a series twice with one command id makes one series',
      () async {
        final create = CreateSeries('new-series', firstRevision: revision());
        await run(create);
        await run(create);
        expect(
          seriesRepo.getAll().where((s) => s.id == 'new-series'),
          hasLength(1),
        );
      },
    );
  });

  group('undo', () {
    test('S16: undoing "done" leaves no record behind', () async {
      await run(done('c1'));
      await service.undo('c1');
      expect(records.get(_key), isNull);
    });

    test('S17: value 30 → 45 → undo → 30', () async {
      await run(
        SetMeasuredValue('a', key: _key, expectedVersion: null, value: 30),
      );
      await run(
        SetMeasuredValue('b', key: _key, expectedVersion: 1, value: 45),
      );
      await service.undo('b');
      expect(records.get(_key)!.measuredValue, 30);
    });

    test('S18: undoing "done" keeps a note added afterwards', () async {
      await run(done('c1'));
      await run(SetNote('c2', key: _key, expectedVersion: 1, note: 'Hills'));
      await service.undo('c1');

      final record = records.get(_key)!;
      expect(record.outcome, OccurrenceOutcome.none);
      expect(record.note, 'Hills');
    });

    test('S19: undo is refused once its own field changed', () async {
      await run(done('c1'));
      await run(
        SetOutcome(
          'c2',
          key: _key,
          expectedVersion: 1,
          outcome: OccurrenceOutcome.skipped,
        ),
      );
      expect(() => service.undo('c1'), throwsA(isA<UndoConflictException>()));
      expect(records.get(_key)!.outcome, OccurrenceOutcome.skipped);
    });

    test('undoing twice does nothing the second time', () async {
      await run(done('c1'));
      await service.undo('c1');
      await service.undo('c1');
      expect(records.get(_key), isNull);
    });

    test('reset to series via inherited fields, then undo', () async {
      await run(
        OverridePlan(
          'c1',
          key: _key,
          expectedVersion: null,
          plan: const OccurrencePlanOverrides(title: SetTo('Long run')),
          fields: {RecordAspect.title},
        ),
      );
      await run(
        OverridePlan(
          'c2',
          key: _key,
          expectedVersion: 1,
          plan: const OccurrencePlanOverrides(),
          fields: RecordAspect.planFields,
        ),
      );
      expect(records.get(_key), isNull);

      await service.undo('c2');
      expect(records.get(_key)!.plan.title, isA<SetTo<String>>());
    });
  });

  group('series edits', () {
    SeriesRevisionDraft draft({int start = eightAm}) => SeriesRevisionDraft(
      rule: daily(),
      startMinutes: start,
      durationMinutes: 45,
      defaults: const SeriesDefaults(title: 'Run'),
    );

    test('an edit from a past occurrence takes effect today (D4a)', () async {
      await run(
        ReviseSeries(
          'c1',
          seriesId: seriesId,
          expectedVersion: 1,
          fromDate: monday,
          draft: draft(),
        ),
      );
      final s = seriesRepo.get(seriesId)!;
      expect(s.revisions.last.effectiveFrom, _today);
      expect(s.revisionOn(monday)!.startMinutes, sevenAm);
    });

    test(
      'S20: undoing a series edit restores the previous revisions',
      () async {
        await run(
          ReviseSeries(
            'c1',
            seriesId: seriesId,
            expectedVersion: 1,
            fromDate: _today,
            draft: draft(),
          ),
        );
        await service.undo('c1');
        final s = seriesRepo.get(seriesId)!;
        expect(s.revisions, hasLength(1));
        expect(s.version, 3);
      },
    );

    test('S20: undo is refused when a later series edit exists', () async {
      await run(
        ReviseSeries(
          'c1',
          seriesId: seriesId,
          expectedVersion: 1,
          fromDate: _today,
          draft: draft(),
        ),
      );
      await run(
        ReviseSeries(
          'c2',
          seriesId: seriesId,
          expectedVersion: 2,
          fromDate: _today.addDays(2),
          draft: draft(start: 600),
        ),
      );
      expect(() => service.undo('c1'), throwsA(isA<UndoConflictException>()));
    });

    test('ending a series stops it from today and keeps history', () async {
      await run(done('c0'));
      await run(EndSeries('c1', seriesId: seriesId, expectedVersion: 1));
      expect(seriesRepo.get(seriesId)!.endsAfter, _today.addDays(-1));
      expect(records.get(_key), isNotNull);
    });

    test('undoing a series creation is refused once it has data', () async {
      await run(CreateSeries('s2', firstRevision: revision()));
      await run(
        SetNote(
          'c1',
          key: const OccurrenceKey(seriesId: 's2', date: monday),
          expectedVersion: null,
          note: 'x',
        ),
      );
      expect(() => service.undo('s2'), throwsA(isA<UndoConflictException>()));
    });
  });

  test('the command log is pruned after its retention window', () async {
    await run(done('c1'));
    now = now.add(commandLogRetention + const Duration(minutes: 1));
    await service.pruneLog();
    expect(log.get('c1'), isNull);
  });
}
