import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/local_date.dart';
import '../models/occurrence_alert.dart';
import '../models/occurrence_key.dart';
import '../models/occurrence_record.dart';
import '../models/recurrence_command.dart';
import '../models/recurrence_rule.dart';
import '../models/series_revision.dart';
import '../models/resolved_occurrence.dart';
import '../models/series.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/occurrence_alert_planner.dart';
import '../services/occurrence_alert_reconciler.dart';
import '../services/occurrence_resolver.dart';
import '../services/occurrence_task_edits.dart';
import '../services/occurrence_task_projection.dart';
import '../services/series_expansion.dart';
import 'notification_providers.dart';
import 'series_providers.dart';

const _uuid = Uuid();

/// Days resolved ahead for alerts — at least the alert horizon.
const _alertLookaheadDays = notificationHorizonDays + 1;

class OccurrenceSnapshot {
  const OccurrenceSnapshot({required this.series, required this.records});
  final List<Series> series;
  final List<OccurrenceRecord> records;
}

/// The series model's in-app state and its single entry point for changes. Every change is a [RecurrenceCommand]; after
/// each, state reloads and occurrence alerts reconcile.
class OccurrenceStore extends Notifier<OccurrenceSnapshot> {
  @override
  OccurrenceSnapshot build() => _load();

  OccurrenceSnapshot _load() => OccurrenceSnapshot(
    series: ref.read(seriesRepositoryProvider).getAll(),
    records: ref.read(occurrenceRecordRepositoryProvider).getAll(),
  );

  /// Occurrences on [day], shown as tasks for the existing Timeline.
  List<Task> tasksOn(LocalDate day) => tasksBetween(day, day);

  /// Occurrences overlapping [from]..[to] (inclusive), shown as tasks — for
  /// readers that need a range (Siri, summaries, behavior progress).
  List<Task> tasksBetween(LocalDate from, LocalDate to) =>
      occurrenceTasksBetween(
        series: state.series,
        records: state.records,
        from: from,
        to: to,
        clock: ref.read(occurrenceClockProvider)(),
      );

  Future<void> run(RecurrenceCommand command) async {
    await ref.read(recurrenceCommandServiceProvider).execute(command);
    state = _load();
    _queueReconcile();
  }

  /// Applies an edited occurrence task as "this occurrence" commands.
  Future<void> applyTaskEdit(Task edited) async {
    final builders = commandsForTaskEdit(
      current: currentTask(occurrenceKeyOfTask(edited)),
      edited: edited,
      today: ref.read(occurrenceClockProvider)().today,
    );
    final key = occurrenceKeyOfTask(edited);
    for (final build in builders) {
      await run(build(_uuid.v4(), _recordVersion(key)));
    }
  }

  /// "Remove this occurrence" — a cancellation, not a deletion (§5).
  /// Returns the command id, so Undo can reverse exactly this.
  Future<String> cancelOccurrence(String taskId) async {
    final key = occurrenceKeyFromPayload(taskId);
    if (key == null) throw StateError('$taskId is not an occurrence');
    final commandId = _uuid.v4();
    await run(
      SetOutcome(
        commandId,
        key: key,
        expectedVersion: _recordVersion(key),
        outcome: OccurrenceOutcome.cancelled,
      ),
    );
    return commandId;
  }

  /// A new repeating series starting at [startAt]; returns its first
  /// occurrence shown as a task (so callers can animate or undo it).
  Future<Task> createSeries({
    required RecurrenceRule rule,
    required DateTime startAt,
    required int durationMinutes,
    required SeriesDefaults defaults,
  }) async {
    final slot = localSlotOf(startAt);
    final seriesId = _uuid.v4();
    await run(
      CreateSeries(
        seriesId,
        firstRevision: SeriesRevision(
          effectiveFrom: slot.date,
          rule: rule,
          startMinutes: slot.minutes,
          durationMinutes: durationMinutes,
          defaults: defaults,
        ),
      ),
    );
    final first = _series(seriesId);
    final firstDate = expectedDates(
      first,
      first.anchor,
      first.anchor.addDays(maxExpansionDays),
    ).first;
    return currentTask(OccurrenceKey(seriesId: seriesId, date: firstDate));
  }

  /// "Delete series" — ends it from today; history stays. Returns the
  /// command id, so Undo can reverse exactly this.
  Future<String> endSeriesOf(Task occurrence) async {
    final series = _series(occurrenceKeyOfTask(occurrence).seriesId);
    final commandId = _uuid.v4();
    await run(
      EndSeries(
        commandId,
        seriesId: series.id,
        expectedVersion: series.version,
      ),
    );
    return commandId;
  }

  /// Reverses one command (see `RecurrenceCommandService.undo`).
  Future<void> undo(String commandId) async {
    await ref.read(recurrenceCommandServiceProvider).undo(commandId);
    state = _load();
    _queueReconcile();
  }

  /// "This and following" / "all" — a new revision from [occurrence]'s date
  /// (or today, if that is past).
  Future<void> reviseFrom(Task occurrence, SeriesRevisionDraft draft) {
    final key = occurrenceKeyOfTask(occurrence);
    final series = _series(key.seriesId);
    return run(
      ReviseSeries(
        _uuid.v4(),
        seriesId: series.id,
        expectedVersion: series.version,
        fromDate: key.date,
        draft: draft,
      ),
    );
  }

  /// The occurrence as it stands now, shown as a task.
  Task currentTask(OccurrenceKey key) => _asTask(
    resolveOccurrence(
      series: _series(key.seriesId),
      key: key,
      record: ref.read(occurrenceRecordRepositoryProvider).get(key),
      clock: ref.read(occurrenceClockProvider)(),
    ),
  );

  Future<void> _alertQueue = Future.value();

  /// Alert updates run one after another, never concurrently — two quick
  /// commands must not reconcile against the same stale state and schedule
  /// twice. A failed update is logged and the queue carries on.
  void _queueReconcile() {
    _alertQueue = _alertQueue.then((_) => reconcileAlerts()).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('Occurrence alert reconcile failed: $error\n$stackTrace');
    });
  }

  /// Completes once every queued alert update has finished.
  Future<void> get alertsSettled => _alertQueue;

  /// Brings OS alerts in line with upcoming occurrences. Failures are logged here and
  /// retried on the next reconcile.
  Future<void> reconcileAlerts() async {
    final clock = ref.read(occurrenceClockProvider)();
    final upcoming = resolveOccurrences(
      series: state.series,
      records: state.records,
      from: clock.today,
      to: clock.today.addDays(_alertLookaheadDays),
      clock: clock,
    );
    final service = ref.read(notificationServiceProvider);
    final report = await OccurrenceAlertReconciler(
      scheduler: _NotificationAlertScheduler(service),
      state: ref.read(occurrenceAlertStateRepositoryProvider),
    ).reconcile(planOccurrenceAlerts(upcoming, now: clock.now));
    for (final failure in report.failures) {
      debugPrint('Occurrence alert not updated, will retry: $failure');
    }
  }

  Task _asTask(ResolvedOccurrence occurrence) {
    final revision = _series(occurrence.key.seriesId)
        .revisionOn(occurrence.key.date);
    if (revision == null) {
      throw StateError('No revision for ${occurrence.key}');
    }
    return occurrenceAsTask(occurrence, revision.rule);
  }

  Series _series(String id) {
    final series = ref.read(seriesRepositoryProvider).get(id);
    if (series == null) throw StateError('No series $id');
    return series;
  }

  int? _recordVersion(OccurrenceKey key) =>
      ref.read(occurrenceRecordRepositoryProvider).get(key)?.version;
}

final occurrenceStoreProvider =
    NotifierProvider<OccurrenceStore, OccurrenceSnapshot>(OccurrenceStore.new);

class _NotificationAlertScheduler implements AlertScheduler {
  _NotificationAlertScheduler(this._service);
  final NotificationService _service;

  @override
  Future<void> schedule(OccurrenceAlert alert) =>
      _service.scheduleOccurrenceAlert(alert);

  @override
  Future<void> cancel(int notificationId) =>
      _service.cancelNotification(notificationId);
}
