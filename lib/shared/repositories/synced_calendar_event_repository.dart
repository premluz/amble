import '../models/synced_calendar_event.dart';

/// Persistence interface for [SyncedCalendarEvent], mirroring
/// [ZoneRepository]'s shape. UI and state never call Hive directly — see
/// CONSTITUTION.md's access-pattern rule.
abstract class SyncedCalendarEventRepository {
  List<SyncedCalendarEvent> getAll();

  /// Null if [taskId] has never been synced.
  SyncedCalendarEvent? getByTaskId(String taskId);

  /// Keyed by [SyncedCalendarEvent.taskId] — at most one row per task, so
  /// this both creates the first sync record and updates it on every
  /// later sync.
  Future<void> save(SyncedCalendarEvent event);

  Future<void> deleteByTaskId(String taskId);
}
