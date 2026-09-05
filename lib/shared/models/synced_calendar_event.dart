import 'package:hive_ce/hive_ce.dart';

part 'synced_calendar_event.g.dart';

/// Tracks one Amble [Task] pushed to a device calendar via manual
/// "Sync to Calendar" — Feature 2 of CONSTITUTION.md's "Calendar" section.
///
/// A separate, persistent entity — own model, own Hive box, own
/// repository, same "own box" shape as [Zone]/[TrackedBehavior] — rather
/// than folding this into [PreferencesRepository]'s generic key-value
/// store: `PreferencesRepository` holds a handful of scalar app settings,
/// not a growing collection of per-task rows with their own independent
/// lifecycle (one row per synced task, deleted when the sync-out logic
/// confirms the device event itself was removed). See docs/DECISIONS.md.
///
/// This row is the ONLY place [deviceEventId] survives once its source
/// [Task] is deleted — `Task.externalEventId` (the task's own copy of the
/// same id, used to decide create-vs-update on the next sync) is deleted
/// along with the task. `CalendarSyncService` reads this box to find
/// synced ids whose source task no longer exists, so it knows to remove
/// the orphaned device event too.
@HiveType(typeId: 10)
class SyncedCalendarEvent extends HiveObject {
  SyncedCalendarEvent({
    required this.taskId,
    required this.deviceEventId,
    required this.deviceCalendarId,
  });

  /// The Amble [Task.id] this device event was created for. Used as this
  /// object's own Hive key (see `HiveSyncedCalendarEventRepository`), so
  /// there is at most one [SyncedCalendarEvent] per task.
  @HiveField(0)
  final String taskId;

  /// The device calendar event's own id — [dc.Event.eventId] from
  /// `device_calendar`. What `CalendarSyncService` updates on a later sync,
  /// or deletes once the source [Task] is gone.
  @HiveField(1)
  final String deviceEventId;

  /// The device calendar this event lives on — `device_calendar`'s
  /// `deleteEvent`/`createOrUpdateEvent` both require the calendar id
  /// alongside the event id, so it has to be stored here too rather than
  /// re-derived (the user's chosen sync-target calendar in Settings can
  /// change after this row was written).
  @HiveField(2)
  final String deviceCalendarId;
}
