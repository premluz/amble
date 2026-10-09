import 'package:amble/shared/models/occurrence_alert.dart';
import 'package:amble/shared/models/occurrence_key.dart';
import 'package:amble/shared/models/resolved_occurrence.dart';
import 'package:amble/shared/repositories/occurrence_alert_state_repository.dart';
import 'package:amble/shared/services/occurrence_alert_planner.dart';
import 'package:amble/shared/services/occurrence_alert_reconciler.dart';
import 'package:amble/shared/services/occurrence_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/recurrence_fixtures.dart';

class _FakeScheduler implements AlertScheduler {
  final scheduled = <int, OccurrenceAlert>{};
  final cancelled = <int>[];
  Set<int> failOn = {};

  @override
  Future<void> schedule(OccurrenceAlert alert) async {
    if (failOn.contains(alert.notificationId)) {
      throw Exception('platform failure');
    }
    scheduled[alert.notificationId] = alert;
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    scheduled.remove(notificationId);
  }
}

OccurrenceAlert _alert(int day, {String title = 'Run', int hour = 7}) =>
    OccurrenceAlert(
      key: OccurrenceKey(seriesId: seriesId, date: monday.addDays(day)),
      title: title,
      at: DateTime.utc(2026, 10, 5 + day, hour),
    );

void main() {
  initTimeZones();

  group('planner', () {
    final clock = clockAt(monday, 6 * 60);
    List<ResolvedOccurrence> resolveDays(int days) => resolveOccurrences(
      series: [
        series([revision()]),
      ],
      records: const [],
      from: monday,
      to: monday.addDays(days),
      clock: clock,
    );

    test('only upcoming occurrences inside the horizon, soonest first', () {
      final alerts = planOccurrenceAlerts(resolveDays(20), now: clock.now);
      expect(alerts, hasLength(14));
      expect(alerts.first.key.date, monday);
    });

    test('a count budget applies, not just a time window', () {
      final alerts = planOccurrenceAlerts(
        resolveDays(20),
        now: clock.now,
        budget: 3,
      );
      expect(alerts.map((a) => a.key.date), [
        monday,
        monday.addDays(1),
        monday.addDays(2),
      ]);
    });
  });

  test('S3: the payload resolves back to the occurrence key', () {
    final alert = _alert(4);
    expect(occurrenceKeyFromPayload(alert.payload), alert.key);
    expect(occurrenceKeyFromPayload('some-task-id'), isNull);
  });

  test('notification ids are fixed values, stable across runs', () {
    // Pinned to an independently computed FNV-1a of the payload: a change
    // here would orphan alerts scheduled by older builds.
    expect(_alert(0).notificationId, 518902062);
    expect(_alert(0).notificationId, isNot(_alert(1).notificationId));
  });

  group('reconciler', () {
    late Box<dynamic> box;
    late HiveOccurrenceAlertStateRepository state;
    late _FakeScheduler os;
    late OccurrenceAlertReconciler reconciler;

    setUp(() async {
      Hive.init('./.dart_tool/test_hive_occurrence_alerts');
      box = await Hive.openBox<dynamic>(
        'alerts_${DateTime.now().microsecondsSinceEpoch}',
      );
      state = HiveOccurrenceAlertStateRepository(box);
      os = _FakeScheduler();
      reconciler = OccurrenceAlertReconciler(scheduler: os, state: state);
    });

    tearDown(() => box.deleteFromDisk());

    test('touches only what differs', () async {
      await reconciler.reconcile([_alert(0), _alert(1)]);
      os.cancelled.clear();

      final report = await reconciler.reconcile([
        _alert(1),
        _alert(2, title: 'Tempo'),
      ]);
      expect(report.scheduled, 1);
      expect(report.cancelled, 1);
      expect(os.cancelled, [_alert(0).notificationId]);
      expect(
        os.scheduled.keys,
        unorderedEquals([_alert(1).notificationId, _alert(2).notificationId]),
      );
    });

    test('a changed time is rescheduled', () async {
      await reconciler.reconcile([_alert(1)]);
      await reconciler.reconcile([_alert(1, hour: 8)]);
      expect(os.scheduled.values.single.at.hour, 8);
    });

    test('a failure is reported and retried next time', () async {
      os.failOn = {_alert(1).notificationId};
      final first = await reconciler.reconcile([_alert(0), _alert(1)]);
      expect(first.failures.single.notificationId, _alert(1).notificationId);
      expect(state.getAll().keys, [_alert(0).notificationId]);

      os.failOn = {};
      final retry = await reconciler.reconcile([_alert(0), _alert(1)]);
      expect(retry.scheduled, 1);
      expect(retry.failures, isEmpty);
    });
  });
}
