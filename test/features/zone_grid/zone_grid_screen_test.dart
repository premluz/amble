import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/features/zone_grid/zone_grid_screen.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
import 'package:amble/features/zone_grid/zone_grid_tab.dart';
import 'package:amble/features/zone_grid/new_zone_sheet.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/shared/services/zone_cascade_reschedule.dart';
import 'package:amble/shared/models/zone.dart';

import '../../support/memory_zone_repositories.dart';

void main() {
  late MemoryZoneRepository repository;
  late MemoryZoneFacetRepository facets;
  late ProviderContainer container;
  setUp(() {
    repository = MemoryZoneRepository();
    facets = MemoryZoneFacetRepository();
    container = ProviderContainer(
      overrides: [
        zoneRepositoryProvider.overrideWithValue(repository),
        zoneFacetRepositoryProvider.overrideWithValue(facets),
        preferencesRepositoryProvider.overrideWithValue(
          MemoryPreferencesRepository(),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.dark]),
          // This suite is entirely about the ZONE grid's own paint/drag
          // gestures — explicit tab, since `ZoneGridScreen`'s own default
          // is now Tasks (see its own doc comment, 2026-09-17 merge).
          home: const ZoneGridScreen(initialTab: ZoneGridTab.zones),
        ),
      ),
    );
    await tester.pump();
  }

  Offset point(WidgetTester tester, int day, int minute) {
    final rect = tester.getRect(
      find.byKey(const ValueKey('zone-paint-surface')),
    );
    // Must track `_axisWidth` in `zone_grid_screen.dart` — 52, so "00:00"
    // (~36px of JetBrains Mono at 12px) still fits between the two 8px
    // insets without wrapping.
    const axisWidth = 60.0;
    // 1.5 px/minute — TimelinePixelsPerMinuteSetting's own default, now
    // shared with the spatial Task view (was a hardcoded 44/60 here).
    const pixelsPerMinute = 1.5;
    return Offset(
      rect.left + axisWidth + (day - .5) * (rect.width - axisWidth) / 7,
      rect.top + minute * pixelsPerMinute,
    );
  }

  testWidgets(
    'long press paints across days; nothing is persisted before naming',
    (tester) async {
      await pump(tester);
      final gesture = await tester.startGesture(point(tester, 1, 180));
      await tester.pump(const Duration(milliseconds: 550));
      await gesture.moveTo(point(tester, 4, 360));
      await tester.pump();
      for (var day = 1; day <= 4; day++) {
        expect(find.byKey(ValueKey('zone-phantom-$day')), findsOneWidget);
      }
      expect(find.byType(NewZoneSheet), findsNothing);
      expect(repository.getAll(), isEmpty);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      final sheet = tester.widget<NewZoneSheet>(find.byType(NewZoneSheet));
      expect(sheet.target.weekdays, {1, 2, 3, 4});
      expect(sheet.target.startMinutes, 180);
      expect(sheet.target.endMinutes, 360);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(NewZoneSheet),
              matching: find.byType(TextField),
            )
            .first,
        'Focus',
      );
      await tester.tap(find.text('Add zone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.getAll(), hasLength(4));
      expect(facets.getAll(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('normal vertical swipe scrolls rather than painting', (
    tester,
  ) async {
    await pump(tester);
    final before = point(tester, 2, 300);
    await tester.dragFrom(before, const Offset(0, -150));
    await tester.pump();
    expect(point(tester, 2, 300).dy, lessThan(before.dy));
    expect(find.byType(NewZoneSheet), findsNothing);
    expect(find.byKey(const ValueKey('zone-paint-selection')), findsNothing);
  });
  testWidgets('tap creates one day and dismissal discards every phantom', (
    tester,
  ) async {
    await pump(tester);
    await tester.tapAt(point(tester, 3, 300));
    await tester.pump();
    expect(
      tester.widget<NewZoneSheet>(find.byType(NewZoneSheet)).target.weekdays,
      {3},
    );
    tester.widget<NewZoneSheet>(find.byType(NewZoneSheet)).onDismiss();
    await tester.pump();
    expect(repository.getAll(), isEmpty);
    expect(find.byKey(const ValueKey('zone-paint-selection')), findsNothing);
  });
  // Painting is entered by LONG PRESS, not an immediate drag. The Zones
  // tab is always in edit mode now, so a plain drag has to stay available
  // to the scroll view — see this screen's own `_editing` doc comment.
  testWidgets(
    'a long-press drag paints, and pointer cancellation discards it',
    (tester) async {
      await pump(tester);
      final g = await tester.startGesture(point(tester, 5, 240));
      await tester.pump(const Duration(milliseconds: 600));
      await g.moveTo(point(tester, 2, 420));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('zone-paint-selection')),
        findsOneWidget,
      );
      await g.cancel();
      await tester.pump();
      expect(find.byKey(const ValueKey('zone-paint-selection')), findsNothing);
      expect(repository.getAll(), isEmpty);
    },
  );
  testWidgets(
    'gradual diagonal painting wins over vertical scroll once long-pressed',
    (tester) async {
      await pump(tester);
      final start = point(tester, 1, 180), end = point(tester, 5, 360);
      final before = point(tester, 1, 0).dy;
      final g = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      for (var step = 1; step <= 30; step++) {
        await g.moveTo(Offset.lerp(start, end, step / 30)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      final target = tester
          .widget<NewZoneSheet>(find.byType(NewZoneSheet))
          .target;
      expect(target.weekdays, {1, 2, 3, 4, 5});
      expect(target.startMinutes, 180);
      expect(target.endMinutes, 360);
      expect(point(tester, 1, 0).dy, before);
    },
  );
  testWidgets(
    'sideways fill survives rebuilds and copies hours, not other placements',
    (tester) async {
      final source =
          (await container
                  .read(zoneListProvider.notifier)
                  .paintWeeklyZones(
                    title: 'Commute',
                    weekdays: {1},
                    startMinutes: 240,
                    endMinutes: 300,
                  ))
              .single;
      await pump(tester);
      await tester.tapAt(point(tester, 1, 270));
      await tester.pump();
      expect(container.read(zoneEditSelectionProvider), contains(source.id));
      final g = await tester.startGesture(point(tester, 1, 270));
      await g.moveTo(point(tester, 2, 270));
      await tester.pump();
      await g.moveTo(point(tester, 4, 270));
      await tester.pump();
      expect(find.byKey(const ValueKey('zone-phantom-4')), findsOneWidget);
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.getAll(), hasLength(4));
      expect(
        repository.getAll().every(
          (z) => z.startMinutes == 240 && z.endMinutes == 300,
        ),
        isTrue,
      );
      expect(find.byType(ZoneGridBlock), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );
  // Overlap NEVER refuses — confirmed directly, "never prevent action".
  // Replaces a test that asserted the opposite (a refusal message and a
  // single surviving zone), written when overlap hard-blocked.
  testWidgets(
    'a paint overlapping an existing zone is written anyway, and displaces it',
    (tester) async {
      await container
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: 'Work',
            weekdays: {2},
            startMinutes: 240,
            endMinutes: 300,
          );
      await pump(tester);
      final before = repository.getAll().single;
      final g = await tester.startGesture(point(tester, 1, 180));
      await tester.pump(const Duration(milliseconds: 550));
      await g.moveTo(point(tester, 3, 360));
      await tester.pump();
      // No refusal affordance exists any more.
      expect(find.text('Overlap'), findsNothing);
      await g.up();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(
        find
            .descendant(
              of: find.byType(NewZoneSheet),
              matching: find.byType(TextField),
            )
            .first,
        'New',
      );
      await tester.tap(find.text('Add zone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('overlaps another zone'), findsNothing);
      // All three painted days were written — nothing partial, nothing refused.
      final painted = repository
          .getAll()
          .where((z) => z.title == 'New')
          .toList();
      expect(painted, hasLength(3));
      // The pre-existing Tuesday zone survives (never deleted) and keeps at
      // least a sliver.
      final after = repository.getById(before.id);
      expect(after, isNotNull);
      expect(
        after!.endMinutes - after.startMinutes,
        greaterThanOrEqualTo(kZoneSliverMinutes),
      );
    },
  );

  // Requested directly: "hours of day have different color on different
  // screens... needs unified." This screen's own hour-axis ("HH:00")
  // labels used to render in `colorTextTertiary`, distinct from the
  // spatial Timeline's `TaskBoundaryMarkers`, which uses
  // `colorTextSecondary` — unified onto the Timeline's own color.
  testWidgets(
    'hour-axis labels render in colorTextSecondary, matching the spatial '
    'Timeline\'s own TaskBoundaryMarkers exactly',
    (tester) async {
      await pump(tester);

      final theme = AmbleTheme.dark;
      final hourLabel = tester.widget<Text>(find.text('00:00').first);

      expect(hourLabel.style?.color, theme.colorTextSecondary);
      expect(hourLabel.style?.color, isNot(theme.colorTextTertiary));
    },
  );

  // Reported directly, twice: "when tap and drag zones let's make it
  // multi select zones", then again after a first attempt was backed out
  // — "on zone edit, tapping on an existing zone and sweeping does not
  // make any selection... can't see the selection or either the border."
  //
  // Device logs later proved tap-to-select itself was fine all along
  // (BLOCK_TAP/ZONE_TAP fired correctly); the genuine gap was that DRAG
  // on a zone did nothing, because the backed-out attempt left unselected
  // zones with null drag handlers.
  group('drag-to-multi-select sweep (2026-09-20)', () {
    testWidgets(
      'dragging from an UNSELECTED zone across a neighbour selects BOTH, '
      'and shows a live marquee while the finger is down',
      (tester) async {
        await container
            .read(zoneListProvider.notifier)
            .paintWeeklyZones(
              title: 'Commute',
              weekdays: {1, 2},
              startMinutes: 240,
              endMinutes: 300,
            );
        await pump(tester);
        container.read(zoneEditSelectionProvider.notifier).clear();
        await tester.pump();

        final marquee = find.byKey(const ValueKey('zone-sweep-selection'));
        expect(marquee, findsNothing);

        final from = point(tester, 1, 270);
        final to = point(tester, 2, 270);
        final gesture = await tester.startGesture(from);
        await tester.pump();
        // Stepped, not one `moveTo` — a single jump produces a drag START
        // with no UPDATEs at all (verified with a probe on the task-side
        // sweep), so the marquee would never grow and the test would
        // measure nothing.
        for (var i = 1; i <= 8; i++) {
          await gesture.moveTo(Offset.lerp(from, to, i / 8)!);
          await tester.pump();
        }

        expect(
          marquee,
          findsOneWidget,
          reason: 'the marquee must be visible mid-sweep',
        );
        expect(
          container.read(zoneEditSelectionProvider),
          hasLength(2),
          reason: 'both swept zones must end up selected',
        );

        await gesture.up();
        await tester.pump();

        expect(
          marquee,
          findsNothing,
          reason: 'the marquee is torn down on release',
        );
        expect(
          container.read(zoneEditSelectionProvider),
          hasLength(2),
          reason: 'the selection the sweep produced must survive it',
        );
      },
    );

    testWidgets(
      'the sweep is ADDITIVE — crossing back over a zone already swept '
      'leaves it selected rather than toggling it off',
      (tester) async {
        await container
            .read(zoneListProvider.notifier)
            .paintWeeklyZones(
              title: 'Commute',
              weekdays: {1, 2},
              startMinutes: 240,
              endMinutes: 300,
            );
        await pump(tester);
        container.read(zoneEditSelectionProvider.notifier).clear();
        await tester.pump();

        final from = point(tester, 1, 270);
        final to = point(tester, 2, 270);
        final gesture = await tester.startGesture(from);
        await tester.pump();
        for (final target in [to, from, to]) {
          for (var i = 1; i <= 4; i++) {
            await gesture.moveTo(Offset.lerp(from, target, i / 4)!);
            await tester.pump();
          }
        }
        await gesture.up();
        await tester.pump();

        expect(container.read(zoneEditSelectionProvider), hasLength(2));
      },
    );
  });

  // Reported directly: "in edit mode on top we should only have 2 tabs
  // task and zones and close on the bottom tool nav... in zones edit and
  // close (close on the leftmost)." The top row used to carry the
  // Tasks/Zones switch PLUS Edit/Close icons; both icons moved to a
  // floating bottom dock.
  group('top row / bottom dock restructure (2026-09-20)', () {
    testWidgets(
      'the tab switch sits ABOVE Close — confirming it moved out of the '
      'top row into a bottom dock, not that it no longer exists anywhere',
      (tester) async {
        await pump(tester);

        final tabSwitchTop = tester.getTopLeft(find.text('Tasks')).dy;
        final closeTop = tester.getTopLeft(find.byTooltip('Close zones')).dy;

        expect(
          closeTop,
          greaterThan(tabSwitchTop + 100),
          reason:
              'Close must sit well below the tab switch (a bottom dock, '
              'not the same top row it used to share)',
        );
      },
    );

    // The Edit/Done toggle that used to sit beside Close is GONE — the
    // Zones tab is always in edit mode now, requested directly ("Edit
    // zones screen should be in edit mode always no need to press edit to
    // edit"), so a button that toggles into it has nothing left to do.
    testWidgets('the Zones tab dock has no Edit toggle — editing is always on', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byTooltip('Close zones'), findsOneWidget);
      expect(find.byTooltip('Edit zones'), findsNothing);
      expect(find.byTooltip('Finish editing'), findsNothing);
    });

    testWidgets('tapping the bottom dock\'s Close pops the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData(extensions: [AmbleTheme.dark]),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const ZoneGridScreen(initialTab: ZoneGridTab.zones),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close zones'));
      await tester.pumpAndSettle();

      expect(find.byType(ZoneGridScreen), findsNothing);
    });
  });
  // Requested directly: "when we have marque selection and release sheet
  // add zone shows but we should be able to resize zones in that view
  // also — so we need to add resize handles (dots) same as on task but on
  // all sides top bottom (resize zone time start end) left right resize
  // sideways to include/reduce days."
  group('marquee resize handles', () {
    // Paints Tue 04:00-05:00 and leaves the naming sheet open, which is
    // the state the handles live in.
    Future<void> paint(WidgetTester tester) async {
      await pump(tester);
      final g = await tester.startGesture(point(tester, 2, 240));
      await tester.pump(const Duration(milliseconds: 600));
      await g.moveTo(point(tester, 2, 300));
      await tester.pump();
      await g.up();
      // `pumpAndSettle`, not a fixed pump — `_endPaint` scrolls the new
      // marquee into view, and `SingleChildScrollView` wraps its contents
      // in an `IgnorePointer` while that animation runs. Stopping early
      // leaves the handles rendered but unreachable by any pointer.
      await tester.pumpAndSettle();
    }

    NewZoneTarget target(WidgetTester tester) =>
        tester.widget<NewZoneSheet>(find.byType(NewZoneSheet)).target;

    // The handles are a private widget, so they're located by their
    // rendered position relative to the marquee rather than by type.
    Rect marquee(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('zone-paint-selection')));

    testWidgets('a handle sits centred on each of the four edges', (
      tester,
    ) async {
      await paint(tester);
      expect(find.byType(NewZoneSheet), findsOneWidget);

      final rect = marquee(tester);
      final dots = find
          .byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_MarqueeResizeHandle',
          )
          .evaluate()
          .map((e) => tester.getRect(find.byWidget(e.widget)).center)
          .toList();

      expect(dots, hasLength(4));
      // One per edge midpoint, within a pixel of the marquee's own edges.
      expect(
        dots.any(
          (c) =>
              (c.dy - rect.top).abs() < 1 &&
              (c.dx - rect.center.dx).abs() < 1,
        ),
        isTrue,
        reason: 'top handle',
      );
      expect(
        dots.any(
          (c) =>
              (c.dy - rect.bottom).abs() < 1 &&
              (c.dx - rect.center.dx).abs() < 1,
        ),
        isTrue,
        reason: 'bottom handle',
      );
      expect(
        dots.any(
          (c) =>
              (c.dx - rect.left).abs() < 1 &&
              (c.dy - rect.center.dy).abs() < 1,
        ),
        isTrue,
        reason: 'left handle',
      );
      expect(
        dots.any(
          (c) =>
              (c.dx - rect.right).abs() < 1 &&
              (c.dy - rect.center.dy).abs() < 1,
        ),
        isTrue,
        reason: 'right handle',
      );
    });

    testWidgets('dragging the BOTTOM handle changes the end time, not the '
        'start', (tester) async {
      await paint(tester);
      final before = target(tester);

      final rect = marquee(tester);
      final bottom = Offset(rect.center.dx, rect.bottom);
      final g = await tester.startGesture(bottom);
      await g.moveTo(Offset(bottom.dx, bottom.dy + 90));
      await tester.pump();
      await g.up();
      await tester.pump();

      final after = target(tester);
      expect(after.startMinutes, before.startMinutes,
          reason: 'the untouched edge must not move');
      expect(after.endMinutes, greaterThan(before.endMinutes));
    });

    testWidgets('dragging the RIGHT handle widens the weekday span',
        (tester) async {
      await paint(tester);
      final before = target(tester);
      expect(before.weekdays, {2});

      final rect = marquee(tester);
      final right = Offset(rect.right, rect.center.dy);
      final g = await tester.startGesture(right);
      await g.moveTo(Offset(right.dx + rect.width * 1.5, right.dy));
      await tester.pump();
      await g.up();
      await tester.pump();

      final after = target(tester);
      expect(after.weekdays.length, greaterThan(1),
          reason: 'dragging right must add days');
      expect(after.startMinutes, before.startMinutes);
      expect(after.endMinutes, before.endMinutes);
    });

    // Reported directly: "when dragging handle it actually moves across
    // instead of resizing smoothly." `_resizeMarquee` used to hand BOTH
    // edges to `ZonePaintSelection.between`, which takes a min/max of
    // whatever pair it is given — so dragging one edge past its opposite
    // silently swapped which edge was which and the whole rectangle
    // jumped sideways. Each edge now clamps against its opposite instead.
    testWidgets(
      'dragging the RIGHT handle LEFT past the left edge clamps instead of '
      'flipping the marquee across the grid',
      (tester) async {
        await paint(tester);
        final before = target(tester);
        expect(before.weekdays, {2});

        final rect = marquee(tester);
        final right = Offset(rect.right, rect.center.dy);
        final g = await tester.startGesture(right);
        // Well past the LEFT edge — the motion that used to invert the
        // rectangle and shift it into earlier days.
        await g.moveTo(Offset(rect.left - rect.width * 2, right.dy));
        await tester.pump();
        await g.up();
        await tester.pump();

        final after = target(tester);
        expect(
          after.weekdays,
          {2},
          reason:
              'the marquee must stay pinned on its own day, collapsed to a '
              'single column — not jump to earlier days',
        );
      },
    );

    testWidgets(
      'dragging the BOTTOM handle UP past the top edge clamps instead of '
      'flipping start/end',
      (tester) async {
        await paint(tester);
        final before = target(tester);

        final rect = marquee(tester);
        final bottom = Offset(rect.center.dx, rect.bottom);
        final g = await tester.startGesture(bottom);
        await g.moveTo(Offset(bottom.dx, rect.top - rect.height * 2));
        await tester.pump();
        await g.up();
        await tester.pump();

        final after = target(tester);
        expect(
          after.startMinutes,
          before.startMinutes,
          reason: 'the untouched top edge must not move',
        );
        expect(
          after.endMinutes,
          greaterThan(after.startMinutes),
          reason: 'end must stay after start, never invert past it',
        );
      },
    );

    // Requested directly: "when drawn and release should be able to drag
    // and move drawn zones that are not saved yet."
    testWidgets('dragging the marquee BODY moves the whole rectangle, '
        'keeping its size', (tester) async {
      await paint(tester);
      final before = target(tester);

      final rect = marquee(tester);
      final g = await tester.startGesture(rect.center);
      // Two columns right and an hour down, in one continuous drag.
      await g.moveBy(Offset(rect.width * 2, 60 * 1.5));
      await tester.pump();
      await g.up();
      await tester.pump();

      final after = target(tester);
      expect(
        after.weekdays.length,
        before.weekdays.length,
        reason: 'a move must not change how many days are covered',
      );
      expect(
        after.endMinutes - after.startMinutes,
        before.endMinutes - before.startMinutes,
        reason: 'a move must not change the duration',
      );
      expect(
        after.weekdays.first,
        greaterThan(before.weekdays.first),
        reason: 'dragging right must move it to a later day',
      );
      expect(
        after.startMinutes,
        greaterThan(before.startMinutes),
        reason: 'dragging down must move it later in the day',
      );
    });

    // Requested directly: "when marquee is drawn and released then single
    // tap anywhere outside removes it... so when not saved marquee drawn
    // other interactions are not active."
    testWidgets('a single tap outside dismisses the marquee and its sheet', (
      tester,
    ) async {
      await paint(tester);
      expect(find.byType(NewZoneSheet), findsOneWidget);

      // Well to the RIGHT of the marquee but at the same height, so the
      // tap is unambiguously on the paint surface: below the sheet's own
      // top edge would hit the sheet, and the surface's own rect extends
      // outside the viewport (it scrolls), so its corners aren't safe.
      final surface = tester.getRect(
        find.byKey(const ValueKey('zone-paint-surface')),
      );
      final rect = marquee(tester);
      await tester.tapAt(
        Offset(surface.left + surface.width * 0.8, rect.center.dy),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(NewZoneSheet),
        findsNothing,
        reason: 'the naming sheet must close',
      );
      expect(
        find.byKey(const ValueKey('zone-paint-selection')),
        findsNothing,
        reason: 'the marquee itself must be removed',
      );
      expect(
        repository.getAll(),
        isEmpty,
        reason: 'dismissing must not save anything',
      );
    });

    testWidgets(
      'while a marquee is pending, tapping an existing zone does NOT select '
      'it — the tap dismisses the marquee instead',
      (tester) async {
        // A saved zone to tap on, on a different day from the marquee.
        await repository.save(
          Zone(
            id: 'existing',
            title: 'Existing',
            startMinutes: 240,
            endMinutes: 300,
            weekday: 5,
          ),
        );
        await paint(tester);
        expect(find.byType(NewZoneSheet), findsOneWidget);

        final block = find.byType(ZoneGridBlock);
        expect(block, findsOneWidget, reason: 'the saved zone should render');
        await tester.tap(block, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          container.read(zoneEditSelectionProvider),
          isEmpty,
          reason:
              'tapping a zone while a marquee is pending must not select it',
        );
        expect(
          find.byType(NewZoneSheet),
          findsNothing,
          reason: 'that same tap should dismiss the marquee',
        );
      },
    );
  });
}
