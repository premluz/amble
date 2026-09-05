import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../models/synced_calendar_event.dart';
import 'synced_calendar_event_repository.dart';

class HiveSyncedCalendarEventRepository
    implements SyncedCalendarEventRepository {
  HiveSyncedCalendarEventRepository(this._box);

  final Box<SyncedCalendarEvent> _box;

  @override
  List<SyncedCalendarEvent> getAll() => _box.values.toList();

  @override
  SyncedCalendarEvent? getByTaskId(String taskId) => _box.get(taskId);

  @override
  Future<void> save(SyncedCalendarEvent event) => _box.put(event.taskId, event);

  @override
  Future<void> deleteByTaskId(String taskId) => _box.delete(taskId);
}
