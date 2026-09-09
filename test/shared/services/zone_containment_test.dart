import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_containment.dart';

Task _task({String? zoneId, DateTime? scheduledAt, String title = 'T'}) {
  final task = scheduledAt == null
      ? Task.captured(title: title)
      : Task.create(
          title: title,
          scheduledAt: scheduledAt,
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.general,
        );
  task.zoneId = zoneId;
  return task;
}

Zone _zone({
  required String id,
  required int startMinutes,
  required int endMinutes,
  DateTime? anchorDate,
}) => Zone(
  id: id,
  title: id,
  startMinutes: startMinutes,
  endMinutes: endMinutes,
  anchorDate: anchorDate,
);

ExternalCalendarEvent _event({
  required String id,
  required DateTime start,
  String title = 'External',
}) => ExternalCalendarEvent(
  id: id,
  title: title,
  start: start,
  end: start.add(const Duration(minutes: 30)),
  sourceCalendarId: 'cal-1',
);

void main() {
  final day = DateTime(2026, 9, 2); // a Wednesday

  group('resolveZoneContainment', () {
    test('an assigned task whose time AGREES with its zone places there — '
        'zoneId and scheduledAt pointing at the same zone', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final task = _task(
        zoneId: 'z1',
        scheduledAt: DateTime(2026, 9, 2, 7, 15),
      );

      final result = resolveZoneContainment(
        tasks: [task],
        zones: [zone],
        day: day,
      );

      expect(result.containments, hasLength(1));
      expect(result.containments.single.tasks, [task]);
      expect(result.unzonedTasks, isEmpty);
    });

    test('computed fallback places an unassigned task whose scheduledAt '
        'falls within a zone\'s window', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final task = _task(scheduledAt: DateTime(2026, 9, 2, 7, 30));

      final result = resolveZoneContainment(
        tasks: [task],
        zones: [zone],
        day: day,
      );

      expect(result.containments.single.tasks, [task]);
      expect(result.unzonedTasks, isEmpty);
      // Read-only: the fallback must never write zoneId onto the task.
      expect(task.zoneId, isNull);
    });

    test('neither an explicit match nor a fallback match renders the task '
        'as unzoned', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final outsideAnyZone = _task(scheduledAt: DateTime(2026, 9, 2, 14, 0));
      final noTimeAtAll = _task();

      final result = resolveZoneContainment(
        tasks: [outsideAnyZone, noTimeAtAll],
        zones: [zone],
        day: day,
      );

      expect(result.containments.single.tasks, isEmpty);
      expect(result.unzonedTasks, containsAll([outsideAnyZone, noTimeAtAll]));
    });

    // Reversed directly (2026-09-04) from "zoneId wins even when
    // scheduledAt falls outside that zone's range". Reported directly: a
    // task reading 05:15 in Task view still rendered inside the
    // 09:00-13:00 container in Zone view, because a `zoneId` set by an
    // earlier Zone-view drop is never cleared when the time later moves.
    // TIME now wins whenever it exists; the stale assignment simply stops
    // affecting placement (it is never written or cleared here).
    test('a scheduledAt outside the assigned zone\'s range wins over that '
        'zoneId — the task renders at its real time, not in its stale '
        'zone', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final mismatched = _task(
        zoneId: 'z1',
        scheduledAt: DateTime(2026, 9, 2, 14, 0), // well outside 07:00-08:00
      );

      final result = resolveZoneContainment(
        tasks: [mismatched],
        zones: [zone],
        day: day,
      );

      expect(result.containments.single.tasks, isEmpty);
      expect(result.unzonedTasks, [mismatched]);
      // Read-only: the stale assignment is left on the task untouched.
      expect(mismatched.zoneId, 'z1');
    });

    test('a scheduledAt inside a DIFFERENT zone than the one assigned puts '
        'the task in the zone its time falls in', () {
      final morning = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final afternoon = _zone(
        id: 'z2',
        startMinutes: 14 * 60,
        endMinutes: 15 * 60,
      );
      final mismatched = _task(
        zoneId: 'z1',
        scheduledAt: DateTime(2026, 9, 2, 14, 30),
      );

      final result = resolveZoneContainment(
        tasks: [mismatched],
        zones: [morning, afternoon],
        day: day,
      );

      final byId = {for (final c in result.containments) c.zone.id: c.tasks};
      expect(byId['z1'], isEmpty);
      expect(byId['z2'], [mismatched]);
      expect(result.unzonedTasks, isEmpty);
    });

    test('a zone-only task (no scheduledAt) still places by its zoneId — '
        'there is no time to resolve against', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final zoneOnly = _task(zoneId: 'z1');

      final result = resolveZoneContainment(
        tasks: [zoneOnly],
        zones: [zone],
        day: day,
      );

      expect(result.containments.single.tasks, [zoneOnly]);
      expect(result.unzonedTasks, isEmpty);
    });

    test('a zone ending exactly when a task is scheduled does not contain '
        'that task — half-open window, matching zonesOverlap semantics', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final atTheBoundary = _task(scheduledAt: DateTime(2026, 9, 2, 8, 0));

      final result = resolveZoneContainment(
        tasks: [atTheBoundary],
        zones: [zone],
        day: day,
      );

      expect(result.containments.single.tasks, isEmpty);
      expect(result.unzonedTasks, [atTheBoundary]);
    });

    test('a non-recurring zone applies on every day viewed', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final anotherDay = DateTime(2026, 9, 10);

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [zone],
        day: anotherDay,
      );

      expect(result.containments, hasLength(1));
    });

    test('a materialized recurring instance only applies on its own '
        'anchorDate', () {
      // day is a Wednesday (2026-09-02); the instance is anchored to the
      // Monday before it, so it must not apply on this Wednesday.
      final mondayInstance = _zone(
        id: 'z1',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        anchorDate: DateTime(2026, 8, 31), // a Monday
      );

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [mondayInstance],
        day: day,
      );

      expect(result.containments, isEmpty);
    });

    test('a materialized recurring instance applies on its own '
        'anchorDate', () {
      final wednesdayInstance = _zone(
        id: 'z1',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
        anchorDate: day,
      );

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [wednesdayInstance],
        day: day,
      );

      expect(result.containments, hasLength(1));
    });

    test('containments are chronological by the zone\'s own startMinutes', () {
      final later = _zone(
        id: 'later',
        startMinutes: 12 * 60,
        endMinutes: 13 * 60,
      );
      final earlier = _zone(
        id: 'earlier',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [later, earlier],
        day: day,
      );

      expect(result.containments.map((c) => c.zone.id), ['earlier', 'later']);
    });
  });

  group('resolveZoneContainment — external calendar events', () {
    // Regression coverage for a real bug, reported directly: "on zone mode
    // tasks imported should be inside zones like other task[s]" — external
    // events had no containment resolution at all before this, and always
    // rendered on the outer axis regardless of zone overlap.
    test('an external event whose start falls inside a zone\'s window is '
        'matched into that zone\'s containment', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final event = _event(id: 'e1', start: DateTime(2026, 9, 2, 7, 15));

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [zone],
        day: day,
        externalEvents: [event],
      );

      expect(result.containments.single.externalEvents, [event]);
    });

    test('an external event whose start falls in NO zone is not matched '
        'into any containment', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      final event = _event(id: 'e1', start: DateTime(2026, 9, 2, 20));

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [zone],
        day: day,
        externalEvents: [event],
      );

      expect(result.containments.single.externalEvents, isEmpty);
    });

    test('an event ending exactly when a zone starts does not match — '
        'half-open window, same as a task', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);
      // Starts before the zone; only start time is checked (matching
      // _zoneContaining's own task rule), so this event's start (6:45)
      // simply falls outside the window.
      final event = _event(id: 'e1', start: DateTime(2026, 9, 2, 6, 45));

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [zone],
        day: day,
        externalEvents: [event],
      );

      expect(result.containments.single.externalEvents, isEmpty);
    });

    test('matched external events are chronological by start within their '
        'zone\'s containment', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 12 * 60);
      final later = _event(id: 'later', start: DateTime(2026, 9, 2, 10));
      final earlier = _event(id: 'earlier', start: DateTime(2026, 9, 2, 8));

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [zone],
        day: day,
        externalEvents: [later, earlier],
      );

      expect(result.containments.single.externalEvents.map((e) => e.id), [
        'earlier',
        'later',
      ]);
    });

    test('external events default to empty when the parameter is omitted '
        '— existing Task-only callers are unaffected', () {
      final zone = _zone(id: 'z1', startMinutes: 7 * 60, endMinutes: 8 * 60);

      final result = resolveZoneContainment(
        tasks: const [],
        zones: [zone],
        day: day,
      );

      expect(result.containments.single.externalEvents, isEmpty);
    });
  });
}
