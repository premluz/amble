import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/synced_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/repositories/hive_synced_calendar_event_repository.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/services/calendar_permission_service.dart';
import 'package:amble/shared/services/calendar_sync_service.dart';

import '../../support/fake_device_calendar_plugin.dart';

const _targetCalendarId = 'target-cal';

void main() {
  late Box<Task> taskBox;
  late Box<SyncedCalendarEvent> syncedBox;
  late HiveTaskRepository taskRepository;
  late HiveSyncedCalendarEventRepository syncedRepository;
  late FakeDeviceCalendarPlugin plugin;
  late CalendarSyncService service;

  setUpAll(() {
    // CalendarSyncService converts Task.scheduledAt to tz.TZDateTime via
    // tz.local — same setup NotificationService.initialize() does at real
    // app startup (main.dart), needed here since nothing else in this test
    // file goes through that path.
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
  });

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_calendar_sync');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    final suffix = DateTime.now().microsecondsSinceEpoch;
    taskBox = await Hive.openBox<Task>('test_tasks_$suffix');
    syncedBox = await Hive.openBox<SyncedCalendarEvent>('test_synced_$suffix');
    taskRepository = HiveTaskRepository(taskBox);
    syncedRepository = HiveSyncedCalendarEventRepository(syncedBox);
    plugin = FakeDeviceCalendarPlugin()
      ..calendars = [dc.Calendar(id: _targetCalendarId, name: 'Target')];
    service = CalendarSyncService(
      plugin,
      CalendarPermissionService(plugin),
      taskRepository,
      syncedRepository,
    );
  });

  tearDown(() async {
    await taskBox.deleteFromDisk();
    await syncedBox.deleteFromDisk();
  });

  Task scheduledTask({String title = 'Task'}) => Task.create(
    title: title,
    scheduledAt: DateTime(2026, 9, 3, 9),
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.personal,
  );

  test('creates a device event for a never-synced scheduled task', () async {
    final task = scheduledTask();
    await taskRepository.saveTask(task);

    final result = await service.sync(targetCalendarId: _targetCalendarId);

    expect(result.created, 1);
    expect(result.updated, 0);
    expect(result.removed, 0);

    final savedTask = taskRepository.getTaskById(task.id)!;
    expect(savedTask.externalEventId, isNotNull);
    expect(
      plugin
          .eventsByCalendarId[_targetCalendarId]![savedTask.externalEventId]
          ?.title,
      'Task',
    );
    expect(syncedRepository.getByTaskId(task.id), isNotNull);
  });

  test(
    'updates the existing device event for an already-synced task',
    () async {
      final task = scheduledTask();
      await taskRepository.saveTask(task);
      await service.sync(targetCalendarId: _targetCalendarId);
      final firstEventId = taskRepository.getTaskById(task.id)!.externalEventId;

      final resynced = taskRepository.getTaskById(task.id)!;
      resynced.title = 'Renamed';
      await taskRepository.saveTask(resynced);

      final result = await service.sync(targetCalendarId: _targetCalendarId);

      expect(result.created, 0);
      expect(result.updated, 1);
      final updatedTask = taskRepository.getTaskById(task.id)!;
      expect(
        updatedTask.externalEventId,
        firstEventId,
      ); // Same event, not a duplicate.
      expect(
        plugin.eventsByCalendarId[_targetCalendarId]![firstEventId]?.title,
        'Renamed',
      );
      expect(plugin.eventsByCalendarId[_targetCalendarId]!.length, 1);
    },
  );

  test('unscheduled (Inbox) tasks are never synced', () async {
    final inboxTask = Task.captured(title: 'Someday');
    await taskRepository.saveTask(inboxTask);

    final result = await service.sync(targetCalendarId: _targetCalendarId);

    expect(result.created, 0);
    expect(taskRepository.getTaskById(inboxTask.id)!.externalEventId, isNull);
    expect(plugin.eventsByCalendarId[_targetCalendarId], isNull);
  });

  test('removes the device event when its source task has been deleted since the last sync', () async {
    final task = scheduledTask();
    await taskRepository.saveTask(task);
    await service.sync(targetCalendarId: _targetCalendarId);
    final eventId = taskRepository.getTaskById(task.id)!.externalEventId!;
    expect(
      plugin.eventsByCalendarId[_targetCalendarId]!.containsKey(eventId),
      isTrue,
    );

    await taskRepository.deleteTask(task.id);

    final result = await service.sync(targetCalendarId: _targetCalendarId);

    expect(result.removed, 1);
    expect(
      plugin.eventsByCalendarId[_targetCalendarId]!.containsKey(eventId),
      isFalse,
    );
    expect(syncedRepository.getByTaskId(task.id), isNull);
  });

  test('a task synced then deleted before any second sync is still cleaned up on the first sync that notices', () async {
    final task = scheduledTask();
    await taskRepository.saveTask(task);
    await service.sync(targetCalendarId: _targetCalendarId);
    await taskRepository.deleteTask(task.id);

    // Second sync also creates/updates nothing else — the orphan cleanup
    // runs alongside a genuinely empty create/update pass.
    final result = await service.sync(targetCalendarId: _targetCalendarId);

    expect(result.created, 0);
    expect(result.updated, 0);
    expect(result.removed, 1);
  });

  test(
    'permission denial returns a zeroed result and touches nothing',
    () async {
      plugin.permissionGranted = false;
      final task = scheduledTask();
      await taskRepository.saveTask(task);

      final result = await service.sync(targetCalendarId: _targetCalendarId);

      expect(result.isEmpty, isTrue);
      expect(taskRepository.getTaskById(task.id)!.externalEventId, isNull);
    },
  );
}
