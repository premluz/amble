import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_bottom_dock.dart';
import 'package:amble/core/widgets/app_button.dart';
import 'package:amble/core/widgets/app_shell_chrome.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/features/zone_grid/zone_grid_screen.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
import 'package:amble/features/zone_grid/zone_grid_tab.dart';
import 'package:amble/features/zone_grid/new_zone_sheet.dart';
import 'package:amble/features/timeline/edit_selection_provider.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
import 'package:amble/shared/services/zone_cascade_reschedule.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/providers/task_providers.dart';
import 'package:amble/shared/repositories/task_repository.dart';

import '../../support/memory_zone_repositories.dart';
import '../../support/fake_notification_service.dart';
import 'package:amble/shared/providers/notification_providers.dart';

void main() {
  late MemoryZoneRepository repository;
  late MemoryZoneFacetRepository facets;
  late ProviderContainer container;
  setUp(() {
    repository = MemoryZoneRepository();
    facets = MemoryZoneFacetRepository();
    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(_MemoryTasks()),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
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

  // The real shell embeds `ZoneGridScreen` inside `AppShellChromeScope` with
  // a real `AppBottomDock` as a SIBLING in an outer `Stack` (`main.dart`'s
  // own structure) — the bare `pump` helper above mounts neither, so
  // `_claimOrBuildDock`'s `controller == null` branch renders the dock
  // LOCALLY inside `zone_grid_screen.dart`'s own `Stack` instead, at a
  // position that (in a test harness) can end up obstructed by other
  // content in that same local stack. Any test that needs to actually TAP
  // a dock action (Close/Edit/Remove) needs this real shell wiring instead
  // of the bare `pump`, or the tap can silently miss.
  Future<void> pumpWithShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chromeController = AppShellChromeController();
    addTearDown(chromeController.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(extensions: [AmbleTheme.dark]),
          home: Scaffold(
            body: AppShellChromeScope(
              controller: chromeController,
              child: Stack(
                children: [
                  const ZoneGridScreen(initialTab: ZoneGridTab.zones),
                  SafeArea(
                    top: false,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AppBottomDock(
                          activeView: AppBottomDockView.timeline,
                          onSelectView: (_) {},
                          onEditTap: () {},
                          whatMattersEnabled: false,
                          onWhatMattersTap: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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
  for (final direction in [-1, 1]) {
    testWidgets('selected zone side handle fills days direction $direction', (
      tester,
    ) async {
      final source =
          (await container
                  .read(zoneListProvider.notifier)
                  .paintWeeklyZones(
                    title: 'Work',
                    weekdays: {3},
                    startMinutes: 240,
                    endMinutes: 360,
                  ))
              .single;
      await pump(tester);
      await tester.tapAt(point(tester, 3, 300));
      await tester.pump();
      final block = find.byWidgetPredicate(
        (w) => w is ZoneGridBlock && w.zone.id == source.id,
      );
      final rect = tester.getRect(block);
      final from = Offset(
        direction < 0 ? rect.left + 2 : rect.right - 2,
        rect.center.dy,
      );
      final column = (point(tester, 4, 300) - point(tester, 3, 300)).dx;
      final widths = <double>[];
      final g = await tester.startGesture(from);
      for (var i = 1; i <= 30; i++) {
        await g.moveTo(from + Offset(direction * column * 2 * i / 30, 0));
        await tester.pump();
        final marker = find.byKey(const ValueKey('zone-marquee-body'));
        if (marker.evaluate().isNotEmpty) widths.add(tester.getSize(marker).width);
      }
      expect(widths.toSet().length, greaterThan(10),
        reason: 'the marker follows pixels, not whole-day jumps');
      expect(find.byKey(const ValueKey('zone-marquee-body')), findsOneWidget);
      expect(find.byKey(const ValueKey('zone-paint-selection')), findsOneWidget);
      expect(find.byKey(const ValueKey('zone-phantom-3')), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('zone-marquee-body'))).width,
        greaterThan(column * 2));
      await g.up();
      await tester.pumpAndSettle();
      expect(
        repository.getAll().map((z) => z.weekday).toSet(),
        direction < 0 ? {1, 2, 3} : {3, 4, 5},
      );
      expect(
        repository.getAll().every(
          (z) => z.startMinutes == 240 && z.endMinutes == 360,
        ),
        isTrue,
      );
      expect(container.read(zoneEditSelectionProvider), contains(source.id));
    });
  }

  for (final sourceDay in [1, 7]) {
    testWidgets(
      'sideways body drag from $sourceDay moves without copying',
      (tester) async {
        final source =
            (await container
                    .read(zoneListProvider.notifier)
                    .paintWeeklyZones(
                      title: 'Commute',
                      weekdays: {sourceDay},
                      startMinutes: 240,
                      endMinutes: 300,
                    ))
                .single;
        await pump(tester);
        await tester.tapAt(point(tester, sourceDay, 270));
        await tester.pump();
        expect(container.read(zoneEditSelectionProvider), contains(source.id));
        final g = await tester.startGesture(point(tester, sourceDay, 270));
        await g.moveTo(point(tester, sourceDay == 1 ? 2 : 6, 270));
        await tester.pump();
        await g.moveTo(point(tester, 4, 270));
        await tester.pump();
        expect(find.byKey(const ValueKey('zone-phantom-4')), findsNothing);
        expect(
          tester.widget<ZoneGridBlock>(find.byType(ZoneGridBlock)).horizontalOffset,
          isNot(0),
        );
        await g.up();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 300));
        expect(repository.getAll(), hasLength(1));
        expect(repository.getAll().single.weekday, 4);
        expect(repository.getAll().single.id, source.id);
        expect(
          repository.getAll().every(
            (z) => z.startMinutes == 240 && z.endMinutes == 300,
          ),
          isTrue,
        );
        expect(find.byType(ZoneGridBlock), findsOneWidget);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(repository.getAll().single.weekday, sourceDay);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final horizontal in [false, true]) {
    testWidgets('selected zone group moves vertically and diagonal=$horizontal', (tester) async {
      final zones = await container.read(zoneListProvider.notifier).paintWeeklyZones(
        title: 'Work', weekdays: {2, 4}, startMinutes: 240, endMinutes: 360,
      );
      await pump(tester);
      for (final zone in zones) {
        container.read(zoneEditSelectionProvider.notifier).toggle(zone.id);
        await tester.pump();
      }
      final from = point(tester, 2, 300);
      final to = point(tester, horizontal ? 3 : 2, 360);
      final gesture = await tester.startGesture(from);
      for (var step = 1; step <= 20; step++) {
        await gesture.moveTo(Offset.lerp(from, to, step / 20)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      final moved = repository.getAll();
      expect(moved, hasLength(2));
      expect(moved.map((z) => z.id).toSet(), zones.map((z) => z.id).toSet());
      expect(moved.map((z) => z.weekday).toSet(), horizontal ? {3, 5} : {2, 4});
      expect(moved.every((z) => z.startMinutes == 300 && z.endMinutes == 420), isTrue);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.getAll().every((z) => z.startMinutes == 240), isTrue);
    });
  }


  for (final top in [true, false]) {
    testWidgets('selected zone handle resizes the group top=$top', (tester) async {
      final zones = await container.read(zoneListProvider.notifier).paintWeeklyZones(
        title: 'Work', weekdays: {2, 4}, startMinutes: 240, endMinutes: 360,
      );
      await pump(tester);
      for (final zone in zones) {
        container.read(zoneEditSelectionProvider.notifier).toggle(zone.id);
      }
      await tester.pump();
      final block = find.byWidgetPredicate((w) => w is ZoneGridBlock && w.zone.id == zones.first.id);
      final rect = tester.getRect(block);
      final from = Offset(rect.center.dx, top ? rect.top + 2 : rect.bottom - 2);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 45));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      final stored = repository.getAll();
      expect(stored.map((z) => z.weekday).toSet(), {2, 4});
      expect(stored.map((z) => top ? z.startMinutes : z.endMinutes).toSet(), hasLength(1));
      expect(stored.every((z) => top ? z.startMinutes > 240 && z.endMinutes == 360
        : z.startMinutes == 240 && z.endMinutes > 360), isTrue);
    });
  }

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
    testWidgets(
      'the Zones tab dock has no Edit toggle — editing is always on',
      (tester) async {
        await pump(tester);

        expect(find.byTooltip('Close zones'), findsOneWidget);
        expect(find.byTooltip('Edit zones'), findsNothing);
        expect(find.byTooltip('Finish editing'), findsNothing);
      },
    );

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
              (c.dy - rect.top).abs() < 1 && (c.dx - rect.center.dx).abs() < 1,
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
              (c.dx - rect.left).abs() < 1 && (c.dy - rect.center.dy).abs() < 1,
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
      expect(
        after.startMinutes,
        before.startMinutes,
        reason: 'the untouched edge must not move',
      );
      expect(after.endMinutes, greaterThan(before.endMinutes));
    });

    testWidgets('side resize tracks pixels across days in one held gesture', (
      tester,
    ) async {
      await paint(tester);
      final before = marquee(tester);
      final start = before.centerRight;
      final g = await tester.startGesture(start);
      await g.moveTo(start + const Offset(30, 0));
      await tester.pump();
      for (var i = 1; i <= 40; i++) {
        final pointer = start + Offset(30 + i * 3, 0);
        await g.moveTo(pointer);
        await tester.pump();
        final live = marquee(tester);
        expect(live.left, before.left);
        expect(live.top, before.top);
        expect(live.height, before.height);
        expect(live.right, closeTo(pointer.dx, 0.01));
      }
      await g.up();
      await tester.pump();
      expect(target(tester).weekdays.length, greaterThan(2));
    });

    testWidgets('dragging the RIGHT handle widens the weekday span', (
      tester,
    ) async {
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
      expect(
        after.weekdays.length,
        greaterThan(1),
        reason: 'dragging right must add days',
      );
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

  group('bottom dock does not overlap the naming sheet', () {
    testWidgets('task draft suppresses claimed Edit chrome immediately', (tester) async {
      await pumpWithShell(tester);
      expect(find.byType(AppDockIconButton), findsWidgets);
      container.read(pendingTaskDraftProvider.notifier).start(
        scheduledAt: DateTime(2026, 9, 27, 10),
        durationMinutes: quickAddDefaultMinutes,
      );
      await tester.pump();
      expect(find.byType(AppDockIconButton), findsNothing);
      container.read(pendingTaskDraftProvider.notifier).clear();
      await tester.pumpAndSettle();
      expect(find.byType(AppDockIconButton), findsWidgets);
    });

    // Uses the top-level `pumpWithShell` helper — see its own doc comment
    // for why the bare `pump` helper can't exercise this: in the real
    // app, `AppBottomDock` (`main.dart`) is a PERSISTENT shell overlay
    // painted AFTER (on top of) the routed content — including whatever
    // `ZoneGridScreen` renders, `NewZoneSheet` among it. Reported directly
    // ("still bottom toolbar overlaps") after an earlier fix tried to
    // reposition the sheet to clear the dock's own height — repositioning
    // could never work, since the dock always paints last regardless of
    // where the sheet sits. `pumpWithShell` reproduces that real paint
    // order so the fix — hiding the dock's own claimed actions while a
    // naming sheet is open — has real coverage.

    testWidgets(
      'the dock renders no action buttons while the naming sheet is open',
      (tester) async {
        await pumpWithShell(tester);

        final rect = tester.getRect(
          find.byKey(const ValueKey('zone-paint-surface')),
        );
        const axisWidth = 60.0;
        const pixelsPerMinute = 1.5;
        Offset point(int day, int minute) => Offset(
          rect.left + axisWidth + (day - .5) * (rect.width - axisWidth) / 7,
          rect.top + minute * pixelsPerMinute,
        );

        // Before opening the sheet: the dock's own Close action is a real
        // tap target.
        expect(find.byType(AppDockIconButton), findsWidgets);

        final gesture = await tester.startGesture(point(1, 180));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(point(1, 360));
        await tester.pump();
        await gesture.up();
        await tester.pump();
        expect(find.byType(AppDockIconButton), findsNothing,
          reason: 'sheet entrance must not wait for the dock exit animation');
        await tester.pumpAndSettle();

        expect(find.byType(NewZoneSheet), findsOneWidget);
        expect(
          find.byType(AppDockIconButton),
          findsNothing,
          reason:
              'the dock must render nothing while a naming sheet is open, '
              'since it is a persistent overlay that always paints on top '
              'of the sheet regardless of the sheet\'s own position',
        );
      },
    );

    testWidgets('the dock reappears once the naming sheet is dismissed', (
      tester,
    ) async {
      await pumpWithShell(tester);

      final rect = tester.getRect(
        find.byKey(const ValueKey('zone-paint-surface')),
      );
      const axisWidth = 60.0;
      const pixelsPerMinute = 1.5;
      Offset point(int day, int minute) => Offset(
        rect.left + axisWidth + (day - .5) * (rect.width - axisWidth) / 7,
        rect.top + minute * pixelsPerMinute,
      );

      final gesture = await tester.startGesture(point(1, 180));
      await tester.pump(const Duration(milliseconds: 550));
      await gesture.moveTo(point(1, 360));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(NewZoneSheet), findsOneWidget);
      expect(find.byType(AppDockIconButton), findsNothing);

      // Close via the sheet's own bottom-row close button.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(NewZoneSheet), findsNothing);
      expect(find.byType(AppDockIconButton), findsWidgets);
    });
  });

  for (final count in [2, 3]) {
    testWidgets('multi edit uses the current $count-zone shell selection', (tester) async {
      final zones = await container.read(zoneListProvider.notifier).paintWeeklyZones(
        title: 'Original', weekdays: {1, 2, 3, 4},
        startMinutes: 240, endMinutes: 360,
      );
      await pumpWithShell(tester);
      for (final zone in zones.take(count)) {
        container.read(zoneEditSelectionProvider.notifier).add(zone.id);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Edit placement'));
      await tester.pumpAndSettle();
      expect(find.text('$count zones selected'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('multiZoneEditNameField')), 'Updated');
      final save = find.widgetWithText(AppButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      for (final zone in zones.take(count)) {
        expect(repository.getById(zone.id)!.title, 'Updated');
      }
      for (final zone in zones.skip(count)) {
        expect(repository.getById(zone.id)!.title, 'Original');
      }
    });
  }

  group('bulk delete removes every selected zone', () {
    // Reported directly as a regression: "when multiselecting zones and
    // delete, it deletes 1 or 2 sometimes but not all at once selected."
    // No existing test covered the multi-select Remove action at all —
    // this reproduces the real UI path (select N zones via the grid's own
    // ZoneEditSelection provider, tap the dock's Remove action) rather
    // than calling `deleteZonesInBatch` directly, so it also catches a
    // bug in the UI-level wiring (a stale `selected`/`zones` closure
    // capture, a race with the dock's own claim/animation, etc.), not
    // just the repository-level batch method in isolation.
    testWidgets(
      'selecting 4 zones and tapping Remove deletes all 4, not a subset',
      (tester) async {
        await pumpWithShell(tester);

        final zones = await container
            .read(zoneListProvider.notifier)
            .paintWeeklyZones(
              title: 'Work',
              weekdays: {1, 2, 3, 4},
              startMinutes: 240,
              endMinutes: 360,
            );
        expect(zones, hasLength(4));
        await tester.pump();

        for (final zone in zones) {
          container.read(zoneEditSelectionProvider.notifier).toggle(zone.id);
          await tester.pumpAndSettle();
        }
        expect(container.read(zoneEditSelectionProvider), hasLength(4));
        // pumpAndSettle BEFORE the tap, not just after — the dock's own
        // Remove button enters via a staggered `Timer`-driven animation
        // (`AppContextDock`'s own `_scheduleEntrance`/`_revealEntry`) and
        // stays wrapped in `IgnorePointer(ignoring: ...entering)` the
        // whole time it's still entering. A tap fired before that timer
        // resolves is silently swallowed — confirmed directly: a single
        // `tester.pump()` here (instead of `pumpAndSettle`) reproduced the
        // reported bug exactly, deleting 0 zones instead of all 4.
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Remove placements'));
        await tester.pumpAndSettle();

        // NOT `repository.getAll(), isEmpty` — a weekly placement (every
        // zone `paintWeeklyZones` creates has a `weekday`, so
        // `isWeeklyPlacement` is true) is ARCHIVED by
        // `deleteZonesInBatch`, not actually removed from storage (see
        // that method's own doc comment: "preserves deleteZone's own
        // per-row branching — a weekly placement is archived, not really
        // deleted"). The real, user-visible signal is
        // `zone_grid_screen.dart`'s own render filter
        // (`.where((z) => z.isWeeklyPlacement && !z.archived)`), which is
        // what the grid actually shows — every selected zone must be
        // ARCHIVED, and none should still render as a live block.
        final stored = repository.getAll();
        expect(stored, hasLength(4), reason: 'archived rows still exist');
        expect(
          stored.every((z) => z.archived),
          isTrue,
          reason:
              'every one of the 4 selected zones should be archived, not '
              'just 1 or 2 of them',
        );
        expect(find.byType(ZoneGridBlock), findsNothing);
        expect(container.read(zoneEditSelectionProvider), isEmpty);
      },
    );

    testWidgets('selecting 8 zones and tapping Remove deletes all 8', (
      tester,
    ) async {
      await pumpWithShell(tester);

      final zones = await container
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: 'Deep work',
            weekdays: {1, 2, 3, 4, 5, 6, 7},
            startMinutes: 60,
            endMinutes: 120,
          );
      final second = await container
          .read(zoneListProvider.notifier)
          .paintWeeklyZones(
            title: 'Wind-down',
            weekdays: {1},
            startMinutes: 1200,
            endMinutes: 1260,
          );
      final all = [...zones, ...second];
      expect(all, hasLength(8));
      await tester.pump();

      for (final zone in all) {
        container.read(zoneEditSelectionProvider.notifier).toggle(zone.id);
          await tester.pumpAndSettle();
      }
      expect(container.read(zoneEditSelectionProvider), hasLength(8));
      // See the 4-zone test's own comment: pumpAndSettle BEFORE the tap so
      // the dock's Remove button has finished its own entrance animation
      // (`IgnorePointer` blocks the tap while `entering` is still true).
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove placements'));
      await tester.pumpAndSettle();

      // See the 4-zone test's own comment on why this checks `archived`
      // rather than repository emptiness.
      final stored = repository.getAll();
      expect(stored, hasLength(8));
      expect(stored.every((z) => z.archived), isTrue);
      expect(find.byType(ZoneGridBlock), findsNothing);
    });
  });
}

class _MemoryTasks implements TaskRepository {
  final _tasks = <String, Task>{};
  @override
  List<Task> getTasks() => _tasks.values.toList();
  @override
  Task? getTaskById(String id) => _tasks[id];
  @override
  Future<void> saveTask(Task task) async {
    _tasks[task.id] = task;
  }
  @override
  Future<void> deleteTask(String id) async {
    _tasks.remove(id);
  }
}
