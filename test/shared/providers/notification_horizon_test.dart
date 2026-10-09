import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/recurrence_frequency.dart';
import 'package:amble/shared/models/recurrence_rule.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/providers/notification_providers.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/hive_task_repository.dart';
import 'package:amble/shared/services/notification_service.dart';

import '../../support/recording_notification_service.dart';

/// Regression coverage for the Android 500-concurrent-alarm incident: a
/// materialized 8-week recurring series used to register an OS alarm per
/// instance, which blew the cap and made every subsequent save take 3-4
/// seconds throwing a PlatformException. See docs/ERROR_LOG.md.
void main() {
  late Box<Task> box;
  late ProviderContainer container;
  late RecordingNotificationService notifications;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_notification_horizon');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    box = await Hive.openBox<Task>(
      'test_horizon_${DateTime.now().microsecondsSinceEpoch}',
    );
    notifications = RecordingNotificationService();

    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(HiveTaskRepository(box)),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await box.deleteFromDisk();
  });

  test('creating a daily repeating task stores no task rows and schedules no '
      'task alarms — occurrence alerts are budgeted separately', () async {
    await container
        .read(taskListProvider.notifier)
        .createTask(
          title: 'Morning run',
          scheduledAt: DateTime.now().add(const Duration(hours: 1)),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.health,
          recurrenceRule: RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            interval: 1,
          ),
        );

    // A series, not materialized rows — so nothing here can approach the
    // OS alarm cap (see `occurrence_alert_planner.dart` for its budget).
    expect(container.read(taskListProvider), isEmpty);
    expect(notifications.syncedTaskIds, isEmpty);
  });

  test('refreshScheduledNotifications cancels everything first, then '
      'schedules only tasks inside the horizon', () async {
    final now = DateTime.now();
    final near = Task.create(
      title: 'Tomorrow',
      scheduledAt: now.add(const Duration(days: 1)),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
    );
    final far = Task.create(
      title: 'Seven weeks out',
      scheduledAt: now.add(const Duration(days: 49)),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
    );
    await box.put(near.id, near);
    await box.put(far.id, far);

    await container
        .read(taskListProvider.notifier)
        .refreshScheduledNotifications();

    // The blanket cancel is what reclaims alarm slots on an install that
    // already hit the cap under the old behavior.
    expect(notifications.cancelAllCount, 1);
    expect(notifications.scheduledTaskIds, [near.id]);
    expect(notifications.scheduledTaskIds, isNot(contains(far.id)));
  });

  test('refreshScheduledNotifications skips a completed task even when it '
      'falls inside the horizon', () async {
    final done = Task.create(
      title: 'Already finished',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
    )..status = TaskStatus.completed;
    await box.put(done.id, done);

    await container
        .read(taskListProvider.notifier)
        .refreshScheduledNotifications();

    expect(notifications.scheduledTaskIds, isEmpty);
  });

  test('an unscheduled Inbox task is never scheduled by a refresh', () async {
    final captured = Task.captured(title: 'Someday');
    await box.put(captured.id, captured);

    await container
        .read(taskListProvider.notifier)
        .refreshScheduledNotifications();

    expect(notifications.scheduledTaskIds, isEmpty);
  });

  test('the horizon is shorter than the 8-week materialization window — the '
      'invariant that keeps the alarm count bounded', () {
    expect(notificationHorizonDays, lessThan(56));
  });
}
