import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/features/zone_grid/zone_grid_screen.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
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
          home: const ZoneGridScreen(),
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
    return Offset(
      rect.left + axisWidth + (day - .5) * (rect.width - axisWidth) / 7,
      rect.top + minute * 44 / 60,
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
}
