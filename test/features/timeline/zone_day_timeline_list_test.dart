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
    bool devZoneTaskStartTimeVisible = false,
    bool whatMattersEnabled = false,
    Map<String, Category> categoryById = const <String, Category>{},
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
            categoryById: categoryById,
            selectedDate: day,
            onTaskTap: (_) {},
            onToggleComplete: (_) {},
            onZoneHeaderTap: onZoneHeaderTap,
            devDurationVisible: devDurationVisible,
            devTimeRangeVisible: devTimeRangeVisible,
            devZoneCardFlat: devZoneCardFlat,
            devHideEmptyZones: devHideEmptyZones,
            devIconsVisible: devIconsVisible,
            devZoneTaskStartTimeVisible: devZoneTaskStartTimeVisible,
            whatMattersEnabled: whatMattersEnabled,
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

  // Requested directly: "wire for zoned" — swipe-to-reveal's add-note
  // action must reach ZoneContainerBlock from this screen, matching the
  // unzoned rows' own existing wiring exactly.
  testWidgets(
    'ZoneContainerBlock.onAddNote is wired, matching the unzoned rows\' '
    'own showAddTaskNoteSheet call',
    (tester) async {
      final zone = zoneAt('z1', 'Morning ritual', 7, 8);
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
      expect(container.onAddNote, isNotNull);
    },
  );

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

    // Reported directly: with `devTimeRangeVisible` at its real app
    // default (false — "should be disabled as default"), an imported
    // event's start time stopped showing at all in zone view. A native
    // task row was never actually affected by that toggle in the first
    // place — `devZoneTaskStartTimeVisible` (real app default: true)
    // wins outright over it there. This pins that an event row now gets
    // the same override, matching the app's own real default
    // combination rather than this suite's own opted-out defaults.
    testWidgets('an unzoned external event\'s start time still shows when '
        'startTimeOnlyVisible wins over a false timeRangeVisible — '
        'matching a real task row\'s own actual default behavior', (
      tester,
    ) async {
      final event = ExternalCalendarEvent(
        id: 'evt-2',
        title: 'Standup',
        start: DateTime(2026, 9, 2, 9, 30),
        end: DateTime(2026, 9, 2, 10),
        sourceCalendarId: 'cal-1',
      );

      await pump(
        tester,
        externalEvents: [event],
        devTimeRangeVisible: false,
        devZoneTaskStartTimeVisible: true,
      );

      expect(find.textContaining('9:30'), findsOneWidget);
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
  // Reported directly against a screenshot with two guide lines drawn
  // from the spatial Task view: "the left line is the left edge of the
  // hour in the day timeline, the second line is the left edge of the
  // position of the zone. It's obviously misaligned." Zone view used to
  // start its cards at just the 24px page inset, reserving no hour
  // gutter at all — 66px left of where the spatial view's own zone band
  // sits (`left: hourGutterWidth` = 24 page + 66 gutter = 90).
  group('zone cards align with the spatial view\'s zone band (2026-09-20)', () {
    testWidgets(
      'a zone card\'s left edge sits at zoneContentLeftInset, the same x '
      'the spatial view\'s zone band uses',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 8);
        await pump(tester, zones: [zone], tasks: const []);

        final cardLeft = tester.getTopLeft(find.byType(ZoneContainerBlock)).dx;

        expect(
          cardLeft,
          moreOrLessEquals(zoneContentLeftInset(AmbleTheme.light), epsilon: 0.5),
          reason:
              'the zone card must start where the spatial view\'s own '
              'zone band does (AmbleTheme.timelineZoneLeft), not at the '
              'bare page inset',
        );
      },
    );

    testWidgets(
      'a zoned task row\'s own time label still escapes all the way back '
      'to the spatial view\'s hour-label position (16px), even though its '
      'card now starts 66px further right',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 9);
        final zonedTask = Task.create(
          title: 'In zone',
          scheduledAt: DateTime(2026, 9, 2, 8),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        );

        await pump(
          tester,
          zones: [zone],
          tasks: [zonedTask],
          devZoneTaskStartTimeVisible: true,
        );

        final timeLeft = tester
            .getTopLeft(find.textContaining('8:00', findRichText: false))
            .dx;

        expect(
          timeLeft,
          moreOrLessEquals(zoneRowTimeLabelEdgeInset, epsilon: 0.5),
          reason:
              'the two guide lines in the report must BOTH match now: the '
              'hour label at 16px and the zone card at 90px',
        );
      },
    );
  });

  group('unzoned rows line up with zoned rows (2026-09-15)', () {
    testWidgets('an unzoned task\'s own badge sits spacingLg further right '
        'than the zone container\'s own edge, matching a zoned task\'s '
        'own inset', (
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

      // ZoneContainerBlock's own card LEFT padding is `spacingLg` (24),
      // so a ZONED task's content starts that far inside the container's
      // own edge. An unzoned row has no container of its own and mirrors
      // the same value explicitly (see ZoneDayTimeline's own Task()
      // branch), so the two kinds still share ONE x-origin — the
      // invariant this group really pins. Only the shared value moves
      // when that card padding changes.
      //
      // Checked against the unzoned ROW's own outer Padding (keyed), not
      // TaskCapsuleBlock's own top-left directly — 2026-09-19 added a
      // leading time column ahead of TaskCapsuleBlock on this row (see
      // ZoneDayTimeline's own Task() branch doc comment), so
      // TaskCapsuleBlock itself no longer starts at the row's own left
      // edge the way it used to.
      final zoneLeft = tester.getTopLeft(find.byType(ZoneContainerBlock)).dx;
      final unzonedRowLeft = tester
          .getTopLeft(
            find.byKey(ValueKey('unzoned-task-row-${unzonedTask.id}')),
          )
          .dx;

      expect(
        unzonedRowLeft,
        moreOrLessEquals(zoneLeft + AmbleTheme.light.spacingLg, epsilon: 0.5),
        reason:
            'an unzoned task row must sit spacingLg inside the zone '
            'container\'s own left edge — matching where a zoned task\'s '
            'own badge sits, since that card applies the same left '
            'padding to its own rows',
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

    // Regression coverage for the actual reported bug: "still see title of
    // task that is outside zone in zone view nonspatial is off." With
    // time visible (the default), a ZONED task row shows a leading time
    // column ahead of its badge (`_ZoneTaskRow`'s own `Flexible(flex: 2)`
    // time column), but an unzoned task rendered via `TaskCapsuleBlock`
    // used to show its time INLINE within the title text instead — no
    // separate leading column at all — so its badge (and title) sat
    // further LEFT than a zoned task's. Fixed by giving the unzoned row
    // its own matching leading time column (same [zoneTaskTimeLabel]
    // format) and suppressing TaskCapsuleBlock's own inline time text for
    // this call site.
    testWidgets(
      'a zoned task title and an unzoned task title share one x-origin '
      'when time is visible (the default) — the reported misalignment',
      (tester) async {
        // `devZoneTaskStartTimeVisible: true` — a short, fixed-width
        // "start time only" string ("7:00 AM"), deliberately short enough
        // to stay well under `_ZoneTaskRow`'s own `Flexible(flex: 2)` time
        // column's cap. The full "start - end (duration)" string this
        // toggle normally shows is wide enough to genuinely ellipsize
        // against that same cap even with just one row in the whole list
        // (confirmed while writing this test — a PRE-EXISTING
        // characteristic of `_ZoneTaskRow`'s own narrow column, unrelated
        // to this fix), which would make an exact-pixel title-origin
        // comparison meaningless: the zoned title's own x already shifts
        // left by however many characters got clipped, for a reason this
        // test isn't about at all.
        //
        // A real resolved `Category` — this suite's own `pump` otherwise
        // passes an empty `categoryById`, under which `_ZoneTaskRow`'s
        // `hasCategory` is false and it renders NO badge at all, while
        // `TaskCapsuleBlock` always renders one (a "General" fallback
        // glyph) regardless — a real, pre-existing asymmetry between the
        // two row types that would make an empty-category comparison
        // apples-to-oranges. Every task in the real app always resolves a
        // real `Category` (even "General" is a seeded row, never
        // actually null — see `category_providers.dart`), so a real one
        // here matches production, where both rows do render a badge.
        final category = Category(
          id: BuiltInCategoryIds.work,
          name: 'Work',
          colorToken: 0,
          emoji: '💼',
          isBuiltIn: true,
        );
        final zone = zoneAt('z1', 'Morning ritual', 7, 9);
        final zonedTask = Task.create(
          title: 'ZonedTask',
          scheduledAt: DateTime(2026, 9, 2, 7),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        );
        final unzonedTask = Task.create(
          title: 'UnzonedTask',
          scheduledAt: DateTime(2026, 9, 2, 21),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        );

        await pump(
          tester,
          zones: [zone],
          tasks: [zonedTask, unzonedTask],
          devZoneTaskStartTimeVisible: true,
          categoryById: {BuiltInCategoryIds.work: category},
        );

        expect(
          tester.getTopLeft(find.text('UnzonedTask')).dx,
          moreOrLessEquals(
            tester.getTopLeft(find.text('ZonedTask')).dx,
            epsilon: 0.5,
          ),
          reason:
              'an unzoned task title must share the same x-origin as a '
              'zoned task title when both show their own time — an '
              'unzoned row needs the same leading time column a zoned '
              'row already has, or its badge/title sit further left',
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

      // `spacingLg` inside the container's own left edge — the same
      // mirrored card padding the unzoned-task case above pins, so both
      // kinds of unzoned row share one x-origin with zoned content.
      expect(
        eventRowLeft,
        moreOrLessEquals(zoneLeft + AmbleTheme.light.spacingLg, epsilon: 0.5),
      );
    });

    // Reported directly: an imported event's time never got the same
    // left-pulled treatment native tasks' own time labels do — it used
    // to render as ordinary in-flow text instead of escaping back to
    // `zoneRowTimeLabelEdgeInset` via `ZoneRowTimeLabel`, the same
    // mechanism `_ZoneTaskRow`/the unzoned task row above already use.
    testWidgets(
      'an unzoned external event\'s time label escapes to the SAME x as '
      'an unzoned task\'s time label — both use ZoneRowTimeLabel now',
      (tester) async {
        final task = Task.create(
          title: 'A task',
          scheduledAt: DateTime(2026, 9, 2, 9),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        );
        final event = ExternalCalendarEvent(
          id: 'e1',
          title: 'Dentist',
          start: DateTime(2026, 9, 2, 14),
          end: DateTime(2026, 9, 2, 15),
          sourceCalendarId: 'cal-1',
        );

        await pump(tester, tasks: [task], externalEvents: [event]);

        final labelLefts = tester
            .widgetList<ZoneRowTimeLabel>(find.byType(ZoneRowTimeLabel))
            .map((w) => w.leftPaddingToEscape)
            .toSet();

        expect(
          labelLefts,
          hasLength(1),
          reason:
              'the task row and the event row must use the exact same '
              'leftPaddingToEscape, or their labels would land at '
              'different x positions despite both claiming to escape '
              'to the same edge inset',
        );
      },
    );

    // Reported directly against a screenshot: an unzoned row's time text
    // sat visibly off the badge's own vertical center. Root cause: this
    // row's enclosing `Row` used to be `stretch`ed (to give
    // `TaskCapsuleBlock` its full natural height, up to the completion
    // checkbox's 48px tap target) — which also stretched the ZERO-WIDTH
    // `ZoneRowTimeLabel` box to that same full height, centering the
    // label within it. But the badge inside `TaskCapsuleBlock` is
    // `topCenter`-anchored at `theme.sizeTaskBadge` from the row's own
    // TOP, not centered in whatever the row's tallest sibling happens to
    // be — the exact same "centers within the wrong box" failure already
    // fixed once for the title text (see `TaskCapsuleBlock`'s own
    // `textHeaderHeight` comment), never applied to this label.
    testWidgets(
      'an unzoned row\'s time label is vertically centered against the '
      'BADGE\'s own height, not the whole (possibly taller) row',
      (tester) async {
        final task = Task.create(
          title: 'Out of zone',
          scheduledAt: DateTime(2026, 9, 2, 14),
          durationMinutes: 30,
          categoryId: BuiltInCategoryIds.work,
        );

        await pump(tester, tasks: [task]);

        final theme = AmbleTheme.light;
        final pillTop = tester.getTopLeft(find.byType(TaskCapsuleBlock)).dy;
        final expectedLabelCenter = pillTop + theme.sizeTaskBadge / 2;

        final labelRect = tester.getRect(find.byType(ZoneRowTimeLabel));

        expect(
          labelRect.center.dy,
          moreOrLessEquals(expectedLabelCenter, epsilon: 1),
          reason:
              'the time label must center within a sizeTaskBadge-tall '
              'region at the row\'s own top, matching the badge\'s own '
              'anchor — not the row\'s full (possibly 48px, checkbox-'
              'driven) stretched height',
        );
      },
    );
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

  // Requested directly: "should also hide emptied zones." What Matters
  // hides every non-important task (each row fades/collapses on its own,
  // via WhatMattersRow) and every external event unconditionally — a
  // zone whose members are ALL non-important (or only had external
  // events) renders as an empty card once that happens, even without the
  // dev toggle above ever being turned on. `whatMattersEnabled` reuses
  // the exact same empty-zone filter `devHideEmptyZones` does, applied
  // automatically whenever the lens is on.
  group('What Matters hides emptied zones (2026-09-20)', () {
    testWidgets(
      'whatMattersEnabled true: a zone whose only task is NOT important '
      'is hidden entirely, same as a genuinely empty zone',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 8);
        final unimportantTask = Task.create(
          title: 'Not important',
          scheduledAt: DateTime(2026, 9, 2, 7, 15),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.health,
        );

        await pump(
          tester,
          zones: [zone],
          tasks: [unimportantTask],
          whatMattersEnabled: true,
        );

        expect(find.byType(ZoneContainerBlock).hitTestable(), findsNothing);
      },
    );

    testWidgets(
      'whatMattersEnabled true: a zone with at least one IMPORTANT task '
      'still renders',
      (tester) async {
        final zone = zoneAt('z1', 'Morning ritual', 7, 9);
        final important = Task.create(
          title: 'Important task',
          scheduledAt: DateTime(2026, 9, 2, 7, 15),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.health,
          isImportant: true,
        );
        final unimportant = Task.create(
          title: 'Not important',
          scheduledAt: DateTime(2026, 9, 2, 8, 15),
          durationMinutes: 15,
          categoryId: BuiltInCategoryIds.health,
        );

        await pump(
          tester,
          zones: [zone],
          tasks: [important, unimportant],
          whatMattersEnabled: true,
        );

        expect(find.byType(ZoneContainerBlock), findsOneWidget);
      },
    );

    testWidgets('whatMattersEnabled true: a zone with no tasks and no external '
        'events (as `TimelineScreen` already provides once What Matters '
        'is on — see that screen\'s own filtering) is hidden entirely', (
      tester,
    ) async {
      // Deliberately passes NO external events: this widget is never
      // responsible for filtering them itself under What Matters —
      // `TimelineScreen` already empties `externalEvents` before it
      // ever reaches here (see that screen's own `ZoneDayTimeline`
      // call site). This test only pins that a zone with genuinely
      // nothing visible left in it is hidden, the same as
      // `devHideEmptyZones`'s own equivalent case above.
      final zone = zoneAt('z1', 'Morning ritual', 7, 9);

      await pump(tester, zones: [zone], whatMattersEnabled: true);

        expect(find.byType(ZoneContainerBlock).hitTestable(), findsNothing);
    });
  });
}
