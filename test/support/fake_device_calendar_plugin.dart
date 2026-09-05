import 'dart:collection';

import 'package:device_calendar/device_calendar.dart' as dc;

/// A [dc.DeviceCalendarPlugin] that never touches a real platform channel —
/// `device_calendar` has no platform implementation registered under
/// `flutter_test`, so any real call would throw. Subclasses the plugin via
/// its `@visibleForTesting` `DeviceCalendarPlugin.private()` constructor
/// (the exact hook the plugin authors provided for this), same shape as
/// `FakeNotificationService` subclassing `NotificationService`.
///
/// In-memory only: [calendars] and [eventsByCalendarId] are plain fields a
/// test seeds directly; [createOrUpdateEvent]/[deleteEvent] mutate them so
/// a test can assert on the resulting state afterwards.
class FakeDeviceCalendarPlugin extends dc.DeviceCalendarPlugin {
  FakeDeviceCalendarPlugin() : super.private();

  bool permissionGranted = true;
  List<dc.Calendar> calendars = [];

  /// Keyed by calendar id, then by event id.
  Map<String, Map<String, dc.Event>> eventsByCalendarId = {};

  int _nextEventId = 1;

  @override
  Future<dc.Result<bool>> hasPermissions() async {
    return dc.Result<bool>()..data = permissionGranted;
  }

  @override
  Future<dc.Result<bool>> requestPermissions() async {
    return dc.Result<bool>()..data = permissionGranted;
  }

  @override
  Future<dc.Result<UnmodifiableListView<dc.Calendar>>>
  retrieveCalendars() async {
    return dc.Result<UnmodifiableListView<dc.Calendar>>()
      ..data = UnmodifiableListView(calendars);
  }

  @override
  Future<dc.Result<UnmodifiableListView<dc.Event>>> retrieveEvents(
    String? calendarId,
    dc.RetrieveEventsParams? retrieveEventsParams,
  ) async {
    final events = eventsByCalendarId[calendarId]?.values.toList() ?? [];
    return dc.Result<UnmodifiableListView<dc.Event>>()
      ..data = UnmodifiableListView(events);
  }

  @override
  Future<dc.Result<String>?> createOrUpdateEvent(dc.Event? event) async {
    if (event == null) return null;
    final calendarId = event.calendarId!;
    final eventId = event.eventId ?? 'fake-event-${_nextEventId++}';
    event.eventId = eventId;
    eventsByCalendarId.putIfAbsent(calendarId, () => {})[eventId] = event;
    return dc.Result<String>()..data = eventId;
  }

  @override
  Future<dc.Result<bool>> deleteEvent(
    String? calendarId,
    String? eventId,
  ) async {
    final removed = eventsByCalendarId[calendarId]?.remove(eventId) != null;
    return dc.Result<bool>()..data = removed;
  }
}
