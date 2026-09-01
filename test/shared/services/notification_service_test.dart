import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/services/notification_service.dart';

void main() {
  late NotificationService service;

  setUp(() {
    service = NotificationService(FlutterLocalNotificationsPlugin());
  });

  test('scheduleForTask no-ops for an unscheduled task without touching the '
      'platform channel', () async {
    final task = Task.captured(title: 'Unscheduled');
    // Would throw LateInitializationError (no platform channel registered
    // under flutter_test) if this reached the plugin — passing proves the
    // early-return guard fired first.
    await service.scheduleForTask(task);
  });

  test('scheduleForTask no-ops for a task whose scheduled time has already '
      'passed, without touching the platform channel', () async {
    final task = Task.create(
      title: 'In the past',
      scheduledAt: DateTime.now().subtract(const Duration(hours: 1)),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
    );
    await service.scheduleForTask(task);
  });

  test('scheduleForTask no-ops for a task with notifications turned off, '
      'without touching the platform channel', () async {
    final task = Task.create(
      title: 'Silent task',
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
      notificationsEnabled: false,
    );
    // Would throw LateInitializationError if this reached the plugin —
    // the opt-out guard has to fire BEFORE the scheduled-time check, or a
    // silenced-but-otherwise-schedulable task would still hit the channel.
    await service.scheduleForTask(task);
  });

  test('scheduleForTask no-ops for a task beyond the notification horizon, '
      'without touching the platform channel', () async {
    final task = Task.create(
      title: 'Far future',
      scheduledAt: DateTime.now().add(
        const Duration(days: notificationHorizonDays + 1),
      ),
      durationMinutes: 30,
      categoryId: BuiltInCategoryIds.personal,
    );
    // The guard that keeps a materialized 8-week recurring series from
    // registering ~56 alarms and blowing Android's 500-alarm cap. Passing
    // (rather than a LateInitializationError) proves it returned before
    // reaching zonedSchedule. See docs/ERROR_LOG.md.
    await service.scheduleForTask(task);
  });

  group('isWithinSchedulingHorizon', () {
    final now = DateTime(2026, 9, 2, 12);

    test('a task in the past is outside the horizon', () {
      expect(
        service.isWithinSchedulingHorizon(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a task later today is inside the horizon', () {
      expect(
        service.isWithinSchedulingHorizon(
          now.add(const Duration(hours: 3)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a task just inside the horizon boundary is included', () {
      expect(
        service.isWithinSchedulingHorizon(
          now.add(const Duration(days: notificationHorizonDays - 1)),
          now: now,
        ),
        isTrue,
      );
    });

    test('a task just beyond the horizon boundary is excluded', () {
      expect(
        service.isWithinSchedulingHorizon(
          now.add(const Duration(days: notificationHorizonDays + 1)),
          now: now,
        ),
        isFalse,
      );
    });

    test('a task 8 weeks out — the far edge of a materialized recurring '
        'series — is excluded', () {
      expect(
        service.isWithinSchedulingHorizon(
          now.add(const Duration(days: 56)),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
