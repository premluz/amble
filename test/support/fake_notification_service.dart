import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/notification_service.dart';

/// A [NotificationService] that never touches the real platform channel —
/// `flutter_local_notifications` has no platform implementation registered
/// under `flutter_test`, so any real call throws `LateInitializationError`.
/// [TaskList]'s write paths call `syncForTask`/`cancelForTask` on every
/// mutation; tests that aren't specifically about notification behavior
/// should override `notificationServiceProvider` with this instead.
class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> syncForTask(Task task) async {}

  @override
  Future<void> cancelForTask(String taskId) async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;
}
