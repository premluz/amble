import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/notification_service.dart';

part 'notification_providers.g.dart';

/// The plugin instance and [NotificationService] are both app-lifetime
/// singletons — [NotificationService.initialize] is called once from
/// `main.dart` before this provider is ever read, and permission state
/// (`_permissionRequested`) needs to persist for the whole session, not
/// per-screen. See [TaskList] in task_providers.dart for where scheduling
/// is actually triggered from.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
}
