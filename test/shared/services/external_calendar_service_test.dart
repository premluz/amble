import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:amble/shared/services/calendar_permission_service.dart';
import 'package:amble/shared/services/external_calendar_service.dart';

import '../../support/fake_device_calendar_plugin.dart';

dc.Calendar _calendar({
  String? id = 'cal-1',
  String? name = 'Work',
  int? color = 0xFF00FF00,
}) {
  return dc.Calendar(id: id, name: name, color: color);
}

// device_calendar 4.x's Event.start/end are TZDateTime, not plain
// DateTime — same conversion CalendarSyncService uses for real writes.
// UTC is a deterministic zone for test assertions, independent of the
// machine's own local timezone.
tz.TZDateTime _tz(DateTime dateTime) => tz.TZDateTime.from(dateTime, tz.UTC);

dc.Event _event({
  String? eventId = 'evt-1',
  String? title = 'Standup',
  tz.TZDateTime? start,
  tz.TZDateTime? end,
}) {
  final event = dc.Event('cal-1', eventId: eventId, title: title);
  event.start = start ?? _tz(DateTime(2026, 9, 3, 9));
  event.end = end ?? _tz(DateTime(2026, 9, 3, 9, 30));
  return event;
}

void main() {
  setUpAll(() => tz_data.initializeTimeZones());

  group('mapDeviceEvent', () {
    test('maps a well-formed device event and calendar', () {
      final mapped = mapDeviceEvent(_event(), _calendar());

      expect(mapped, isNotNull);
      expect(mapped!.id, 'evt-1');
      expect(mapped.title, 'Standup');
      expect(mapped.start, _tz(DateTime(2026, 9, 3, 9)));
      expect(mapped.end, _tz(DateTime(2026, 9, 3, 9, 30)));
      expect(mapped.sourceCalendarId, 'cal-1');
      expect(mapped.sourceCalendarName, 'Work');
      expect(mapped.sourceCalendarColor, const Color(0xFF00FF00));
    });

    test('returns null when the device event has no eventId', () {
      expect(mapDeviceEvent(_event(eventId: null), _calendar()), isNull);
    });

    test('returns null when the device event has no start', () {
      final event = dc.Event('cal-1', eventId: 'evt-1', title: 'X')
        ..end = _tz(DateTime(2026, 9, 3, 9, 30));
      expect(mapDeviceEvent(event, _calendar()), isNull);
    });

    test('returns null when the device event has no end', () {
      final event = dc.Event('cal-1', eventId: 'evt-1', title: 'X')
        ..start = _tz(DateTime(2026, 9, 3, 9));
      expect(mapDeviceEvent(event, _calendar()), isNull);
    });

    test('a missing title maps to an empty string, not null/a crash', () {
      final mapped = mapDeviceEvent(_event(title: null), _calendar());
      expect(mapped!.title, '');
    });

    test('a calendar with no color maps to a null sourceCalendarColor', () {
      final mapped = mapDeviceEvent(_event(), _calendar(color: null));
      expect(mapped!.sourceCalendarColor, isNull);
    });

    test('a calendar with no name maps to a null sourceCalendarName', () {
      final mapped = mapDeviceEvent(_event(), _calendar(name: null));
      expect(mapped!.sourceCalendarName, isNull);
    });

    test('a calendar with no id maps to an empty sourceCalendarId', () {
      final mapped = mapDeviceEvent(_event(), _calendar(id: null));
      expect(mapped!.sourceCalendarId, '');
    });
  });

  group('fetchEvents excludeDeviceEventIds', () {
    // Regression coverage for a real bug, reported directly: "when pushed
    // Amble task to local calendar we shouldn't show that task as 'pulled'
    // from local calendar, otherwise it's duplication" — a task synced to
    // a calendar the user also selected to DISPLAY rendered twice on the
    // Timeline before this filter existed. See
    // calendar_providers.dart's externalCalendarEventsForRange, which
    // supplies excludeDeviceEventIds from every known SyncedCalendarEvent.
    late FakeDeviceCalendarPlugin plugin;
    late ExternalCalendarService service;

    setUp(() {
      plugin = FakeDeviceCalendarPlugin()
        ..calendars = [_calendar(id: 'cal-1')]
        ..eventsByCalendarId = {
          'cal-1': {
            'evt-amble-synced': _event(eventId: 'evt-amble-synced'),
            'evt-genuinely-external': _event(eventId: 'evt-genuinely-external'),
          },
        };
      service = ExternalCalendarService(
        plugin,
        CalendarPermissionService(plugin),
      );
    });

    test(
      'an event whose id is in excludeDeviceEventIds is filtered out',
      () async {
        final events = await service.fetchEvents(
          calendarIds: ['cal-1'],
          rangeStart: DateTime(2026, 9, 3),
          rangeEnd: DateTime(2026, 9, 4),
          excludeDeviceEventIds: {'evt-amble-synced'},
        );

        expect(events.map((e) => e.id), ['evt-genuinely-external']);
      },
    );

    test(
      'an empty excludeDeviceEventIds (the default) returns every event',
      () async {
        final events = await service.fetchEvents(
          calendarIds: ['cal-1'],
          rangeStart: DateTime(2026, 9, 3),
          rangeEnd: DateTime(2026, 9, 4),
        );

        expect(events.map((e) => e.id).toSet(), {
          'evt-amble-synced',
          'evt-genuinely-external',
        });
      },
    );
  });
}
