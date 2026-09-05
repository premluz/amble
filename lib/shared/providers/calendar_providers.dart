import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/external_calendar_event.dart';
import '../models/synced_calendar_event.dart';
import '../repositories/hive_synced_calendar_event_repository.dart';
import '../repositories/synced_calendar_event_repository.dart';
import '../services/calendar_permission_service.dart';
import '../services/calendar_sync_service.dart';
import '../services/external_calendar_service.dart';
import 'preferences_providers.dart';
import 'task_providers.dart';

part 'calendar_providers.g.dart';

const syncedCalendarEventBoxName = 'syncedCalendarEvents';

/// App-lifetime singleton, same reasoning as `notificationServiceProvider`
/// — one plugin instance, one permission-request lifecycle for the whole
/// session.
@Riverpod(keepAlive: true)
dc.DeviceCalendarPlugin deviceCalendarPlugin(Ref ref) {
  return dc.DeviceCalendarPlugin();
}

@Riverpod(keepAlive: true)
CalendarPermissionService calendarPermissionService(Ref ref) {
  return CalendarPermissionService(ref.watch(deviceCalendarPluginProvider));
}

@Riverpod(keepAlive: true)
SyncedCalendarEventRepository syncedCalendarEventRepository(Ref ref) {
  final box = Hive.box<SyncedCalendarEvent>(syncedCalendarEventBoxName);
  return HiveSyncedCalendarEventRepository(box);
}

@Riverpod(keepAlive: true)
ExternalCalendarService externalCalendarService(Ref ref) {
  return ExternalCalendarService(
    ref.watch(deviceCalendarPluginProvider),
    ref.watch(calendarPermissionServiceProvider),
  );
}

@Riverpod(keepAlive: true)
CalendarSyncService calendarSyncService(Ref ref) {
  return CalendarSyncService(
    ref.watch(deviceCalendarPluginProvider),
    ref.watch(calendarPermissionServiceProvider),
    ref.watch(taskRepositoryProvider),
    ref.watch(syncedCalendarEventRepositoryProvider),
  );
}

/// Every calendar on the device, for the two Settings pickers (display
/// multi-select, sync-target single-select) — a plain `autoDispose` future
/// provider, not `keepAlive`: this is Settings-screen-scoped lookup data,
/// re-fetched fresh each time Settings is opened, unlike the session-long
/// state the other providers in this file hold.
@riverpod
Future<List<dc.Calendar>> availableDeviceCalendars(Ref ref) async {
  final permissions = ref.watch(calendarPermissionServiceProvider);
  if (!await permissions.requestPermission()) return const [];

  final plugin = ref.watch(deviceCalendarPluginProvider);
  final result = await plugin.retrieveCalendars();
  if (!result.isSuccess || result.data == null) return const [];
  return result.data!.toList();
}

/// Fetches [ExternalCalendarEvent]s for the given day range from whichever
/// calendars [CalendarDisplayIdsSetting] selects — the Timeline's own
/// read path for Feature 1. `autoDispose`, family-keyed by the exact range
/// requested: this is a per-load fetch, not session state to keep alive,
/// and the Timeline re-requests it on every day-range change/refresh.
///
/// Excludes any device event Amble itself pushed via Feature 2's manual
/// sync-out — otherwise a task synced to a calendar the user also chose to
/// DISPLAY would render twice (the real Amble task capsule, plus a
/// read-only "external" duplicate of the very event Amble just created).
/// Reported directly: "when pushed Amble task to local calendar we
/// shouldn't show that task as 'pulled' from local calendar, otherwise
/// it's duplication." See [ExternalCalendarService.fetchEvents]'s own doc
/// comment for why this stays a pure read-side filter rather than any
/// coupling between the two services.
@riverpod
Future<List<ExternalCalendarEvent>> externalCalendarEventsForRange(
  Ref ref,
  DateTime rangeStart,
  DateTime rangeEnd,
) async {
  final calendarIds = ref.watch(calendarDisplayIdsSettingProvider);
  final service = ref.watch(externalCalendarServiceProvider);
  final syncedEventIds = ref
      .watch(syncedCalendarEventRepositoryProvider)
      .getAll()
      .map((synced) => synced.deviceEventId)
      .toSet();
  return service.fetchEvents(
    calendarIds: calendarIds,
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    excludeDeviceEventIds: syncedEventIds,
  );
}
