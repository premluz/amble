import 'package:amble/features/timeline/selected_date_provider.dart';
import 'package:amble/features/timeline/tasks_for_selected_day_provider.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/occurrence_alert.dart';
import 'package:amble/shared/models/occurrence_key.dart';
import 'package:amble/shared/models/occurrence_record.dart';
import 'package:amble/shared/models/recurrence_command.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/occurrence_store.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/series_providers.dart';
import 'package:amble/shared/providers/series_routing_task_repository.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/command_log_repository.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/repositories/occurrence_alert_state_repository.dart';
import 'package:amble/shared/repositories/occurrence_record_repository.dart';
import 'package:amble/shared/repositories/series_repository.dart';
import 'package:amble/shared/repositories/zone_history_repository.dart';
import 'package:amble/shared/services/occurrence_task_projection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../support/fake_notification_service.dart';
import '../../support/recurrence_fixtures.dart';

class _AlertRecordingService extends FakeNotificationService {
  final scheduled = <int, OccurrenceAlert>{};

  @override
  Future<void> scheduleOccurrenceAlert(OccurrenceAlert alert) async =>
      scheduled[alert.notificationId] = alert;

  @override
  Future<void> cancelNotification(int notificationId) async =>
      scheduled.remove(notificationId);
}

const _key = OccurrenceKey(seriesId: seriesId, date: monday);

void main() {
  initTimeZones();
  late List<Box<dynamic>> boxes;
  late Box<Task> taskBox;
  late ProviderContainer container;
  late _AlertRecordingService notifications;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_series_wiring');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('tasks_$stamp');
    boxes = [
      for (final name in ['s', 'r', 'l', 'z', 'a', 'p'])
        await Hive.openBox<dynamic>('${name}_$stamp'),
    ];
    notifications = _AlertRecordingService();
    late final ProviderContainer created;
    created = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(
          SeriesRoutingTaskRepository(
            HiveTaskRepository(taskBox),
            () => created.read(occurrenceStoreProvider.notifier),
          ),
        ),
        seriesRepositoryProvider.overrideWithValue(
          HiveSeriesRepository(boxes[0]),
        ),
        occurrenceRecordRepositoryProvider.overrideWithValue(
          HiveOccurrenceRecordRepository(boxes[1]),
        ),
        commandLogRepositoryProvider.overrideWithValue(
          HiveCommandLogRepository(boxes[2]),
        ),
        zoneHistoryRepositoryProvider.overrideWithValue(
          HiveZoneHistoryRepository(boxes[3]),
        ),
        occurrenceAlertStateRepositoryProvider.overrideWithValue(
          HiveOccurrenceAlertStateRepository(boxes[4]),
        ),
        preferencesRepositoryProvider.overrideWithValue(
          HivePreferencesRepository(boxes[5]),
        ),
        occurrenceClockProvider.overrideWithValue(
          () => clockAt(monday, 6 * 60),
        ),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
    container = created;
    await container
        .read(occurrenceStoreProvider.notifier)
        .run(CreateSeries(seriesId, firstRevision: revision()));
  });

  tearDown(() async {
    await container.read(occurrenceStoreProvider.notifier).alertsSettled;
    container.dispose();
    await taskBox.deleteFromDisk();
    for (final box in boxes) {
      await box.deleteFromDisk();
    }
  });

  OccurrenceStore store() => container.read(occurrenceStoreProvider.notifier);
  Task mondayRun() => store().tasksOn(monday).single;
  TaskList tasks() => container.read(taskListProvider.notifier);
  OccurrenceRecord? record() =>
      container.read(occurrenceRecordRepositoryProvider).get(_key);

  test('an occurrence appears as a task at its wall-clock time', () {
    final run = mondayRun();
    expect(run.id, occurrenceTaskId(_key));
    expect(run.scheduledAt, DateTime(2026, 10, 5, 7));
    expect(run.durationMinutes, 45);
  });

  test('completing through TaskList records an outcome, not a task', () async {
    await tasks().toggleComplete(mondayRun());

    expect(record()!.outcome, OccurrenceOutcome.done);
    expect(record()!.completionDate, monday);
    expect(mondayRun().status, TaskStatus.completed);
    expect(taskBox.isEmpty, isTrue);
  });

  test('dragging through TaskList moves only this occurrence', () async {
    await tasks().rescheduleTask(mondayRun(), DateTime(2026, 10, 5, 9, 30));

    expect(mondayRun().scheduledAt, DateTime(2026, 10, 5, 9, 30));
    expect(record()!.outcome, OccurrenceOutcome.none);
    expect(
      store().tasksOn(monday.addDays(1)).single.scheduledAt,
      DateTime(2026, 10, 6, 7),
    );
  });

  test('removing an occurrence cancels it rather than deleting', () async {
    await tasks().deleteTask(occurrenceTaskId(_key));

    expect(store().tasksOn(monday), isEmpty);
    expect(record()!.outcome, OccurrenceOutcome.cancelled);
  });

  test('deleting the series ends it from today and keeps history', () async {
    await tasks().toggleComplete(mondayRun());
    await tasks().deleteTaskSeries(mondayRun());

    final series = container.read(seriesRepositoryProvider).get(seriesId)!;
    expect(series.endsAfter, monday.addDays(-1));
    expect(record()!.outcome, OccurrenceOutcome.done);
  });

  test('a note edit keeps every plan field inherited (D1)', () async {
    final run = mondayRun()..notes = 'Hills';
    await tasks().updateTask(run);

    expect(record()!.note, 'Hills');
    expect(record()!.plan.isEmpty, isTrue);
  });

  test('alerts follow the series, and stop once it ends', () async {
    await store().reconcileAlerts();
    expect(notifications.scheduled, isNotEmpty);
    expect(
      occurrenceKeyFromPayload(notifications.scheduled.values.first.payload),
      _key,
    );

    await tasks().deleteTaskSeries(mondayRun());
    await store().reconcileAlerts();
    expect(notifications.scheduled, isEmpty);
  });

  test('the Timeline day includes series occurrences', () {
    container.read(selectedDateProvider.notifier).goTo(DateTime(2026, 10, 5));
    expect(container.read(tasksForSelectedDayProvider).map((t) => t.id), [
      occurrenceTaskId(_key),
    ]);
  });

  test('createTask with a rule creates a series, not task rows', () async {
    final first = await tasks().createTask(
      title: 'Swim',
      scheduledAt: DateTime(2026, 10, 7, 18),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.health,
      recurrenceRule: weekly([DateTime.wednesday]),
    );

    expect(isOccurrenceTaskId(first.id), isTrue);
    expect(first.scheduledAt, DateTime(2026, 10, 7, 18));
    expect(taskBox.isEmpty, isTrue);
    final wednesday = monday.addDays(9);
    expect(store().tasksOn(wednesday).map((t) => t.title), contains('Swim'));

    // Quick capture's Undo for a repeating capture removes the series.
    await tasks().undoSeriesChange(first.recurrenceId!);
    expect(
      store().tasksOn(wednesday).map((t) => t.title),
      isNot(contains('Swim')),
    );
  });

  test('cancelling one occurrence, then Undo, restores it', () async {
    final commandId = await tasks().cancelOccurrence(mondayRun());
    expect(store().tasksOn(monday), isEmpty);

    await tasks().undoSeriesChange(commandId);
    expect(store().tasksOn(monday).single.id, occurrenceTaskId(_key));
  });

  test('ending the series, then Undo, brings it back', () async {
    final commandId = await tasks().deleteTaskSeries(mondayRun());
    await tasks().undoSeriesChange(commandId);
    expect(
      container.read(seriesRepositoryProvider).get(seriesId)!.endsAfter,
      isNull,
    );
  });

  test(
    'task lists derived from the task store never include occurrences',
    () async {
      await tasks().toggleComplete(mondayRun());
      expect(container.read(taskListProvider), isEmpty);
    },
  );
}
