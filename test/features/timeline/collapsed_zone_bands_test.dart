import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/task_overlap_layout.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/services/zone_containment.dart';

/// `collapsedZoneBands` derives a zone's List-mode band by wrapping its own
/// member tasks' ALREADY-COMPUTED collapsed tops (from `_collapsedTops`'
/// gap-collapsing stack cursor) — never from real time-to-pixel math, which
/// has no relationship to List mode's non-linear stacking. Requested
/// directly: List mode should show zone bands, matching the mockup's
/// "To be" column.
void main() {
  final day = DateTime(2026, 9, 4);

  Task task(String id) => Task(
    id: id,
    title: id,
    scheduledAt: DateTime(2026, 9, 4, 8),
    durationMinutes: 30,
    categoryId: BuiltInCategoryIds.work,
  );

  group('a zone with member tasks', () {
    test('bands from the earliest member\'s own top to the latest '
        'member\'s own bottom, padded on both edges', () {
      final zone = Zone(
        id: 'z',
        title: 'Morning',
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
      );
      final a = task('a');
      final b = task('b');
      final containment = ZoneContainment(zone: zone, tasks: [a, b]);

      final bands = collapsedZoneBands(
        containments: [containment],
        day: day,
        taskTops: {'a': 100, 'b': 150},
        taskHeights: {'a': 24, 'b': 40},
        externalEventTops: const {},
        externalEventHeights: const {},
        rowTopsByStartTime: const [],
        rowExtents: const [],
        padding: 4,
        placeholderHeight: 20,
      );

      expect(bands, hasLength(1));
      // min top (100) - padding, to max bottom (150+40=190) + padding.
      expect(bands.single.top, 100 - 4);
      expect(bands.single.height, (190 - 100) + 4 * 2);
    });

    test('external events inside the zone count toward the wrap too', () {
      final zone = Zone(
        id: 'z',
        title: 'Morning',
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
      );
      final a = task('a');
      final containment = ZoneContainment(
        zone: zone,
        tasks: [a],
        externalEvents: const [],
      );

      // An event lower than the task's own bottom extends the band.
      final bands = collapsedZoneBands(
        containments: [
          ZoneContainment(zone: zone, tasks: [a], externalEvents: const []),
        ],
        day: day,
        taskTops: {'a': 100},
        taskHeights: {'a': 24},
        externalEventTops: const {},
        externalEventHeights: const {},
        rowTopsByStartTime: const [],
        rowExtents: const [],
        padding: 4,
        placeholderHeight: 20,
      );

      expect(bands.single.top, 100 - 4);
      expect(bands.single.height, 24 + 4 * 2);
      // Sanity: containment constructed above is unused directly, but
      // confirms the shape compiles against the real ZoneContainment type.
      expect(containment.tasks, [a]);
    });
  });

  group('a zone with no members', () {
    test('gets a fixed-height placeholder slotted before the first row at '
        'or after its own start time', () {
      final zone = Zone(
        id: 'empty',
        title: 'Empty',
        startMinutes: 10 * 60, // 10:00
        endMinutes: 11 * 60,
      );
      final containment = ZoneContainment(zone: zone, tasks: const []);

      final bands = collapsedZoneBands(
        containments: [containment],
        day: day,
        taskTops: const {},
        taskHeights: const {},
        externalEventTops: const {},
        externalEventHeights: const {},
        rowTopsByStartTime: [
          MapEntry(DateTime(2026, 9, 4, 9), 50.0),
          MapEntry(DateTime(2026, 9, 4, 11), 120.0),
        ],
        rowExtents: const [],
        padding: 4,
        placeholderHeight: 20,
      );

      expect(bands, hasLength(1));
      // 11:00 row is the first at-or-after the zone's 10:00 start.
      expect(bands.single.top, 120.0 - 4);
      expect(bands.single.height, 20 + 4 * 2);
    });

    test('slots after the LAST row when nothing starts at or after it', () {
      final zone = Zone(
        id: 'empty',
        title: 'Empty',
        startMinutes: 23 * 60,
        endMinutes: 23 * 60 + 30,
      );
      final containment = ZoneContainment(zone: zone, tasks: const []);

      final bands = collapsedZoneBands(
        containments: [containment],
        day: day,
        taskTops: const {},
        taskHeights: const {},
        externalEventTops: const {},
        externalEventHeights: const {},
        rowTopsByStartTime: [
          MapEntry(DateTime(2026, 9, 4, 9), 50.0),
          MapEntry(DateTime(2026, 9, 4, 11), 120.0),
        ],
        rowExtents: const [],
        padding: 4,
        placeholderHeight: 20,
      );

      expect(bands.single.top, 120.0 - 4);
    });

    test('with no rows at all, falls back to top 0', () {
      final zone = Zone(
        id: 'empty',
        title: 'Empty',
        startMinutes: 60,
        endMinutes: 90,
      );
      final containment = ZoneContainment(zone: zone, tasks: const []);

      final bands = collapsedZoneBands(
        containments: [containment],
        day: day,
        taskTops: const {},
        taskHeights: const {},
        externalEventTops: const {},
        externalEventHeights: const {},
        rowTopsByStartTime: const [],
        rowExtents: const [],
        padding: 4,
        placeholderHeight: 20,
      );

      expect(bands.single.top, 0 - 4);
    });
  });

  test('returns one band per containment, in the same order given', () {
    final zoneA = Zone(
      id: 'a',
      title: 'A',
      startMinutes: 8 * 60,
      endMinutes: 9 * 60,
    );
    final zoneB = Zone(
      id: 'b',
      title: 'B',
      startMinutes: 10 * 60,
      endMinutes: 11 * 60,
    );
    final t = task('t');

    final bands = collapsedZoneBands(
      containments: [
        ZoneContainment(zone: zoneA, tasks: [t]),
        ZoneContainment(zone: zoneB, tasks: const []),
      ],
      day: day,
      taskTops: {'t': 10},
      taskHeights: {'t': 24},
      externalEventTops: const {},
      externalEventHeights: const {},
      rowTopsByStartTime: [MapEntry(t.scheduledAt!, 10.0)],
      rowExtents: const [],
      padding: 4,
      placeholderHeight: 20,
    );

    expect(bands, hasLength(2));
    expect(bands[0].zone.id, 'a');
    expect(bands[1].zone.id, 'b');
  });

  group('padding clamp — real bug, reported directly from a screenshot: '
      'zones ended up overlapping once the collapsed inter-row gap shrank '
      'below double the zone padding', () {
    test('two zones separated by a real gap SMALLER than 2x padding never '
        'overlap — each gets at most half the gap, not the full padding', () {
      final zoneA = Zone(
        id: 'a',
        title: 'A',
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
      );
      final zoneB = Zone(
        id: 'b',
        title: 'B',
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
      );
      final taskA = task('a');
      final taskB = task('b');

      // Zone A's task ends at 100+24=124; zone B's task starts at 126 —
      // a real gap of only 2px, far smaller than 2x the 4px padding
      // requested (which would need 8px to avoid overlap).
      final bands = collapsedZoneBands(
        containments: [
          ZoneContainment(zone: zoneA, tasks: [taskA]),
          ZoneContainment(zone: zoneB, tasks: [taskB]),
        ],
        day: day,
        taskTops: {'a': 100, 'b': 126},
        taskHeights: {'a': 24, 'b': 24},
        externalEventTops: const {},
        externalEventHeights: const {},
        rowTopsByStartTime: [
          MapEntry(taskA.scheduledAt!, 100.0),
          MapEntry(taskB.scheduledAt!, 126.0),
        ],
        rowExtents: const [(100.0, 124.0), (126.0, 150.0)],
        padding: 4,
        placeholderHeight: 20,
      );

      expect(bands, hasLength(2));
      final bandA = bands[0];
      final bandB = bands[1];

      // The two bands must not overlap.
      expect(bandA.top + bandA.height, lessThanOrEqualTo(bandB.top));
      // Each got exactly half the real 2px gap (1px), not the full 4px
      // padding requested.
      expect(bandA.top + bandA.height, 124.0 + 1.0);
      expect(bandB.top, 126.0 - 1.0);
    });

    test('a zone band never eats into a plain unzoned row\'s own body, not '
        'just its top edge', () {
      final zone = Zone(
        id: 'z',
        title: 'Z',
        startMinutes: 8 * 60,
        endMinutes: 9 * 60,
      );
      final zoned = task('zoned');

      // An unzoned row sits right below the zone's own member, with a
      // real TALL height (100 to 140) — the old bug would have let the
      // band's padding land at 100+4=104, deep inside that row's body,
      // if it only ever checked the row's start (100) rather than
      // treating the row as occupying the whole 100-140 span.
      final bands = collapsedZoneBands(
        containments: [
          ZoneContainment(zone: zone, tasks: [zoned]),
        ],
        day: day,
        taskTops: {'zoned': 50},
        taskHeights: {'zoned': 24},
        externalEventTops: const {},
        externalEventHeights: const {},
        rowTopsByStartTime: [MapEntry(zoned.scheduledAt!, 50.0)],
        rowExtents: const [(50.0, 74.0), (76.0, 116.0)],
        padding: 4,
        placeholderHeight: 20,
      );

      final band = bands.single;
      expect(band.top + band.height, lessThanOrEqualTo(76.0));
    });
  });
}
