import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_top_scroll_fade.dart';
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
}
