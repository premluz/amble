import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/day_strip.dart';
import 'package:amble/hive_registrar.g.dart';
import 'package:amble/shared/providers/preferences_providers.dart';
import 'package:amble/shared/repositories/hive_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';

/// Reported directly: "the adjacent pane with calendar still jumps a
/// little on timeline."
///
/// The "return to today" chevron used to be added to and removed from the
/// strip's Row outright (`if (_scrolledAwayFromToday) ...`), so scrolling
/// across today's date changed the Row's child COUNT and shifted the day
/// tiles sideways by the chevron's full width. Its slot is now always
/// present and only its opacity animates.
void main() {
  late Box<dynamic> preferencesBox;

  setUp(() async {
    Hive.init('./.dart_tool/test_hive_day_strip_stability');
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapters();
    }
    preferencesBox = await Hive.openBox<dynamic>(
      'test_prefs_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async => preferencesBox.close());

  Future<void> pumpStrip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(
            HivePreferencesRepository(preferencesBox),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                DayStrip(onCreatePressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the chevron is always in the layout, visible or not', (
    tester,
  ) async {
    await pumpStrip(tester);

    // The structural fix: the chevron is present in the tree regardless of
    // scroll position, so its width is reserved either way. Under the old
    // `if (_scrolledAwayFromToday)` this finder returned nothing whenever
    // today was in view, and the strip beside it occupied that space
    // instead — then gave it back the moment the user scrolled.
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

    // And its visibility is carried by opacity, not by presence.
    expect(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left_rounded),
        matching: find.byType(AnimatedOpacity),
      ),
      findsOneWidget,
    );
  });

  testWidgets('visibility and hit-testing stay in step with each other', (
    tester,
  ) async {
    await pumpStrip(tester);

    final opacity = tester
        .widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.byIcon(Icons.chevron_left_rounded),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        )
        .opacity;
    final ignoring = tester
        .widget<IgnorePointer>(
          find
              .ancestor(
                of: find.byIcon(Icons.chevron_left_rounded),
                matching: find.byType(IgnorePointer),
              )
              .first,
        )
        .ignoring;

    // Whichever state the strip happens to rest in, an invisible chevron
    // must never be tappable and a visible one must never be inert —
    // reserving the space must not leave a dead zone or a ghost target.
    expect(
      ignoring,
      equals(opacity == 0.0),
      reason: 'opacity $opacity but ignoring=$ignoring',
    );
  });
}
