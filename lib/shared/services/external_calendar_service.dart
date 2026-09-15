import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart' show Color;

import '../models/external_calendar_event.dart';
import 'calendar_permission_service.dart';

/// Fetches read-only [ExternalCalendarEvent]s from the device calendar for
/// display on the Timeline — Feature 1 of CONSTITUTION.md's "Calendar"
/// section. Strictly read-only: nothing in this service ever calls a
/// `device_calendar` write method (`createOrUpdateEvent`/`deleteEvent`).
///
/// A plain class taking [dc.DeviceCalendarPlugin] by constructor injection,
/// same shape as [NotificationService] wrapping
/// `FlutterLocalNotificationsPlugin` — tests override
/// [externalCalendarServiceProvider] with a subclass that overrides
/// [fetchEvents] directly, so the pure mapping logic ([mapDeviceEvent]) can
/// still be unit-tested independently, with no real device dependency.
class ExternalCalendarService {
  ExternalCalendarService(this._plugin, this._permissions);

  final dc.DeviceCalendarPlugin _plugin;
  final CalendarPermissionService _permissions;

  /// Fetches every event across [calendarIds] that overlaps
  /// [rangeStart]..[rangeEnd]. Never throws: permission denial, an empty
  /// [calendarIds], or any platform/plugin error all resolve to an empty
  /// list — per CONSTITUTION.md, a fetch failure here must never block or
  /// degrade the ordinary Amble Timeline.
  ///
  /// [excludeDeviceEventIds] filters out any device event Amble itself
  /// created via Feature 2's sync-out (see [SyncedCalendarEventRepository]).
  /// Without this, a task synced to a calendar the user also selected to
  /// DISPLAY (Feature 1) would render twice on the Timeline — once as the
  /// real, interactive Amble task, once again as a read-only "external"
  /// duplicate of the very event Amble just created. This is a pure
  /// read-side filter, not a write or a dependency on Feature 2's own
  /// write path — [ExternalCalendarService] still never calls
  /// `createOrUpdateEvent`/`deleteEvent` and stays otherwise unaware of how
  /// sync-out works, matching CONSTITUTION.md's "reading external events
  /// never writes anything back" separation.
  Future<List<ExternalCalendarEvent>> fetchEvents({
    required List<String> calendarIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    Set<String> excludeDeviceEventIds = const {},
  }) async {
    if (calendarIds.isEmpty) return const [];
    if (!await _permissions.requestPermission()) return const [];

    final calendarsResult = await _plugin.retrieveCalendars();
    if (!calendarsResult.isSuccess || calendarsResult.data == null) {
      return const [];
    }
    final calendarsById = {
      for (final calendar in calendarsResult.data!)
        if (calendar.id != null) calendar.id!: calendar,
    };

    final events = <ExternalCalendarEvent>[];
    for (final calendarId in calendarIds) {
      final calendar = calendarsById[calendarId];
      if (calendar == null) continue; // Selected calendar no longer exists.

      final result = await _plugin.retrieveEvents(
        calendarId,
        dc.RetrieveEventsParams(startDate: rangeStart, endDate: rangeEnd),
      );
      if (!result.isSuccess || result.data == null) continue;

      for (final event in result.data!) {
        if (excludeDeviceEventIds.contains(event.eventId)) continue;
        final mapped = mapDeviceEvent(event, calendar);
        if (mapped != null) events.add(mapped);
      }
    }
    return events;
  }
}

/// Pure mapping from the plugin's [dc.Event]/[dc.Calendar] shapes to
/// [ExternalCalendarEvent] — kept free of the plugin's I/O so it's
/// unit-testable with plain constructed objects, no real device or
/// platform channel required. Returns null for an event missing the fields
/// an [ExternalCalendarEvent] requires (id/title/start/end) rather than
/// throwing — a single malformed device event must not take down the
/// whole fetch.
ExternalCalendarEvent? mapDeviceEvent(dc.Event event, dc.Calendar calendar) {
  final id = event.eventId;
  final start = event.start;
  final end = event.end;
  if (id == null || start == null || end == null) return null;

  return ExternalCalendarEvent(
    id: id,
    title: event.title ?? '',
    // Rebuilt from the absolute INSTANT into a plain, device-local
    // `DateTime` — never passed through, and never via `.toLocal()`.
    //
    // Reported directly: a Google event at 10:30 rendered "09:30 - 10:00"
    // in the detail sheet while sitting correctly at 10:30 on the spatial
    // rail. On-device diagnostics showed exactly why:
    //
    //   raw=2026-09-15 09:30:00.000+0100  zone=BST  offset=1:00
    //   epochLocal=2026-09-15 10:30:00.000
    //   deviceOffset=2:00
    //
    // The INSTANT the plugin returns is always right (it comes from the
    // OS). Only the LOCATION it staples on is unreliable: `Event.fromJson`
    // does `timeZoneDatabase.locations[eventStartTimeZone] ?? tz.local` —
    // a raw map lookup, falling back to the `timezone` package's own
    // `tz.local`, which is `Etc/UTC` until `tz.setLocalLocation` runs and
    // is whatever `FlutterTimezone` last resolved after that. Above, it
    // attached BST (UTC+1) to a device genuinely on UTC+2.
    //
    // That matters because the two render paths read the value
    // differently: the rail does `difference()` arithmetic on absolute
    // instants (offset-correct whatever zone is attached), while every
    // text label goes through `TimeOfDay.fromDateTime`, which reads
    // wall-clock FIELDS. Hence one event showing two different times.
    //
    // `DateTime.fromMillisecondsSinceEpoch` resolves against the Dart
    // VM's own local zone — the one the OS sets — so it is immune to
    // whatever `tz.local` happens to hold. Verified across five
    // `tz.local` states and both plugin outcomes: the rebuilt wall clock
    // always equals the host's, and the instant is preserved exactly.
    start: DateTime.fromMillisecondsSinceEpoch(start.millisecondsSinceEpoch),
    end: DateTime.fromMillisecondsSinceEpoch(end.millisecondsSinceEpoch),
    sourceCalendarId: calendar.id ?? '',
    sourceCalendarName: calendar.name,
    sourceCalendarColor: _colorFromArgb(calendar.color),
  );
}

Color? _colorFromArgb(int? argb) => argb == null ? null : Color(argb);
