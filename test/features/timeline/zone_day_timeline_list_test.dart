import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';
import 'package:amble/features/timeline/external_event_capsule_block.dart'
    show DashedPillRail;
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/zone_container_block.dart';
import 'package:amble/features/timeline/zone_day_timeline.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

/// Zone view, made non-spatial — requested directly: "current zone view
/// make non spatial.. just list of zones one by one with 4px gap." No more
/// time axis, no `pixelsPerMinute`/`rangeStart`, no drag-to-move/resize or
/// drag-and-drop reassignment (all covered, pre-rewrite, by
/// `zone_day_timeline_position_test.dart`/`zone_day_timeline_move_resize_
/// test.dart`/`zone_move_end_to_end_test.dart` — all three deleted since
/// they tested behavior that no longer exists). This file covers the
/// replacement: a plain vertical list.
void main() {
  final day = DateTime(2026, 9, 2);

  Future<void> pump(
    WidgetTester tester, {
    List<Task> tasks = const [],
    List<Zone> zones = const [],
    List<ExternalCalendarEvent> externalEvents = const [],
    ValueChanged<Zone>? onZoneHeaderTap,
    bool devDurationVisible = true,
    bool devTimeRangeVisible = true,
    bool devZoneCardFlat = false,
    bool devHideEmptyZones = false,
    bool devIconsVisible = true,
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: ZoneDayTimeline(
            tasks: tasks,
            zones: zones,
            externalEvents: externalEvents,
            theme: AmbleTheme.light,
            categoryById: const <String, Category>{},
            selectedDate: day,
            onTaskTap: (_) {},
            onToggleComplete: (_) {},
            onZoneHeaderTap: onZoneHeaderTap,
            devDurationVisible: devDurationVisible,
            devTimeRangeVisible: devTimeRangeVisible,
            devZoneCardFlat: devZoneCardFlat,
            devHideEmptyZones: devHideEmptyZones,
            devIconsVisible: devIconsVisible,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Zone zoneAt(String id, String title, int startHour, int endHour) => Zone(
    id: id,
    title: title,
    startMinutes: startHour * 60,
    endMinutes: endHour * 60,
  );

  testWidgets('renders one ZoneContainerBlock per zone, no time-axis '
      'geometry (Positioned/Stack) required of the caller', (tester) async {
    await pump(
      tester,
      zones: [
        zoneAt('z1', 'Morning ritual', 7, 8),
        zoneAt('z2', 'Deep work', 9, 11),
      ],
    );

    expect(find.byType(ZoneContainerBlock), findsNWidgets(2));
    expect(find.textContaining('Morning ritual'), findsOneWidget);
    expect(find.textContaining('Deep work'), findsOneWidget);
  });

  // Reported directly, off the same reference screenshot the shared
  // `AppCalendarHeader` came from: "hard edge here... should be gradient
  // that fades under it." `_DayTimeline` (Task view) already had its own
  // top fade; this view had none at all until this fix.
  testWidgets('fades its own top row out under a fixed heading, matching '
      'the Task view\'s identical fade', (tester) async {
    await pump(tester, zones: [zoneAt('z1', 'Morning ritual', 7, 8)]);

    expect(find.byType(AppTopScrollFade), findsOneWidget);
    final fade = tester.widget<AppTopScrollFade>(find.byType(AppTopScrollFade));
    expect(fade.color, AmbleTheme.light.colorSurfaceTimeline);
    expect(fade.fromBottom, isFalse);
  });

  testWidgets(
    'consecutive rows are separated by exactly theme.spacingXs (4px)',
    (tester) async {
      await pump(
        tester,
        zones: [
          zoneAt('z1', 'Morning ritual', 7, 8),
          zoneAt('z2', 'Deep work', 9, 11),
        ],
      );

      final tops = tester
          .widgetList<ZoneContainerBlock>(find.byType(ZoneContainerBlock))
          .map((w) => w.zone.id)
          .toList();
      expect(tops, ['z1', 'z2']); // chronological by startMinutes

      final firstBottom = tester
          .getBottomLeft(find.byType(ZoneContainerBlock).first)
          .dy;
      final secondTop = tester
          .getTopLeft(find.byType(ZoneContainerBlock).last)
          .dy;

      expect(
        secondTop - firstBottom,
        closeTo(AmbleTheme.light.spacingXs, 0.5),
        reason: 'requested directly: "4px gap" between consecutive rows',
      );
    },
  );

  // Requested directly: "add gap between zones zone view (flat style)" —
  // with the zone's own card background/border gone in flat style, the
  // original 4px separator reads as too tight with nothing left to
  // visually separate one zone from the next.
  testWidgets(
    'in flat style, consecutive rows get a LARGER gap (theme.spacingMd), '
    'not the normal-style 4px',
    (tester) async {
      await pump(
        tester,
        zones: [
          zoneAt('z1', 'Morning ritual', 7, 8),
          zoneAt('z2', 'Deep work', 9, 11),
        ],
        devZoneCardFlat: true,
      );

      final firstBottom = tester
          .getBottomLeft(find.byType(ZoneContainerBlock).first)
          .dy;
      final secondTop = tester
          .getTopLeft(find.byType(ZoneContainerBlock).last)
          .dy;

      expect(secondTop - firstBottom, closeTo(AmbleTheme.light.spacingMd, 0.5));
    },
  );

  testWidgets('a zone\'s own tasks render inside its ZoneContainerBlock', (
    tester,
  ) async {
    final zone = zoneAt('z1', 'Morning ritual', 7, 8);
    // No explicit zoneId set — containment resolves by TIME first (per
    // resolveZoneContainment's own contract), and this task's scheduledAt
    // already falls inside the zone's window.
    final task = Task.create(
      title: 'Stretch',
      scheduledAt: DateTime(2026, 9, 2, 7, 15),
      durationMinutes: 15,
      categoryId: BuiltInCategoryIds.health,
    );

    await pump(tester, zones: [zone], tasks: [task]);

    final container =
        find.byType(ZoneContainerBlock).evaluate().single.widget
            as ZoneContainerBlock;
    expect(container.tasks.map((t) => t.id), contains(task.id));
    expect(find.textContaining('Stretch'), findsOneWidget);
  });

  testWidgets(
    'an unzoned task renders as its own flat row, not inside any zone',
    (tester) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
      final unzoned = Task.create(
        title: 'Water the plants',
        scheduledAt: DateTime(2026, 9, 2, 13),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.general,
      );

      await pump(tester, zones: [zone], tasks: [unzoned]);

      expect(find.byType(TaskCapsuleBlock), findsOneWidget);
      expect(find.textContaining('Water the plants'), findsOneWidget);
      final container =
          find.byType(ZoneContainerBlock).evaluate().single.widget
              as ZoneContainerBlock;
      expect(container.tasks, isEmpty);
    },
  );

  testWidgets(
    'zones and unzoned tasks interleave chronologically, not zones-first',
    (tester) async {
      final earlyZone = zoneAt('z1', 'Early zone', 6, 7);
      final unzonedBetween = Task.create(
        title: 'Between zones',
        scheduledAt: DateTime(2026, 9, 2, 8),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.general,
      );
      final lateZone = zoneAt('z2', 'Late zone', 9, 10);

      await pump(tester, zones: [earlyZone, lateZone], tasks: [unzonedBetween]);

      final earlyZoneY = tester
          .getTopLeft(find.textContaining('Early zone'))
          .dy;
      final unzonedY = tester
          .getTopLeft(find.textContaining('Between zones'))
          .dy;
      final lateZoneY = tester.getTopLeft(find.textContaining('Late zone')).dy;

      expect(earlyZoneY, lessThan(unzonedY));
      expect(unzonedY, lessThan(lateZoneY));
    },
  );

  testWidgets(
    'an external event whose time falls inside a zone renders inside it, '
    'not as its own flat row',
    (tester) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
      final event = ExternalCalendarEvent(
        id: 'evt-1',
        title: 'Dentist',
        start: DateTime(2026, 9, 2, 7, 15),
        end: DateTime(2026, 9, 2, 7, 30),
        sourceCalendarId: 'cal-1',
      );

      await pump(tester, zones: [zone], externalEvents: [event]);

      final container =
          find.byType(ZoneContainerBlock).evaluate().single.widget
              as ZoneContainerBlock;
      expect(container.externalEvents.map((e) => e.id), contains(event.id));
      expect(find.textContaining('Dentist'), findsOneWidget);
    },
  );

  testWidgets(
    'an external event outside every zone renders as its own flat row',
    (tester) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
      final event = ExternalCalendarEvent(
        id: 'evt-1',
        title: 'Dentist',
        start: DateTime(2026, 9, 2, 13),
        end: DateTime(2026, 9, 2, 14),
        sourceCalendarId: 'cal-1',
      );

      await pump(tester, zones: [zone], externalEvents: [event]);

      expect(find.textContaining('Dentist'), findsOneWidget);
      final container =
          find.byType(ZoneContainerBlock).evaluate().single.widget
              as ZoneContainerBlock;
      expect(container.externalEvents, isEmpty);
    },
  );

  testWidgets(
    'tapping a zone\'s header fires onZoneHeaderTap with that zone — the '
    'read-only list\'s only way to edit a zone now',
    (tester) async {
      Zone? tapped;
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);

      await pump(tester, zones: [zone], onZoneHeaderTap: (z) => tapped = z);

      await tester.tap(find.textContaining('Morning ritual'));
      expect(tapped?.id, zone.id);
    },
  );

  testWidgets(
    'a zone renders with no onMoveStart/onResizeTopStart/onResizeBottomStart '
    'wired — move/resize are gone from this view entirely',
    (tester) async {
      await pump(tester, zones: [zoneAt('z1', 'Morning ritual', 7, 8)]);

      final container =
          find.byType(ZoneContainerBlock).evaluate().single.widget
              as ZoneContainerBlock;
      expect(container.onMoveStart, isNull);
      expect(container.onResizeTopStart, isNull);
      expect(container.onResizeBottomStart, isNull);
      expect(container.editModeEnabled, isFalse);
    },
  );

  group('devTimeRangeVisible ("Show time (from-to)")', () {
    // Requested directly: "Hide/show start end should also affect zone
    // view" — this dev toggle previously wasn't threaded into
    // ZoneDayTimeline at all, so every row here always showed its time
    // range regardless of the Settings toggle.
    testWidgets(
      'reaches the zone header — hides its own start-end time range',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 8);

        await pump(tester, zones: [zone], devTimeRangeVisible: false);

        // The zone header's title still carries its own "(duration)"
        // suffix regardless — only the separate start-end range hides.
        expect(find.textContaining('Morning ritual 1h'), findsOneWidget);
        expect(find.textContaining('7:00'), findsNothing);
        expect(find.textContaining('8:00'), findsNothing);
      },
    );

    testWidgets(
      'off (default true) still shows the zone header\'s time range',
      (tester) async {
        await pump(tester, zones: [zoneAt('z1', 'Morning ritual', 7, 8)]);

        expect(find.textContaining('7:00'), findsOneWidget);
      },
    );

    testWidgets(
      'reaches an in-zone task row — hides its start-end range, keeps the '
      'duration suffix independent',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 8);
        final task = Task.create(
          title: 'Stretch',
          scheduledAt: DateTime(2026, 9, 2, 7, 15),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.health,
        );

        await pump(
          tester,
          zones: [zone],
          tasks: [task],
          devTimeRangeVisible: false,
        );

        expect(find.textContaining('7:15'), findsNothing);
        expect(find.textContaining('(15m)'), findsOneWidget);
      },
    );

    testWidgets('reaches an unzoned task row (TaskCapsuleBlock)', (
      tester,
    ) async {
      final unzoned = Task.create(
        title: 'Water the plants',
        scheduledAt: DateTime(2026, 9, 2, 13),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.general,
      );

      await pump(tester, tasks: [unzoned], devTimeRangeVisible: false);

      final capsule =
          find.byType(TaskCapsuleBlock).evaluate().single.widget
              as TaskCapsuleBlock;
      expect(capsule.timeRangeVisible, isFalse);
    });

    testWidgets('reaches an unzoned external event row', (tester) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
      final event = ExternalCalendarEvent(
        id: 'evt-1',
        title: 'Dentist',
        start: DateTime(2026, 9, 2, 13),
        end: DateTime(2026, 9, 2, 14),
        sourceCalendarId: 'cal-1',
      );

      await pump(
        tester,
        zones: [zone],
        externalEvents: [event],
        devTimeRangeVisible: false,
        devDurationVisible: true,
      );

      expect(find.textContaining('1:00'), findsNothing);
      expect(find.textContaining('Dentist'), findsOneWidget);
    });

    testWidgets(
      'independent of devDurationVisible — both, either, or neither can '
      'be on',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 8);
        final task = Task.create(
          title: 'Stretch',
          scheduledAt: DateTime(2026, 9, 2, 7, 15),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.health,
        );

        await pump(
          tester,
          zones: [zone],
          tasks: [task],
          devTimeRangeVisible: true,
          devDurationVisible: false,
        );

        expect(find.textContaining('7:15'), findsOneWidget);
        expect(find.textContaining('(15m)'), findsNothing);
      },
    );
  });

  // Requested directly: "align tasks that are not in zones same with tasks
  // that have zones, so add margin that is equal zone left padding."
  group('unzoned rows line up with zoned rows (2026-09-15)', () {
    testWidgets('an unzoned task\'s own badge sits spacingMd further right '
        'than a bare row would, matching a zoned task\'s own inset', (
      tester,
    ) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
      final unzonedTask = Task.create(
        title: 'Out of zone',
        scheduledAt: DateTime(2026, 9, 2, 12),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      await pump(tester, zones: [zone], tasks: [unzonedTask]);

      // ZoneContainerBlock's own content padding is theme.spacingMd on the
      // left (see its own `EdgeInsets.fromLTRB` — unchanged by this fix).
      // An unzoned row must now sit that same spacingMd further right than
      // the zone container's own left edge, not flush with it.
      final theme = AmbleTheme.light;
      final zoneLeft = tester.getTopLeft(find.byType(ZoneContainerBlock)).dx;
      final unzonedTaskLeft = tester
          .getTopLeft(find.byType(TaskCapsuleBlock))
          .dx;

      expect(
        unzonedTaskLeft,
        moreOrLessEquals(zoneLeft + theme.spacingMd, epsilon: 0.5),
        reason:
            'an unzoned task must sit spacingMd right of the zone '
            'container\'s own left edge — matching where a zoned task\'s '
            'own badge sits inside that container\'s spacingMd padding, '
            'not flush with the container\'s outer edge',
      );
    });

    // Regression coverage for two defects reported together against one
    // screenshot: "items that don't fit in zones render differently than
    // those in zones" and "standup is imported task but doesn't show icon
    // with dotted circle.. like those imported in zones > and is in a
    // pane, but those in zones not."
    //
    // `_UnzonedEventRow` was a bare time/title Row inside its own
    // `DecoratedBox` panel, with no badge at all — so an imported event
    // read as a different KIND of object depending only on whether it
    // happened to fall inside a zone's window. It also lacked the
    // `if (timeLabel.isNotEmpty)` guard both in-container rows have, so
    // with time hidden its leftover `spacingSm` indented it 8px: measured
    // at title.left 64.0 against every other row kind's 72.0.
    testWidgets(
      'an unzoned imported event shows the same dashed badge as a zoned '
      'one, with no panel of its own, and its title lines up with every '
      'other row kind when time is hidden',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 18);
        // Outside the zone window -> renders as an unzoned imported row.
        final unzonedEvent = ExternalCalendarEvent(
          id: 'e-out',
          title: 'UnzonedEvent',
          start: DateTime(2026, 9, 2, 21),
          end: DateTime(2026, 9, 2, 21, 30),
          sourceCalendarId: 'cal-1',
        );
        // Inside it -> renders as a zoned imported row, the reference.
        final zonedEvent = ExternalCalendarEvent(
          id: 'e-in',
          title: 'ZonedEvent',
          start: DateTime(2026, 9, 2, 10),
          end: DateTime(2026, 9, 2, 10, 30),
          sourceCalendarId: 'cal-1',
        );

        await pump(
          tester,
          zones: [zone],
          externalEvents: [zonedEvent, unzonedEvent],
          devTimeRangeVisible: false,
          devDurationVisible: false,
        );

        // Both imported rows carry the badge — zoned AND unzoned.
        expect(find.byType(DashedPillRail), findsNWidgets(2));

        // The two imported rows share one title origin. Compared against
        // the ZONED imported row rather than the task row deliberately:
        // this suite's own `pump` passes an empty `categoryById`, so a
        // task row has no emoji and therefore renders no badge at all,
        // putting its title at a different x for a reason unrelated to
        // what's under test here.
        final zonedEventLeft = tester.getTopLeft(find.text('ZonedEvent')).dx;
        final unzonedEventLeft = tester
            .getTopLeft(find.text('UnzonedEvent'))
            .dx;

        expect(
          unzonedEventLeft,
          moreOrLessEquals(zonedEventLeft, epsilon: 0.5),
          reason:
              'unzoned imported title left=$unzonedEventLeft, zoned '
              'imported left=$zonedEventLeft',
        );
      },
    );

    // Regression coverage for a real bug, reported directly against a
    // screenshot: "note focus label is not aligned with labels tasks in
    // zones." An out-of-zone task renders as a `TaskCapsuleBlock`, whose
    // text column sat inside a `Center(widthFactor: 1)` — centring on
    // BOTH axes when only the vertical half was intended. It went
    // unnoticed while the Column always had a wide child holding its
    // width; with the indicator-icon row hidden AND the time line empty,
    // the Column shrank to the title alone, which then floated to the
    // horizontal centre. Measured before the fix: title.left 275.6
    // against every other row kind's 72.0.
    testWidgets(
      'an out-of-zone task title stays left-aligned with every other row '
      'kind even with icons hidden and no time line',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 18);
        final zonedEvent = ExternalCalendarEvent(
          id: 'e-in',
          title: 'ZonedEvent',
          start: DateTime(2026, 9, 2, 10),
          end: DateTime(2026, 9, 2, 10, 30),
          sourceCalendarId: 'cal-1',
        );
        // Outside the zone window -> an unzoned TaskCapsuleBlock row.
        final unzonedTask = Task.create(
          title: 'UnzonedTask',
          scheduledAt: DateTime(2026, 9, 2, 21),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        );

        await pump(
          tester,
          zones: [zone],
          tasks: [unzonedTask],
          externalEvents: [zonedEvent],
          devTimeRangeVisible: false,
          devDurationVisible: false,
          devIconsVisible: false,
        );

        expect(
          tester.getTopLeft(find.text('UnzonedTask')).dx,
          moreOrLessEquals(
            tester.getTopLeft(find.text('ZonedEvent')).dx,
            epsilon: 0.5,
          ),
          reason:
              'an out-of-zone task title must share the same origin as '
              'every in-zone row, not drift to the centre when its own '
              'text column happens to be narrow',
        );
      },
    );

    testWidgets('an unmatched external event gets the same left inset as '
        'an unzoned task', (tester) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
      final event = ExternalCalendarEvent(
        id: 'e1',
        title: 'Dentist',
        start: DateTime(2026, 9, 2, 14),
        end: DateTime(2026, 9, 2, 15),
        sourceCalendarId: 'cal-1',
      );

      await pump(tester, zones: [zone], externalEvents: [event]);

      final theme = AmbleTheme.light;
      final zoneLeft = tester.getTopLeft(find.byType(ZoneContainerBlock)).dx;
      // The row's own outer bounds (`_UnzonedEventRow`'s SizedBox), not the
      // "Dentist" text itself — that text sits further right again inside
      // the row's OWN internal `spacingMd` padding, which is unrelated to
      // the fix under test here (this row's OUTER left edge, set by the
      // Padding this fix added in ZoneDayTimeline).
      final eventRowLeft = tester
          .getTopLeft(
            find
                .ancestor(
                  of: find.textContaining('Dentist'),
                  matching: find.byType(SizedBox),
                )
                .first,
          )
          .dx;

      expect(
        eventRowLeft,
        moreOrLessEquals(zoneLeft + theme.spacingMd, epsilon: 0.5),
      );
    });
  });

  // Requested directly: "add config in dev to hide zones that have no
  // items inside in zone view only."
  group('devHideEmptyZones (2026-09-15)', () {
    testWidgets('off (default): an empty zone still renders its container '
        '— the existing documented default is unchanged', (tester) async {
      await pump(tester, zones: [zoneAt('z1', 'Empty zone', 7, 8)]);

      expect(find.byType(ZoneContainerBlock), findsOneWidget);
    });

    testWidgets('on: a zone with no member task and no matched event is '
        'hidden entirely', (tester) async {
      await pump(
        tester,
        zones: [zoneAt('z1', 'Empty zone', 7, 8)],
        devHideEmptyZones: true,
      );

      expect(find.byType(ZoneContainerBlock), findsNothing);
    });

    testWidgets('on: a zone WITH a member task still renders', (tester) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
      final task = Task.create(
        title: 'Stretch',
        scheduledAt: DateTime(2026, 9, 2, 7, 15),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.health,
      );

      await pump(tester, zones: [zone], tasks: [task], devHideEmptyZones: true);

      expect(find.byType(ZoneContainerBlock), findsOneWidget);
    });

    testWidgets('on: a zone with no task but a MATCHED external event '
        'still renders — an event counts as "has items inside"', (
      tester,
    ) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 9);
      final event = ExternalCalendarEvent(
        id: 'e1',
        title: 'Standup',
        start: DateTime(2026, 9, 2, 7, 30),
        end: DateTime(2026, 9, 2, 8),
        sourceCalendarId: 'cal-1',
      );

      await pump(
        tester,
        zones: [zone],
        externalEvents: [event],
        devHideEmptyZones: true,
      );

      expect(find.byType(ZoneContainerBlock), findsOneWidget);
    });

    testWidgets('on: hides only the empty zone among several, leaving '
        'non-empty ones and unzoned rows untouched', (tester) async {
      final emptyZone = zoneAt('z1', 'Empty zone', 6, 7);
      final fullZone = zoneAt('z2', 'Morning ritual', 9, 10);
      final task = Task.create(
        title: 'Stretch',
        scheduledAt: DateTime(2026, 9, 2, 9, 15),
        durationMinutes: 15,
        categoryId: BuiltInCategoryIds.health,
      );
      final unzonedTask = Task.create(
        title: 'Out of zone',
        scheduledAt: DateTime(2026, 9, 2, 14),
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      );

      await pump(
        tester,
        zones: [emptyZone, fullZone],
        tasks: [task, unzonedTask],
        devHideEmptyZones: true,
      );

      expect(find.byType(ZoneContainerBlock), findsOneWidget);
      expect(find.textContaining('Morning ritual'), findsOneWidget);
      expect(find.textContaining('Empty zone'), findsNothing);
      expect(find.textContaining('Out of zone'), findsOneWidget);
    });
  });
}
