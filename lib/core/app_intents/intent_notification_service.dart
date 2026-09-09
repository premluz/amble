import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../shared/models/task.dart';
import '../../shared/models/zone.dart';
import '../../shared/services/notification_service.dart';

const appIntentsChannel = MethodChannel('com.amble/app_intents');

/// Mobile bootstrap adapter: foreground permission behavior stays unchanged.
/// An assistant background launch may only use permission already granted, never
/// try to present a permission sheet. No changes to NotificationService.
class IntentNotificationService extends NotificationService {
  IntentNotificationService() : super(FlutterLocalNotificationsPlugin());

  final _pending = <Future<void>>{};

  @override
  Future<bool> requestPermissionIfNeeded() async {
    final foreground = await appIntentsChannel.invokeMethod<bool>(
      'isForeground',
    );
    return foreground == true
        ? super.requestPermissionIfNeeded()
        : hasPermission();
  }

  // TaskList deliberately fires this side effect without awaiting it. Keep
  // the intent alive until it finishes rather than replying before its alert
  // reaches the OS. Track launch refresh too so cancelAll cannot race a save.
  @override
  Future<void> syncForTask(Task task) => _track(super.syncForTask(task));

  @override
  Future<void> refreshScheduled(List<Task> tasks) =>
      _track(super.refreshScheduled(tasks));

  @override
  Future<void> scheduleForZone(Zone zone) =>
      _track(super.scheduleForZone(zone));

  Future<void> _track(Future<void> work) {
    final settled = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending.add(settled);
    settled.then((_) => _pending.remove(settled));
    return work;
  }

  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }
}
