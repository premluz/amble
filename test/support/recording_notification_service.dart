import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/notification_service.dart';

/// A [NotificationService] that records which task ids it was asked to
/// schedule/sync/cancel instead of touching the platform channel.
///
/// [FakeNotificationService] is a silent stub — enough for tests that just
/// need writes not to explode. This one exists for tests that assert on the
/// *scheduling behavior itself*: specifically that materializing a
/// recurring series does NOT register an alarm per instance, which is what
/// drove the app past Android's 500-alarm cap. See docs/ERROR_LOG.md.
class RecordingNotificationService extends NotificationService {
  RecordingNotificationService() : super(FlutterLocalNotificationsPlugin());

  final List<String> syncedTaskIds = [];
  final List<String> scheduledTaskIds = [];
  final List<String> cancelledTaskIds = [];
  int cancelAllCount = 0;

  @override
  Future<void> syncForTask(Task task) async {
    syncedTaskIds.add(task.id);
  }

  @override
  Future<void> scheduleForTask(Task task) async {
    scheduledTaskIds.add(task.id);
  }

  @override
  Future<void> cancelForTask(String taskId) async {
    cancelledTaskIds.add(taskId);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;
}
