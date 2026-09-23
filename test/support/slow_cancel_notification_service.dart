import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/notification_service.dart';

/// A [NotificationService] whose `cancelForTask` never completes until the
/// test explicitly [releaseCancels] — standing in for the real
/// platform-channel round trip, which on a device costs real time per call.
///
/// Exists to pin the fix for "one disappears instant, then after a long
/// delay the others": [TaskList.deleteTasksInBatch] must not await these
/// cancels inside its delete loop, because that wait scales with the number
/// of selected rows. A test using this fake can assert the rows are already
/// gone from `taskListProvider` while every cancel is still outstanding —
/// something a blocking implementation could never satisfy.
class SlowCancelNotificationService extends NotificationService {
  SlowCancelNotificationService() : super(FlutterLocalNotificationsPlugin());

  final _pending = <Completer<void>>[];

  /// Every id `cancelForTask` was called with, in call order.
  final cancelledIds = <String>[];

  /// How many cancels have actually finished — stays 0 until
  /// [releaseCancels], which is what makes "the write didn't wait for
  /// these" assertable.
  int completedCancels = 0;

  @override
  Future<void> cancelForTask(String taskId) {
    cancelledIds.add(taskId);
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future.then((_) => completedCancels++);
  }

  /// Lets every outstanding cancel finish.
  void releaseCancels() {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete();
    }
    _pending.clear();
  }

  @override
  Future<void> syncForTask(Task task) async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> openNotificationSettings() async => true;
}
