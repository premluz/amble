import 'package:device_calendar/device_calendar.dart' as dc;
import 'package:flutter/material.dart' show Color, TimeOfDay;
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
      // Compared as absolute INSTANTS, not as `DateTime` values: the
      // mapper deliberately returns a plain device-local `DateTime`
      // rebuilt from the epoch (see the mislabelled-zone test below for
      // why), so it is never `==` to the `TZDateTime` that went in even
      // though both name the same moment.
      expect(
        mapped.start.millisecondsSinceEpoch,
        _tz(DateTime(2026, 9, 3, 9)).millisecondsSinceEpoch,
      );
      expect(
        mapped.end.millisecondsSinceEpoch,
        _tz(DateTime(2026, 9, 3, 9, 30)).millisecondsSinceEpoch,
      );
      expect(mapped.sourceCalendarId, 'cal-1');
      expect(mapped.sourceCalendarName, 'Work');
      expect(mapped.sourceCalendarColor, const Color(0xFF00FF00));
    });

    // Regression coverage for a real bug, reported directly: "item in
    // local device calendar Google shows 10:30 - 11:00 standup / on
    // timeline it shows correctly 10:30-11 visually spatially but when
    // tapped details in sheet show 8:30 - 9:00 / should show same as
    // Google."
    //
    // The cause was a `.toLocal()` added at this mapping boundary.
    // `TZDateTime.toLocal()` resolves against the `timezone` package's
    // `tz.local`, which is `Etc/UTC` until `tz.setLocalLocation` runs, so
    // a Warsaw 10:30 became `08:30Z`. Every display site reads WALL-CLOCK
    // FIELDS (`TimeOfDay.fromDateTime`) and so rendered 08:30, while the
    // spatial rail — which does `difference()` arithmetic on absolute
    // instants — stayed correct at 10:30. Hence one event showing two
    // different times in the same app.
    //
    // Asserted on the wall-clock HOUR/MINUTE specifically: that is what
    // the user actually reads off the sheet, and it is the only assertion
    // that fails when a conversion silently shifts the fields. The
    // previous version of this test compared `.toLocal()` against
    // `.toLocal()` on both sides, which passes whether or not any
    // conversion happens — it could never have caught this.
    test('an event carrying the WRONG timezone still maps to the device\'s '
        'own wall clock — the instant is what matters, not the label', () {
      // Reproduces the real on-device failure exactly. The plugin returned
      // the right INSTANT with BST (UTC+1) stapled on, while the device
      // was on UTC+2:
      //   raw=2026-09-15 09:30:00.000+0100 zone=BST epochLocal=10:30
      // Every text label reads wall-clock FIELDS via TimeOfDay, so the
      // sheet showed 09:30 for an event Google showed at 10:30.
      //
      // Built the way device_calendar's own Event.fromJson builds it —
      // `TZDateTime.fromMillisecondsSinceEpoch(zone, ts)` with a zone that
      // is NOT the device's. A hand-made TZDateTime in the *correct* zone
      // (the previous version of this test) could never catch this.
      final london = tz.getLocation('Europe/London');
      final warsaw = tz.getLocation('Europe/Warsaw');
      final trueInstant = tz.TZDateTime(warsaw, 2026, 9, 15, 10, 30);
      final mislabelled = tz.TZDateTime.fromMillisecondsSinceEpoch(
        london,
        trueInstant.millisecondsSinceEpoch,
      );

      final event = dc.Event('cal-1', eventId: 'evt-1', title: 'Standup')
        ..start = mislabelled
        ..end = mislabelled.add(const Duration(minutes: 30));

      final mapped = mapDeviceEvent(event, _calendar());

      // The instant must survive untouched...
      expect(
        mapped!.start.millisecondsSinceEpoch,
        trueInstant.millisecondsSinceEpoch,
      );
      // ...and the wall clock must be the DEVICE's reading of it, which is
      // what every display site renders. Asserted against the host's own
      // DateTime rather than a literal hour, so this stays correct on any
      // machine (and on CI) instead of encoding one timezone's answer.
      final hostReading = DateTime.fromMillisecondsSinceEpoch(
        trueInstant.millisecondsSinceEpoch,
      );
      expect(
        TimeOfDay.fromDateTime(mapped.start),
        TimeOfDay.fromDateTime(hostReading),
        reason: 'the sheet formats via TimeOfDay.fromDateTime — this is '
            'the exact value the user sees when tapping the event',
      );
      expect(mapped.start.isUtc, isFalse);
      expect(
        mapped.end.millisecondsSinceEpoch,
        trueInstant.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
      );
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
