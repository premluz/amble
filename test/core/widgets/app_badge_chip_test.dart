import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/core/widgets/app_badge_chip.dart';

/// Covers the systematized badge/chip requested directly: "systematize
/// badge (just displayed, selectable variant on off)... selected border
/// should be inner not outer, not to change the size." The bug this
/// guards against: the old `TemplateChip` toggled `Container.border`
/// between `null` and `Border.all(...)`, so selecting a chip grew its
/// total footprint by the border's own width on every edge.
void main() {
  final theme = AmbleTheme.light;

  Future<void> pump(
    WidgetTester tester, {
    bool? selected,
    VoidCallback? onTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: AppBadgeChip(
            theme: theme,
            leading: const SizedBox(width: 24, height: 24),
            label: 'Deep work',
            selected: selected,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets('selecting a chip does not change its own footprint at all', (
    tester,
  ) async {
    await pump(tester, selected: false, onTap: () {});
    final unselectedSize = tester.getSize(find.byType(AppBadgeChip));

    await pump(tester, selected: true, onTap: () {});
    final selectedSize = tester.getSize(find.byType(AppBadgeChip));

    expect(
      selectedSize,
      unselectedSize,
      reason:
          'requested directly: "selected border should be inner not '
          'outer, not to change the size" — toggling selected must not '
          'grow or shrink the chip',
    );
  });

  testWidgets('unselected: no accent-colored ring exists at all', (
    tester,
  ) async {
    await pump(tester, selected: false, onTap: () {});

    final accentBorders = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where(
          (d) => switch (d.border) {
            Border(:final top) => top.color == theme.colorAccent,
            _ => false,
          },
        );

    expect(accentBorders, isEmpty);
  });

  testWidgets('selected: an accent-colored ring exists', (tester) async {
    await pump(tester, selected: true, onTap: () {});

    final accentBorders = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where(
          (d) => switch (d.border) {
            Border(:final top) => top.color == theme.colorAccent,
            _ => false,
          },
        );

    expect(accentBorders, isNotEmpty);
  });

  testWidgets('the selection ring is painted as an overlay, not Padding — the '
      'leading widget keeps its own full, un-shrunk size while selected', (
    tester,
  ) async {
    await pump(tester, selected: true, onTap: () {});

    final leadingSize = tester.getSize(find.byType(SizedBox).first);
    expect(leadingSize, const Size(24, 24));
  });

  testWidgets('tapping fires onTap', (tester) async {
    var tapped = false;
    await pump(tester, selected: false, onTap: () => tapped = true);

    await tester.tap(find.byType(AppBadgeChip));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets(
    'the non-selectable variant (selected/onTap both null) renders no '
    'ring at all, even after an interior gesture probe',
    (tester) async {
      await pump(tester);

      final accentBorders = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where(
            (d) => switch (d.border) {
              Border(:final top) => top.color == theme.colorAccent,
              _ => false,
            },
          );

      expect(accentBorders, isEmpty);
      expect(find.byType(GestureDetector), findsNothing);
    },
  );

  testWidgets(
    'the non-selectable variant has the SAME footprint as the selectable '
    'variant at rest (unselected) — omitting selection entirely changes '
    'nothing about layout',
    (tester) async {
      await pump(tester);
      final plainSize = tester.getSize(find.byType(AppBadgeChip));

      await pump(tester, selected: false, onTap: () {});
      final unselectedSize = tester.getSize(find.byType(AppBadgeChip));

      expect(plainSize, unselectedSize);
    },
  );
}
