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
  testWidgets(
    'edit mode supports immediate drag and pointer cancellation discards it',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Edit zones'));
      await tester.pump();
      final g = await tester.startGesture(point(tester, 5, 240));
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
    'gradual diagonal painting wins over vertical scroll in edit mode',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Edit zones'));
      await tester.pump();
      final start = point(tester, 1, 180), end = point(tester, 5, 360);
      final before = point(tester, 1, 0).dy;
      final g = await tester.startGesture(start);
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
        // Edit mode first — outside it the grid is vertically scrollable,
        // so a drag legitimately belongs to the scroll view.
        await tester.tap(find.byTooltip('Edit zones'));
        await tester.pumpAndSettle();
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
        await tester.tap(find.byTooltip('Edit zones'));
        await tester.pumpAndSettle();
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
}
