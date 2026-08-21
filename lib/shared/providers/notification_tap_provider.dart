import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_tap_provider.g.dart';

/// The task id from a notification tap (foreground response or cold-start
/// launch — both funnel through [NotificationService]/`main.dart` into this
/// provider), waiting to be consumed by the UI. `AmbleHome` watches this,
/// switches to the Timeline tab, jumps to the task's day, and clears it via
/// [NotificationTap.consume] so the same tap doesn't re-trigger navigation
/// on a later rebuild.
@Riverpod(keepAlive: true)
class NotificationTap extends _$NotificationTap {
  @override
  String? build() => null;

  void set(String taskId) => state = taskId;

  void consume() => state = null;
}
