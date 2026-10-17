import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/occurrence_key.dart';
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

import 'package:amble/shared/models/local_date.dart';
import 'package:amble/shared/providers/assistant_backend.dart';
import 'package:amble/shared/services/assistant/assistant_task_edit.dart';

/// `edit_task` through the real save paths: the task list, the series
/// store and its routing repository, exactly as Amble's own editor saves.
const _monday = OccurrenceKey(seriesId: seriesId, date: monday);
final _backendProvider = Provider<AppAssistantBackend>(AppAssistantBackend.new);

void main() {
  initTimeZones();
  late List<Box<dynamic>> boxes;
  late Box<Task> taskBox;
  late ProviderContainer container;
  late FakeNotificationService notifications;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_series_wiring');
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapters();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('tasks_$stamp');
    boxes = [
      for (final name in ['s', 'r', 'l', 'z', 'a', 'p'])
        await Hive.openBox<dynamic>('${name}_$stamp'),
    ];
    notifications = FakeNotificationService();
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
  AppAssistantBackend backend() => container.read(_backendProvider);
  Task on(LocalDate day) => store().tasksOn(day).single;
  Task mondayRun() => backend().taskById(occurrenceTaskId(_monday))!;

  group('a one-off task', () {
    late Task task;

    setUp(() async {
      task = Task.create(
        title: 'Dentist',
        scheduledAt: DateTime(2026, 10, 6, 9),
        durationMinutes: 30,
        categoryId: 'general',
      );
      await taskBox.put(task.id, task);
    });

    test('fields change in place; undo puts them back', () async {
      final undo = await backend().editTask(
        task,
        const AssistantTaskEdit(title: 'Dentist (check-up)', important: true),
      );
      expect(taskBox.get(task.id)!.title, 'Dentist (check-up)');
      expect(taskBox.get(task.id)!.isImportant, isTrue);
      await undo!();
      expect(taskBox.get(task.id)!.title, 'Dentist');
      expect(taskBox.get(task.id)!.isImportant, isFalse);
    });

    test(
      'turning repeat on replaces it with a series; undo restores it',
      () async {
        final undo = await backend().editTask(
          task,
          const AssistantTaskEdit(repeatDays: {DateTime.tuesday}),
        );
        expect(taskBox.get(task.id), isNull);
        final repeating = store()
            .tasksOn(monday.addDays(1))
            .where((t) => t.title == 'Dentist');
        expect(repeating.single.isRecurring, isTrue);
        expect(
          store().tasksOn(monday.addDays(8)).where((t) => t.title == 'Dentist'),
          hasLength(1),
          reason: 'and again the next Tuesday',
        );

        await undo!();
        expect(taskBox.get(task.id)!.title, 'Dentist');
        expect(
          store().tasksOn(monday.addDays(8)).where((t) => t.title == 'Dentist'),
          isEmpty,
        );
      },
    );
  });

  group('a repeating task (daily "Run" at 07:00)', () {
    test('"this" changes only this occurrence; undo restores it', () async {
      final undo = await backend().editTask(
        mondayRun(),
        AssistantTaskEdit(title: 'Long run', start: DateTime(2026, 10, 5, 8)),
      );
      expect(on(monday).title, 'Long run');
      expect(on(monday).scheduledAt, DateTime(2026, 10, 5, 8));
      expect(on(monday.addDays(1)).title, 'Run');

      await undo!();
      expect(on(monday).title, 'Run');
      expect(on(monday).scheduledAt, DateTime(2026, 10, 5, 7));
    });

    test(
      '"this and following" changes it and later ones; undo restores',
      () async {
        final undo = await backend().editTask(
          mondayRun(),
          AssistantTaskEdit(
            start: DateTime(2026, 10, 5, 6, 30),
            durationMinutes: 30,
            scope: AssistantEditScope.thisAndFollowing,
          ),
        );
        expect(on(monday.addDays(3)).scheduledAt, DateTime(2026, 10, 8, 6, 30));
        expect(on(monday.addDays(3)).durationMinutes, 30);

        await undo!();
        expect(on(monday.addDays(3)).scheduledAt, DateTime(2026, 10, 8, 7));
      },
    );

    test('new repeat days apply from this date on', () async {
      await backend().editTask(
        mondayRun(),
        const AssistantTaskEdit(
          repeatDays: {DateTime.monday, DateTime.wednesday},
        ),
      );
      expect(store().tasksOn(monday.addDays(1)), isEmpty, reason: 'Tuesday');
      expect(store().tasksOn(monday.addDays(2)), hasLength(1));
    });

    test('repeat off ends the series; undo brings it back', () async {
      final undo = await backend().editTask(
        mondayRun(),
        const AssistantTaskEdit(repeatDays: {}),
      );
      expect(store().tasksOn(monday.addDays(5)), isEmpty);

      await undo!();
      expect(store().tasksOn(monday.addDays(5)), hasLength(1));
    });

    test('done marks only this occurrence; undo clears it', () async {
      final undo = await backend().editTask(
        mondayRun(),
        const AssistantTaskEdit(done: true),
      );
      expect(on(monday).status, TaskStatus.completed);
      expect(on(monday.addDays(1)).status, TaskStatus.pending);

      await undo!();
      expect(on(monday).status, TaskStatus.pending);
    });

    test('the tools can find an occurrence by the id they hand out', () {
      expect(backend().taskById(occurrenceTaskId(_monday))!.title, 'Run');
      expect(backend().taskById('missing'), isNull);
    });
  });
}
