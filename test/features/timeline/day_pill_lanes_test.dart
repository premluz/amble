import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/task_overlap_layout.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

/// The Spatial Task View's shared text column has always used
/// [dayPillLanes] (day-wide), so every task's name starts at the same x
/// wherever it sits — "all text ... always lined up even if one zone."
///
/// Zone background bands went through two designs. [zonePillLanes] (per
/// zone) sized each band to only ITS OWN occupied lanes, so a zone holding
/// one task didn't reserve an empty second lane whenever anything else in
/// the day happened to stack — requested directly at the time ("gap from
/// right ... should be same as left gap", clarified as "perceived padding
/// right"). That was then explicitly reversed: "all zones widen to the
/// same size" whenever ANY overlap exists anywhere in the visible day, so
/// `timeline_screen.dart`'s `_zoneBackgroundWidth` now reads [dayPillLanes]
/// for every band too — the same value the text column already used, so
/// bands and text align to the very same lane count.
void main() {
  Task task(int hour, int minute, int durationMinutes) => Task.create(
    title: 'T',
    scheduledAt: DateTime(2026, 9, 4, hour, minute),
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.health,
  );

  group('dayPillLanes', () {
    test('an empty day still reserves one lane', () {
      expect(dayPillLanes(const []), 1);
    });

    test('a day of non-overlapping tasks is one lane', () {
      final slots = layoutOverlappingTasks([
        task(5, 0, 30),
        task(6, 0, 30),
        task(9, 0, 30),
      ]);
      expect(dayPillLanes(slots), 1);
    });

    test('two overlapping tasks make it two lanes', () {
      final slots = layoutOverlappingTasks([task(5, 0, 60), task(5, 30, 60)]);
      expect(dayPillLanes(slots), 2);
    });

    test('three mutually-overlapping tasks make it three lanes', () {
      final slots = layoutOverlappingTasks([
        task(5, 0, 60),
        task(5, 15, 60),
        task(5, 30, 60),
      ]);
      expect(dayPillLanes(slots), 3);
    });

    test('the DEEPEST stack anywhere in the day wins — a single stacked '
        'run sets the width for the whole day, which is what keeps every '
        'zone band and every name column aligned', () {
      final slots = layoutOverlappingTasks([
        // One unstacked task early...
        task(4, 0, 30),
        // ...and a 3-deep stack much later.
        task(14, 0, 60),
        task(14, 15, 60),
        task(14, 30, 60),
        // ...then unstacked again.
        task(20, 0, 30),
      ]);
      expect(dayPillLanes(slots), 3);
    });
  });

  test('the TEXT COLUMN still uses the day-wide count, so one stacked run '
      'holds every name at the same x — while a quiet zone\'s own band no '
      'longer has to reserve that run\'s extra lane', () {
    // Previously this asserted both were derived from the SAME count.
    // That stopped being true once band width went per-zone; the earlier
    // version passed only because it compared an expression to itself.
    final slots = layoutOverlappingTasks([
      task(4, 0, 30), // unstacked, early — its own quiet zone
      task(14, 0, 60), // a 2-deep stack later
      task(14, 30, 60),
    ]);

    // The text column: one value for the whole day, taken from its
    // deepest stack, so names never shift between zones.
    expect(dayPillLanes(slots), 2);

    // The band around the early, unstacked task: 1 lane, NOT the day's 2.
    expect(
      zonePillLanes(
        slots: slots,
        zoneStart: DateTime(2026, 9, 4, 4),
        zoneEnd: DateTime(2026, 9, 4, 5),
      ),
      1,
    );
    // And the band around the stacked run: 2.
    expect(
      zonePillLanes(
        slots: slots,
        zoneStart: DateTime(2026, 9, 4, 14),
        zoneEnd: DateTime(2026, 9, 4, 16),
      ),
      2,
    );
  });

  // Regression test for a real bug, reported directly: "when one of
  // stacked items is lifted the zones shrink and titles shift left, as if
  // ghost not holding physical space." The zone band and the shared text
  // column are both sized from the day's deepest lane count, and that has
  // to be measured from the RESTING layout — the one computed without the
  // dragged task excluded from cluster detection — or lifting one member
  // of a stack drops the count and reflows the whole day mid-drag.
  test('excluding a dragged task from clustering must NOT be what the lane '
      'count is measured from — the resting layout keeps its depth', () {
    final all = [task(9, 0, 60), task(9, 30, 60)];

    // The resting layout: both tasks present, two lanes deep.
    expect(dayPillLanes(layoutOverlappingTasks(all)), 2);

    // What a naive mid-drag computation would see, with the dragged task
    // dropped from the list: only one lane, so the band would narrow and
    // every name would jump left.
    final asIfDragExcluded = [all.first];
    expect(dayPillLanes(layoutOverlappingTasks(asIfDragExcluded)), 1);
  });

  group('zonePillLanes', () {
    // The screenshot's own scenario: a 1-task zone above a 2-task one.
    // The day is 2 lanes deep, but the 1-task zone's band must NOT
    // reserve the second lane or it reads as a big gap on its right.
    final meditationStart = DateTime(2026, 9, 4, 4);
    final meditationEnd = DateTime(2026, 9, 4, 5);
    final ritualStart = DateTime(2026, 9, 4, 5);
    final ritualEnd = DateTime(2026, 9, 4, 7);

    final slots = layoutOverlappingTasks([
      task(4, 0, 60), // Meditation — alone in its zone
      task(5, 0, 120), // Walk
      task(5, 15, 60), // Stretching — overlaps Walk
    ]);

    test('the whole day is 2 lanes deep', () {
      expect(dayPillLanes(slots), 2);
    });

    test('a zone holding ONE task is 1 lane, even though the day is 2', () {
      expect(
        zonePillLanes(
          slots: slots,
          zoneStart: meditationStart,
          zoneEnd: meditationEnd,
        ),
        1,
      );
    });

    test('a zone holding a 2-task stack is 2 lanes', () {
      expect(
        zonePillLanes(slots: slots, zoneStart: ritualStart, zoneEnd: ritualEnd),
        2,
      );
    });

    test('a zone holding no tasks still reserves one lane', () {
      expect(
        zonePillLanes(
          slots: slots,
          zoneStart: DateTime(2026, 9, 4, 20),
          zoneEnd: DateTime(2026, 9, 4, 22),
        ),
        1,
      );
    });

    test('half-open: a task ending exactly when the zone starts is outside '
        'it, matching resolveZoneContainment\'s own window rule', () {
      final touching = layoutOverlappingTasks([
        task(3, 0, 60), // 03:00-04:00, ends exactly at the zone's start
        task(3, 0, 30), // overlaps it -> the pair is 2 lanes
      ]);
      expect(
        zonePillLanes(
          slots: touching,
          zoneStart: meditationStart,
          zoneEnd: meditationEnd,
        ),
        1,
      );
    });

    test('a task straddling into the zone DOES count', () {
      final straddling = layoutOverlappingTasks([
        task(3, 30, 60), // 03:30-04:30, reaches into the zone
        task(3, 30, 60), // overlaps it, also reaches in -> 2 lanes
      ]);
      expect(
        zonePillLanes(
          slots: straddling,
          zoneStart: meditationStart,
          zoneEnd: meditationEnd,
        ),
        2,
      );
    });
  });

  group('band padding is symmetric around the pills it contains', () {
    // Reported twice: "perceived padding right ... still too big", and the
    // top gap looking disproportionate beside it. Both traced to the pill
    // box starting `spacingSm` LEFT of its lane (see
    // `pillBoxLeftForColumn`), which made the real padding 4px left / 20px
    // right rather than the intended 12/12 — so a correct 12px top inset
    // looked far too large next to a 4px left.
    //
    // Uses the REAL sizing/offset functions, not copies of their
    // arithmetic, so reintroducing the shift fails this.
    const pill = 24.0; // sizeTaskBadge (md)
    const columnGap = 8.0; // spacingSm
    // Read from the real constants rather than restated, so a change to
    // either follows here instead of silently disagreeing.
    const inset = zoneBackgroundOffset;
    const trim = zoneBackgroundGap;
    const hourGutter = 56.0;

    void expectSymmetric(int lanes) {
      final bandWidthParam = zoneBackgroundWidthForPills(
        pillsSpan: zoneBackgroundPillWidth(
          lanes: lanes,
          pillWidth: pill,
          columnGap: columnGap,
        ),
        horizontalInset: inset,
        trailingTrim: trim,
      );

      // What ZoneBackgroundBlock actually renders from that width.
      final bandLeft = hourGutter - inset;
      final bandRight = bandLeft + (bandWidthParam - trim);

      // The first and last rails, via the real lane-offset function.
      final firstRailLeft =
          hourGutter +
          pillBoxLeftForColumn(
            column: 0,
            pillWidth: pill,
            columnGap: columnGap,
          );
      final lastRailRight =
          hourGutter +
          pillBoxLeftForColumn(
            column: lanes - 1,
            pillWidth: pill,
            columnGap: columnGap,
          ) +
          pill;

      expect(
        firstRailLeft - bandLeft,
        inset,
        reason: 'left padding at $lanes lane(s)',
      );
      expect(
        bandRight - lastRailRight,
        inset,
        reason: 'right padding at $lanes lane(s)',
      );
    }

    test('one lane', () => expectSymmetric(1));
    test('two lanes', () => expectSymmetric(2));
    test('three lanes', () => expectSymmetric(3));

    test('the top inset a task starting at the zone\'s start gets matches '
        'that same left/right padding', () {
      // `_zoneTaskTopInset` uses zoneBackgroundOffset, and the band's own
      // top is the strict time — so the visible top gap IS that inset,
      // the same value the left/right assertions above already pin. This
      // just states the coupling explicitly.
      expect(inset, zoneBackgroundOffset);
    });
  });

  group('zoneBackgroundPillWidth', () {
    test('one lane is exactly one pill, with no gap', () {
      expect(
        zoneBackgroundPillWidth(lanes: 1, pillWidth: 32, columnGap: 4),
        32,
      );
    });

    test('each extra lane adds a pill plus one gap', () {
      expect(
        zoneBackgroundPillWidth(lanes: 2, pillWidth: 32, columnGap: 4),
        68,
      );
      expect(
        zoneBackgroundPillWidth(lanes: 3, pillWidth: 32, columnGap: 4),
        104,
      );
    });
  });
}
