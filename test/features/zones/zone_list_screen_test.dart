import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/zones/zone_list_screen.dart';
import 'package:amble/shared/models/zone.dart';
import 'package:amble/shared/models/zone_facet.dart';
import 'package:amble/shared/providers/zone_facet_providers.dart';
import 'package:amble/shared/providers/zone_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_zone_repositories.dart';

/// Requested directly: "zones tempaltes tags can be slided left to be
/// removed (we have that pattern on tasks and notes in inbox)." Zones'
/// tap-opens-edit and no-chevron/no-menu shape were already correct
/// before this — only the swipe-to-remove itself is new, added to
/// [ZoneListBody] via the shared [AppSwipeActions] pattern.
void main() {
  Future<ProviderContainer> pumpList(
    WidgetTester tester, {
    List<ZoneFacet> facets = const [],
    List<Zone> zones = const [],
  }) async {
    final facetRepository = MemoryZoneFacetRepository();
    for (final facet in facets) {
      await facetRepository.save(facet);
    }
    final zoneRepository = MemoryZoneRepository();
    for (final zone in zones) {
      await zoneRepository.save(zone);
    }

    final container = ProviderContainer(
      overrides: [
        zoneFacetRepositoryProvider.overrideWithValue(facetRepository),
        zoneRepositoryProvider.overrideWithValue(zoneRepository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: const Scaffold(body: ZoneListBody()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'swiping a zone name left past the threshold removes it when unused',
    (tester) async {
      await pumpList(
        tester,
        facets: [ZoneFacet(id: 'z1', name: 'Focus')],
      );
      expect(find.text('Focus'), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Focus')),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Focus'), findsNothing);
      expect(find.text('No zone names yet'), findsOneWidget);
    },
  );

  testWidgets(
    'swiping a zone name in use by a saved zone shows an error toast and '
    'leaves the row in place',
    (tester) async {
      // Requested directly, confirmed via AskUserQuestion: the swipe still
      // attempts the remove — `deleteUnusedFacet` throws `StateError`
      // ("This name is used by saved zones. Rename it instead.") when a
      // saved zone still references the facet, and this shows that
      // message as a plain informational toast (no undo action) rather
      // than silently doing nothing or blocking the swipe pre-emptively.
      await pumpList(
        tester,
        facets: [ZoneFacet(id: 'z1', name: 'Focus')],
        zones: [
          Zone(
            id: 'zone1',
            title: 'Focus',
            facetId: 'z1',
            startMinutes: 540,
            endMinutes: 600,
          ),
        ],
      );
      expect(find.text('Focus'), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Focus')),
      );
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Focus'), findsOneWidget);
      expect(
        find.textContaining('This name is used by saved zones'),
        findsOneWidget,
      );

      // The toast's own auto-dismiss is a real platform Timer — pumping
      // past its full default duration lets it fire before the test
      // returns, matching zone_form_screen_test.dart's own established
      // fix for the same AppUndoToast teardown assertion.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    },
  );
}
