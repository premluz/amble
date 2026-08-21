import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/notification_service.dart';

/// A [NotificationService] whose sync/cancel calls always throw — used to
/// prove [TaskList]'s mutators still complete the task write (and refresh
/// state) even when notification scheduling fails, per the fix for
/// "Continue does nothing" (an unguarded `syncForTask` call could abort a
/// save entirely). See docs/ERROR_LOG.md.
class ThrowingNotificationService extends NotificationService {
  ThrowingNotificationService() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> syncForTask(Task task) async {
    throw StateError('simulated notification scheduling failure');
  }

  @override
  Future<void> cancelForTask(String taskId) async {
    throw StateError('simulated notification cancel failure');
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;
}
