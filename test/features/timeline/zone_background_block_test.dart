import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/task_overlap_layout.dart';
import 'package:amble/features/timeline/zone_background_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

void main() {
  _zoneNameLabelTests();
  const pixelsPerMinute = 1.5;
  final day = DateTime(2026, 9, 2);
  final rangeStart = DateTime(2026, 9, 2, 6); // 06:00
  final zone = Zone(
    id: 'z',
    title: 'Morning ritual',
    startMinutes: 7 * 60, // 07:00
    endMinutes: 8 * 60, // 08:00
  );

  Future<Positioned> pumpAndFindPositioned(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(
            children: [
              ZoneBackgroundBlock(
                theme: AmbleTheme.light,
                zone: zone,
                day: day,
                rangeStart: rangeStart,
                pixelsPerMinute: pixelsPerMinute,
                left: 56,
                width: 300,
              ),
            ],
          ),
        ),
      ),
    );
    return tester.widget<Positioned>(find.byType(Positioned));
  }

  testWidgets(
    'the top edge lands EXACTLY on the zone\'s own start time — the cusp is '
    'precise, with no vertical offset',
    (tester) async {
      // Real bug, reported directly: "zone is 4:00-5:00 but it looks like
      // it ends before 5:00 ... we need to make that cusp precise but
      // retain gap between zones." The block used to start 12px above its
      // own start time (and therefore end 16px short of its end), which
      // read as the whole band sitting off its real hours.
      final positioned = await pumpAndFindPositioned(tester);

      // Strict top: (07:00 - 06:00) * 1.5 = 90.0 — unadjusted.
      expect(positioned.top, 90.0);
      // Horizontal inset is unchanged: strict left 56, offset -12 -> 44.
      expect(positioned.left, 56 - zoneBackgroundOffset);
    },
  );

  testWidgets(
    'the whole inter-zone gap comes off the BOTTOM, so the block ends one '
    'gap short of its own end time and the next zone can still start '
    'exactly on the shared boundary',
    (tester) async {
      final positioned = await pumpAndFindPositioned(tester);

      // Strict height: (08:00 - 07:00) * 1.5 = 90.0. Shrinks by -4.0 -> 86.0.
      expect(positioned.height, 90.0 - zoneBackgroundGap);
      // Strict width: 300. Shrinks by -4.0 -> 296.0.
      expect(positioned.width, 300 - zoneBackgroundGap);
      // The bottom edge therefore sits exactly `gap` before the real end.
      expect(positioned.top! + positioned.height!, 180.0 - zoneBackgroundGap);
    },
  );

  testWidgets(
    'a zone whose end exactly matches the next zone\'s start renders with '
    'exactly zoneBackgroundGap of clearance — measured from the REAL '
    'rendered geometry of both blocks, not recomputed in the test',
    (tester) async {
      final earlier = Zone(
        id: 'a',
        title: 'A',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60, // ends 08:00
      );
      final later = Zone(
        id: 'b',
        title: 'B',
        startMinutes: 8 * 60, // starts exactly when `earlier` ends
        endMinutes: 9 * 60,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                // Emitted in this order, so the two Positioned widgets
                // below are `earlier` then `later`.
                for (final zone in [earlier, later])
                  ZoneBackgroundBlock(
                    theme: AmbleTheme.light,
                    zone: zone,
                    day: day,
                    rangeStart: rangeStart,
                    pixelsPerMinute: pixelsPerMinute,
                    left: 56,
                    width: 300,
                  ),
              ],
            ),
          ),
        ),
      );

      final blocks = tester.widgetList<Positioned>(find.byType(Positioned));
      expect(blocks, hasLength(2));
      final a = blocks.first;
      final b = blocks.last;

      expect(b.top! - (a.top! + a.height!), zoneBackgroundGap);
      // And the later zone's own top is still exactly its start time.
      expect(b.top, 180.0);
    },
  );

  testWidgets(
    'zoneBackgroundOffset is the requested minimal 4px — it is also the '
    'top inset a task starting at its zone\'s start gets, and on the Task '
    'view\'s 1.5px-per-minute scale a larger value reads as the task '
    'starting minutes late',
    (tester) async {
      expect(zoneBackgroundOffset, 4.0);
      // Under three minutes of apparent delay at the default scale; the
      // previous 12px read as roughly eight, which is what prompted the
      // change ("otherwise the perception will be that it's starting
      // later").
      expect(zoneBackgroundOffset / 1.5, lessThan(3.0));
    },
  );

  testWidgets('zoneBackgroundGap matches the requested 4px exactly', (
    tester,
  ) async {
    expect(zoneBackgroundGap, 4.0);
  });

  // Requested directly: "gap from right (zone to right task) should be
  // same as left gap (padding)" and "gap from top of zone if task starts
  // same hour as zone should be same as from left". The band's right
  // padding used to fall out of `_zoneBackgroundWidth`'s arithmetic as 8px
  // against a 12px left inset — lopsided by accident rather than by
  // choice. This pins all three paddings to the SAME value so they can't
  // drift apart again.
  testWidgets(
    'the band pads its pill column equally on the left, the right, and '
    'above a task that starts exactly at the zone\'s start',
    (tester) async {
      final theme = AmbleTheme.light;
      const pillLeft = 56.0;
      final pill = theme.sizeTaskBadge;

      // The REAL sizing function timeline_screen.dart calls, not a copy of
      // its arithmetic — an earlier version of this test recomputed the
      // formula inline and therefore passed even with the fix reverted.
      final widthParam = zoneBackgroundWidthForPills(
        pillsSpan: zoneBackgroundPillWidth(
          lanes: 1,
          pillWidth: pill,
          columnGap: theme.spacingSm,
        ),
        horizontalInset: zoneBackgroundOffset,
        trailingTrim: zoneBackgroundGap,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Stack(
              children: [
                ZoneBackgroundBlock(
                  theme: theme,
                  zone: zone,
                  day: day,
                  rangeStart: rangeStart,
                  pixelsPerMinute: pixelsPerMinute,
                  left: pillLeft,
                  width: widthParam,
                ),
              ],
            ),
          ),
        ),
      );

      final band = tester.widget<Positioned>(find.byType(Positioned));
      final strictTop = (7 * 60 - 6 * 60) * pixelsPerMinute;

      // Left: pill's own left edge, minus the band's.
      expect(pillLeft - band.left!, zoneBackgroundOffset);
      // Right: band's right edge, minus the last pill's.
      expect(
        (band.left! + band.width!) - (pillLeft + pill),
        zoneBackgroundOffset,
      );
      // Top: a task starting at the zone's start renders at
      // strictTop + `_zoneTaskTopInset` (zoneBackgroundOffset), and the
      // band's own top is the strict time — so the gap is that inset.
      expect(
        (strictTop + zoneBackgroundOffset) - band.top!,
        zoneBackgroundOffset,
      );
    },
  );

  testWidgets('renders IgnorePointer — purely decorative, never intercepts '
      'a tap', (tester) async {
    await pumpAndFindPositioned(tester);
    expect(
      find.descendant(
        of: find.byType(ZoneBackgroundBlock),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  // Real bug, reported directly from a screenshot: a task ending exactly
  // on its zone's end looked flush against the band's bottom, despite
  // `TaskCapsuleBlock.bottomTrim` genuinely being applied. Root cause: the
  // band's own rendered bottom edge already sits `zoneBackgroundGap` above
  // the zone's real end time (the inter-zone gap, taken entirely off each
  // block's bottom — see that constant's own doc comment), so trimming the
  // task by `zoneBackgroundOffset` alone landed its new bottom exactly on
  // that already-raised edge: both moved together and the visible gap
  // stayed zero. `timeline_screen.dart`'s `_zoneTaskBottomTrim` now trims
  // by `zoneBackgroundOffset + zoneBackgroundGap` to compensate — this
  // measures the REAL rendered rects of both a `ZoneBackgroundBlock` and a
  // `TaskCapsuleBlock` built with that combined trim, not a copy of either
  // widget's arithmetic, so reverting the fix back to the offset alone
  // fails this.
  testWidgets(
    'a task ending exactly on its zone\'s end gets the SAME visible bottom '
    'gap as a task starting at the zone\'s start gets on top',
    (tester) async {
      final theme = AmbleTheme.light;
      const pillLeft = 56.0;
      final pill = theme.sizeTaskBadge;

      final widthParam = zoneBackgroundWidthForPills(
        pillsSpan: zoneBackgroundPillWidth(
          lanes: 1,
          pillWidth: pill,
          columnGap: theme.spacingSm,
        ),
        horizontalInset: zoneBackgroundOffset,
        trailingTrim: zoneBackgroundGap,
      );

      // A task occupying the zone's exact window (07:00-08:00), so its own
      // end lands exactly on the zone's end — the one condition
      // `_zoneTaskBottomTrim` applies a non-zero trim for.
      final task = Task.create(
        title: 'Deep work',
        scheduledAt: DateTime(2026, 9, 2, 7),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.work,
      );
      final strictTop = (7 * 60 - 6 * 60) * pixelsPerMinute;
      // The combined trim `_zoneTaskBottomTrim` now applies for this case.
      final bottomTrim = zoneBackgroundOffset + zoneBackgroundGap;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Stack(
              children: [
                ZoneBackgroundBlock(
                  theme: theme,
                  zone: zone,
                  day: day,
                  rangeStart: rangeStart,
                  pixelsPerMinute: pixelsPerMinute,
                  left: pillLeft,
                  width: widthParam,
                ),
                Positioned(
                  top: strictTop,
                  left: pillLeft,
                  right: 0,
                  child: TaskCapsuleBlock(
                    task: task,
                    pixelsPerMinute: pixelsPerMinute,
                    bottomTrim: bottomTrim,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final band = tester.widget<Positioned>(find.byType(Positioned).first);
      final bandBottom = band.top! + band.height!;
      final rail = tester.getRect(find.byType(AnimatedContainer).first);

      // Same visible gap the top case gets (see the test above this one):
      // zoneBackgroundOffset, measured against the band's REAL rendered
      // bottom edge rather than the zone's nominal end time.
      expect(bandBottom - rail.bottom, zoneBackgroundOffset);
    },
  );

  // Regression test for "all zones widen to the same size" whenever any
  // overlap exists anywhere in the visible day — requested directly,
  // reversing the earlier per-zone-lanes design ([zonePillLanes], still
  // used by the group above this one in day_pill_lanes_test.dart, but no
  // longer by `timeline_screen.dart`'s own `_zoneBackgroundWidth`).
  //
  // Builds the SAME width every zone band on screen now gets, using the
  // real public helpers `_zoneBackgroundWidth` itself calls
  // (`layoutOverlappingTasks`, `dayPillLanes`, `zoneBackgroundPillWidth`,
  // `zoneBackgroundWidthForPills`) rather than a copy of that arithmetic,
  // then renders TWO real `ZoneBackgroundBlock`s — one holding a
  // 2-lane overlap, one holding a single, non-overlapping task — and
  // measures their actual rendered widths are identical.
  testWidgets(
    'a zone with only one task still renders at the SAME width as a zone '
    'elsewhere in the day holding a 2-lane overlap',
    (tester) async {
      final theme = AmbleTheme.light;
      final busyZone = Zone(
        id: 'busy',
        title: 'Busy',
        startMinutes: 7 * 60,
        endMinutes: 8 * 60,
      );
      final quietZone = Zone(
        id: 'quiet',
        title: 'Quiet',
        startMinutes: 9 * 60,
        endMinutes: 10 * 60,
      );
      final tasks = [
        Task.create(
          title: 'A',
          scheduledAt: DateTime(2026, 9, 2, 7),
          durationMinutes: 60,
          categoryId: BuiltInCategoryIds.work,
        ),
        Task.create(
          title: 'B',
          scheduledAt: DateTime(2026, 9, 2, 7, 30),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        ),
        Task.create(
          title: 'C',
          scheduledAt: DateTime(2026, 9, 2, 9),
          durationMinutes: 60,
          categoryId: BuiltInCategoryIds.work,
        ),
      ];

      final slots = layoutOverlappingTasks(tasks);
      final dayWideWidth = zoneBackgroundWidthForPills(
        pillsSpan: zoneBackgroundPillWidth(
          lanes: dayPillLanes(slots),
          pillWidth: theme.sizeTaskBadge,
          columnGap: theme.spacingSm,
        ),
        horizontalInset: zoneBackgroundOffset,
        trailingTrim: zoneBackgroundGap,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: Stack(
              children: [
                for (final z in [busyZone, quietZone])
                  ZoneBackgroundBlock(
                    theme: theme,
                    zone: z,
                    day: day,
                    rangeStart: rangeStart,
                    pixelsPerMinute: pixelsPerMinute,
                    left: 56,
                    width: dayWideWidth,
                  ),
              ],
            ),
          ),
        ),
      );

      final blocks = tester.widgetList<Positioned>(find.byType(Positioned));
      expect(blocks, hasLength(2));
      expect(blocks.first.width, blocks.last.width);

      // Proves the day-wide value is a real, distinguishing choice here —
      // not a width the old per-zone design would have produced too. The
      // quiet zone holds only task C, alone in its own time window, so
      // zonePillLanes (the superseded per-zone count) would give it just
      // 1 lane against the day's 2 — this is exactly the gap "all zones
      // widen to the same size" was requested to close.
      expect(dayPillLanes(slots), 2);
      expect(
        zonePillLanes(
          slots: slots,
          zoneStart: day.add(const Duration(hours: 9)),
          zoneEnd: day.add(const Duration(hours: 10)),
        ),
        1,
      );
    },
  );

  // List (collapsed) mode override — the same nullable-param contract
  // ExternalEventBlock's own collapsedTop/collapsedHeight already
  // established. Requested directly: List mode should show zone bands
  // too, but positioned from wrapping its member tasks' own collapsed
  // tops (see collapsedZoneBands in task_overlap_layout.dart), not from
  // this widget's real time-to-pixel math — which has nothing meaningful
  // to measure against in collapsed mode.
  group('collapsedTop / collapsedHeight override', () {
    testWidgets('ZoneBackgroundBlock renders at the override, ignoring its own '
        'real-time formula entirely', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Stack(
              children: [
                ZoneBackgroundBlock(
                  theme: AmbleTheme.light,
                  zone: zone,
                  day: day,
                  rangeStart: rangeStart,
                  pixelsPerMinute: pixelsPerMinute,
                  left: 56,
                  width: 300,
                  collapsedTop: 500,
                  collapsedHeight: 40,
                ),
              ],
            ),
          ),
        ),
      );

      final band = tester.widget<Positioned>(find.byType(Positioned));
      // The real-time formula would put this zone (07:00-08:00, against
      // a 06:00 rangeStart) at top 90 height 90 — nowhere near the
      // override values, so this can't pass by coincidence.
      expect(band.top, 500);
      expect(band.height, 40);
    });

    testWidgets(
      'ZoneNameLabel renders at the override too, spanning the SAME band '
      'its ZoneBackgroundBlock sibling does',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              extensions: [AmbleTheme.light],
            ),
            home: Scaffold(
              body: Stack(
                children: [
                  ZoneNameLabel(
                    theme: AmbleTheme.light,
                    zone: zone,
                    day: day,
                    rangeStart: rangeStart,
                    pixelsPerMinute: pixelsPerMinute,
                    width: AmbleTheme.light.spacingLg,
                    collapsedTop: 500,
                    collapsedHeight: 40,
                  ),
                ],
              ),
            ),
          ),
        );

        final label = tester.widget<Positioned>(find.byType(Positioned));
        expect(label.top, 500);
        expect(label.height, 40);
      },
    );

    testWidgets(
      'null (the default) falls back to the real-time formula unchanged — '
      'Task view\'s existing call sites need no changes',
      (tester) async {
        final band = await pumpAndFindPositioned(tester);
        // Same values the very first test in this file already pins for
        // the un-overridden case (07:00-08:00 against a 06:00 rangeStart).
        expect(band.top, 90.0);
      },
    );
  });
}

/// The rotated zone name down the day's right edge — requested directly
/// ("can't see vertical zone name on task view"). Styled to match the hour
/// labels on the opposite edge.
void _zoneNameLabelTests() {
  const pixelsPerMinute = 1.5;
  final day = DateTime(2026, 9, 2);
  final rangeStart = DateTime(2026, 9, 2, 6); // 06:00
  final zone = Zone(
    id: 'z',
    title: 'Morning ritual',
    startMinutes: 7 * 60, // 07:00
    endMinutes: 8 * 60, // 08:00
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(
            children: [
              ZoneNameLabel(
                theme: AmbleTheme.light,
                zone: zone,
                day: day,
                rangeStart: rangeStart,
                pixelsPerMinute: pixelsPerMinute,
                width: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders the zone title', (tester) async {
    await pump(tester);
    expect(find.text('Morning ritual'), findsOneWidget);
  });

  testWidgets('is rotated a quarter turn', (tester) async {
    await pump(tester);
    final rotated = tester.widget<RotatedBox>(find.byType(RotatedBox));
    expect(rotated.quarterTurns, 1);
  });

  testWidgets('spans the zone\'s own time range, pinned to the right edge', (
    tester,
  ) async {
    await pump(tester);
    final positioned = tester.widget<Positioned>(find.byType(Positioned));

    // (07:00 - 06:00) * 1.5 = 90.0.
    expect(positioned.top, 90.0);
    // (08:00 - 07:00) * 1.5 = 90.0.
    expect(positioned.height, 90.0);
    expect(positioned.right, 0.0);
    expect(positioned.left, isNull);
  });

  testWidgets('is decorative — never takes a tap', (tester) async {
    await pump(tester);
    expect(
      find.descendant(
        of: find.byType(ZoneNameLabel),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  // Requested directly: "Make zone names even subtler color (add new
  // subtler semantic token)." Was colorTextSecondary.
  testWidgets('renders in colorTextTertiary, not colorTextSecondary', (
    tester,
  ) async {
    await pump(tester);
    final text = tester.widget<Text>(find.text('Morning ritual'));
    expect(text.style?.color, AmbleTheme.light.colorTextTertiary);
    expect(text.style?.color, isNot(AmbleTheme.light.colorTextSecondary));
  });
}
