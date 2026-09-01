import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';
import '../models/task_status.dart';

const _androidChannelId = 'task_alerts';
const _androidChannelName = 'Task alerts';
const _androidChannelDescription =
    'Alerts you when a scheduled task is starting.';

/// How far ahead a task-start alert is actually registered with the OS.
///
/// Android caps an app at **500 concurrent alarms** and throws
/// `IllegalStateException: Maximum limit of concurrent alarms 500 reached`
/// past that — and, critically, keeps throwing for every subsequent
/// schedule attempt. Recurring series materialize an 8-week rolling window
/// (`recurrenceWindowWeeks`, see `recurrence_generator.dart`), so a handful
/// of daily series is enough to blow the cap: one daily series alone is ~56
/// alarms. See docs/ERROR_LOG.md for the incident this constant exists to
/// prevent.
///
/// 14 days is deliberately shorter than the 8-week materialization window:
/// tasks are *stored* 8 weeks out (so the Timeline can show them), but only
/// the near ones hold an OS alarm. [NotificationService.refreshScheduled]
/// tops the window up at launch, which is what keeps a task scheduled 3
/// weeks out from being silently forgotten.
const notificationHorizonDays = 14;

/// Wraps `flutter_local_notifications` for task-start alerts. All scheduling
/// decisions (whether a given task write should schedule/cancel/reschedule a
/// notification) live in [TaskList] — this service only knows how to
/// schedule-for-time and cancel-by-id, kept deliberately dumb so the
/// task-writing logic isn't scattered across UI code. See docs/DECISIONS.md.
///
/// Permission is not requested in [initialize] — [DarwinInitializationSettings]
/// below has all `request*Permission` flags off, so iOS shows no prompt at
/// launch. Both platforms' permission requests happen lazily, the first time
/// [scheduleForTask] actually needs to schedule something (see
/// [requestPermissionIfNeeded]), not at app start. If the user denies, this
/// service silently skips scheduling — the app must work fully without
/// notification permission.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  bool _permissionRequested = false;

  /// [onNotificationTap] fires with the tapped notification's payload (the
  /// task id — see [scheduleForTask]) when the user taps a notification
  /// while the app is running or backgrounded. Cold-start launches (app not
  /// running at all) don't go through this callback — see
  /// [handleColdStartLaunch].
  Future<void> initialize({
    required void Function(String taskId) onNotificationTap,
  }) async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    // Reuses the app's launcher icon rather than adding a dedicated
    // drawable resource — acceptable for MVP per the official guidance
    // being "prefer a drawable," not "mipmap is invalid." Revisit if a
    // dedicated notification icon is ever designed.
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        final taskId = response.payload;
        if (taskId != null) onNotificationTap(taskId);
      },
    );
  }

  /// Checks whether the app was cold-launched by tapping a notification
  /// (the app process wasn't running at all, so [initialize]'s
  /// `onDidReceiveNotificationResponse` never fires for that first launch)
  /// and forwards its payload the same way. Call once, after [initialize].
  Future<void> handleColdStartLaunch({
    required void Function(String taskId) onNotificationTap,
  }) async {
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final taskId = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true && taskId != null) {
      onNotificationTap(taskId);
    }
  }

  /// Requests notification permission on first use, once per app run.
  /// Returns whether permission is granted. Safe to call repeatedly —
  /// only the first call actually prompts.
  Future<bool> requestPermissionIfNeeded() async {
    if (_permissionRequested) return _hasPermission();
    _permissionRequested = true;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsGranted =
          await android?.requestNotificationsPermission() ?? false;
      // Exact-alarm permission is separate from the notification-post
      // permission on Android 12+ (API 31+) — without it, zonedSchedule
      // with exactAllowWhileIdle silently falls back to inexact timing.
      // Best-effort: request it too, but don't block scheduling on it.
      await android?.requestExactAlarmsPermission();
      return notificationsGranted;
    }

    return true;
  }

  Future<bool> _hasPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.checkPermissions();
      return status?.isEnabled ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final enabled = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    }
    return true;
  }

  /// Current notification-permission status, for display (e.g. in
  /// Settings) — does not request permission or count as the "first use"
  /// that [requestPermissionIfNeeded] tracks, just reads the OS's current
  /// answer.
  Future<bool> hasPermission() => _hasPermission();

  /// Opens the OS's notification-settings page for this app. The standard
  /// pattern for "permission was denied, let the user go grant it
  /// manually" — most platforms (iOS included) don't allow an app to
  /// re-trigger the in-app permission prompt once denied, so deep-linking
  /// to OS settings is the only way back in. Provided directly by
  /// `flutter_local_notifications` (`openAppNotificationSettings`) on both
  /// iOS and Android — no separate package needed. Returns whether the
  /// settings page could be opened.
  Future<bool> openNotificationSettings() async {
    final opened = await _plugin.openAppNotificationSettings();
    return opened ?? false;
  }

  /// Schedules a start-time alert for [task]. No-ops silently if [task]
  /// isn't scheduled, its scheduled time has already passed, it falls
  /// beyond [notificationHorizonDays], or notification permission is denied
  /// — the app must keep working without it either way.
  Future<void> scheduleForTask(Task task) async {
    if (!task.notificationsEnabled) return;
    final scheduledAt = task.scheduledAt;
    if (scheduledAt == null) return;
    if (!isWithinSchedulingHorizon(scheduledAt)) return;

    final granted = await requestPermissionIfNeeded();
    if (!granted) return;

    await _plugin.zonedSchedule(
      id: _notificationId(task.id),
      title: task.title,
      body: _formatTime(scheduledAt),
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: task.id,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Whether [scheduledAt] is near enough to hold an OS alarm right now:
  /// still in the future, and no further out than [notificationHorizonDays].
  ///
  /// Pure and separated from [scheduleForTask] so the horizon rule is
  /// testable without a platform channel, and so [refreshScheduled] can
  /// apply exactly the same rule when topping the window up.
  bool isWithinSchedulingHorizon(DateTime scheduledAt, {DateTime? now}) {
    final from = now ?? DateTime.now();
    if (!scheduledAt.isAfter(from)) return false;
    return scheduledAt.isBefore(
      from.add(const Duration(days: notificationHorizonDays)),
    );
  }

  Future<void> cancelForTask(String taskId) =>
      _plugin.cancel(id: _notificationId(taskId));

  /// Rebuilds the whole set of registered alarms from scratch: cancels
  /// every pending one, then schedules [tasks] (the caller passes only
  /// those inside the horizon). Called once at launch (see `main.dart`),
  /// which is what makes [notificationHorizonDays] safe — a task further
  /// out than the horizon picks up its alarm on a later launch rather than
  /// never getting one.
  ///
  /// The blanket [cancelAll] first is deliberate, and does two jobs. It
  /// drops alarms for tasks that have since moved out of the horizon (or
  /// been deleted while the app wasn't running), and — the reason it
  /// exists — it reclaims the slots of installs that already blew past
  /// Android's 500-alarm cap under the previous schedule-everything
  /// behavior. Without it those installs stay wedged: the cap is already
  /// hit at launch, so every new schedule keeps throwing. See
  /// docs/ERROR_LOG.md.
  ///
  /// Each task is then scheduled independently with failures contained per
  /// task — one task's scheduling failure must not stop the rest of the
  /// window from being registered.
  Future<void> refreshScheduled(List<Task> tasks) async {
    try {
      await cancelAll();
    } catch (error) {
      debugPrint('Notification cancelAll failed during refresh: $error');
    }

    for (final task in tasks) {
      try {
        await scheduleForTask(task);
      } catch (error) {
        debugPrint('Notification refresh failed for task ${task.id}: $error');
      }
    }
  }

  /// Cancels every pending notification this app has registered.
  Future<void> cancelAll() => _plugin.cancelAll();

  /// Cancels any existing alert for [task], then schedules a fresh one if
  /// still appropriate. Correct for every write path (create, update,
  /// reschedule, toggle-complete, move-to-timeline) — a stale alert never
  /// survives a save that no longer warrants one.
  Future<void> syncForTask(Task task) async {
    await cancelForTask(task.id);
    if (task.status == TaskStatus.completed) return;
    await scheduleForTask(task);
  }
}

/// Derives a stable, deterministic notification id from a task's UUID
/// string — flutter_local_notifications requires an `int` id, and this
/// guarantees the same task always maps to the same id (so re-scheduling
/// correctly cancels its own prior alert) without persisting a separate
/// counter.
int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
