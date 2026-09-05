import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:timezone/timezone.dart' as tz;

import '../models/synced_calendar_event.dart';
import '../models/task.dart';
import '../repositories/synced_calendar_event_repository.dart';
import '../repositories/task_repository.dart';
import 'calendar_permission_service.dart';

/// Summary of one "Sync to Calendar" run, for the Settings button's result
/// text (e.g. "12 synced, 2 updated, 1 removed") — see CONSTITUTION.md's
/// "Calendar" section, Feature 2.
class CalendarSyncResult {
  const CalendarSyncResult({
    this.created = 0,
    this.updated = 0,
    this.removed = 0,
  });

  /// New device events created for tasks synced for the first time.
  final int created;

  /// Existing device events updated in place (task already had an
  /// [Task.externalEventId]).
  final int updated;

  /// Device events removed because their source [Task] was deleted since
  /// the last sync.
  final int removed;

  bool get isEmpty => created == 0 && updated == 0 && removed == 0;
}

/// Manual, one-directional sync of Amble [Task]s OUT to a single
/// user-chosen device calendar — Feature 2 of CONSTITUTION.md's "Calendar"
/// section. Strictly the mirror image of [ExternalCalendarService]: this
/// service never reads or modifies an event it didn't create itself, and
/// never touches any calendar other than the one explicit `targetCalendarId`
/// passed to [sync].
///
/// No automatic/background sync (a real, deliberate non-goal) — [sync] is
/// only ever called from the Settings "Sync to Calendar" button. No
/// conflict resolution for calendar-side edits to a previously-synced
/// event — Amble always overwrites what's on the device on the next sync,
/// per the explicit non-goal.
class CalendarSyncService {
  CalendarSyncService(
    this._plugin,
    this._permissions,
    this._taskRepository,
    this._syncedEventRepository,
  );

  final dc.DeviceCalendarPlugin _plugin;
  final CalendarPermissionService _permissions;
  final TaskRepository _taskRepository;
  final SyncedCalendarEventRepository _syncedEventRepository;

  /// Pushes every scheduled task to [targetCalendarId]: creates a device
  /// event for a task with no [Task.externalEventId], updates the existing
  /// event for a task that already has one, and removes any previously-
  /// synced device event whose source task has since been deleted.
  /// Unscheduled (Inbox) tasks are never synced.
  ///
  /// Returns a zeroed [CalendarSyncResult] (never throws) if permission is
  /// denied — same "degrade, don't crash" contract as
  /// [ExternalCalendarService.fetchEvents], though a denial here is more
  /// visible to the user since it's the direct result of pressing "Sync to
  /// Calendar," not a background Timeline load.
  Future<CalendarSyncResult> sync({required String targetCalendarId}) async {
    if (!await _permissions.requestPermission()) {
      return const CalendarSyncResult();
    }

    var created = 0;
    var updated = 0;

    final tasks = _taskRepository.getTasks();
    final scheduledTasks = tasks.where((task) => task.isScheduled);

    for (final task in scheduledTasks) {
      // device_calendar 4.x's Event.start/end are TZDateTime, not plain
      // DateTime — same tz.TZDateTime.from(x, tz.local) conversion
      // NotificationService already uses for zonedSchedule, relying on the
      // same tz.setLocalLocation call NotificationService.initialize makes
      // at app startup (see main.dart).
      final start = tz.TZDateTime.from(task.scheduledAt!, tz.local);
      final end = tz.TZDateTime.from(
        task.scheduledAt!.add(Duration(minutes: task.durationMinutes!)),
        tz.local,
      );
      final event = dc.Event(
        targetCalendarId,
        eventId: task.externalEventId,
        title: task.title,
        description: task.notes,
        start: start,
        end: end,
      );
      final result = await _plugin.createOrUpdateEvent(event);
      final deviceEventId = result?.data;
      if (result == null || !result.isSuccess || deviceEventId == null) {
        continue; // Leave this task's own sync state untouched; try again next run.
      }

      final wasAlreadySynced = task.externalEventId != null;
      task.externalEventId = deviceEventId;
      await _taskRepository.saveTask(task);
      await _syncedEventRepository.save(
        SyncedCalendarEvent(
          taskId: task.id,
          deviceEventId: deviceEventId,
          deviceCalendarId: targetCalendarId,
        ),
      );
      if (wasAlreadySynced) {
        updated++;
      } else {
        created++;
      }
    }

    final removed = await _removeOrphanedEvents(tasks);
    return CalendarSyncResult(
      created: created,
      updated: updated,
      removed: removed,
    );
  }

  /// Removes the device event for every [SyncedCalendarEvent] whose source
  /// task no longer exists in [currentTasks] — the tracking row is what
  /// makes this possible once the [Task] (and its own copy of the id) is
  /// gone. See [SyncedCalendarEvent]'s own doc comment for why this can't
  /// be derived from `Task.externalEventId` alone.
  Future<int> _removeOrphanedEvents(List<Task> currentTasks) async {
    final currentTaskIds = currentTasks.map((task) => task.id).toSet();
    var removed = 0;

    for (final synced in _syncedEventRepository.getAll()) {
      if (currentTaskIds.contains(synced.taskId)) continue;

      final result = await _plugin.deleteEvent(
        synced.deviceCalendarId,
        synced.deviceEventId,
      );
      // Removed from tracking regardless of the device-side result's
      // success: a "not found" failure means the event is already gone
      // (nothing left to retry), and retrying a genuine platform error
      // indefinitely on every future sync isn't better than dropping the
      // stale tracking row once its source task is confirmed deleted.
      await _syncedEventRepository.deleteByTaskId(synced.taskId);
      if (result.isSuccess) removed++;
    }
    return removed;
  }
}
