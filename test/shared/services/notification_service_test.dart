import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
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
      category: TaskCategory.personal,
    );
    await service.scheduleForTask(task);
  });
}
