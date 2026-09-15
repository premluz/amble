import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/zone.dart';

/// Covers the two-ring selection treatment requested directly: "the blue
/// selected border should be thinner and have inner dark bg color inner
/// border (hard inner glow/shadow of 1-2px), that makes the effect of
/// separation of blue 'active border' from the pill color in case pill
/// color is also blue — this is both for zones and tasks."
void main() {
  final theme = AmbleTheme.light;

  group('TaskCapsuleBlock selection', () {
    final task = Task.create(
      title: 'Deep work',
      scheduledAt: DateTime(2026, 9, 4, 9),
      durationMinutes: 90,
      categoryId: BuiltInCategoryIds.work,
    );

    Future<void> pump(WidgetTester tester, {required bool isSelected}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: TaskCapsuleBlock(task: task, isSelected: isSelected),
          ),
        ),
      );
    }

    testWidgets('unselected: no accent or separator ring exists — only '
        'unrelated borders elsewhere on the pill (if any) survive', (
      tester,
    ) async {
      await pump(tester, isSelected: false);

      final selectionColors = <Color>{
        for (final decoration
            in tester
                .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                .map((w) => w.decoration)
                .whereType<BoxDecoration>())
          if (decoration.border case Border(:final top))
            top.color,
      }..retainAll([theme.colorAccent, theme.colorScrim]);

      expect(
        selectionColors,
        isEmpty,
        reason: 'no selection ring should exist at all while unselected',
      );
    });

    // Real bug, caught after shipping: the first version always built the
    // selected-only wrapper (SizedBox.expand -> Padding -> DecoratedBox,
    // the innermost of which had a transparent `const BoxDecoration()`
    // when unselected) rather than skipping it, so an unselected pill
    // carried three empty extra layers around its own emoji for no
    // reason. Reported directly: "I think you added some 2 inner? one
    // transparent kind of?"
    testWidgets('unselected: the badge AnimatedContainer has no '
        'SizedBox.expand descendant at all — same shape as before this '
        'feature existed, not an empty wrapper left in the tree', (
      tester,
    ) async {
      await pump(tester, isSelected: false);

      final badge = find.byType(AnimatedContainer).first;
      expect(
        find.descendant(
          of: badge,
          matching: find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == double.infinity,
          ),
        ),
        findsNothing,
        reason:
            'the selected-only SizedBox.expand wrapper must not exist at '
            'all when unselected, not merely render an empty decoration',
      );
    });

    testWidgets('selected: the accent ring and the dark separator ring are '
        'two DIFFERENT colors, not the same ring drawn twice', (
      tester,
    ) async {
      await pump(tester, isSelected: true);

      final borderColors = <Color>{
        for (final decoration
            in tester
                .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                .map((w) => w.decoration)
                .whereType<BoxDecoration>())
          if (decoration.border case Border(:final top))
            top.color,
      };

      expect(
        borderColors,
        containsAll([theme.colorAccent, theme.colorScrim]),
        reason:
            'the accent ring and the dark separator ring must be '
            'independently visible colors, so selection stays legible '
            'even against a category color that happens to already be '
            'the same blue as the accent',
      );
    });

    testWidgets('selected: the accent ring is thinner than the old '
        'un-separated single-ring width (borderWidthHairline * 2)', (
      tester,
    ) async {
      await pump(tester, isSelected: true);

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
      for (final decoration in accentBorders) {
        final width = (decoration.border as Border).top.width;
        expect(
          width,
          lessThan(theme.borderWidthHairline * 2),
          reason: 'requested directly: "the blue selected border should '
              'be thinner"',
        );
      }
    });
  });

  group('ZoneGridBlock selection', () {
    final zone = Zone.create(
      title: 'Focus block',
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
    );

    Future<void> pump(WidgetTester tester, {required bool isSelected}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: SizedBox(
              width: 60,
              child: Stack(
                children: [
                  ZoneGridBlock(
                    theme: theme,
                    zone: zone,
                    top: 0,
                    height: 90,
                    isSelected: isSelected,
                    wiggleEnabled: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('unselected: no accent or separator ring', (tester) async {
      await pump(tester, isSelected: false);

      final selectionColors = <Color>{
        for (final decoration
            in tester
                .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                .map((w) => w.decoration)
                .whereType<BoxDecoration>())
          if (decoration.border case Border(:final top))
            top.color,
      }..retainAll([theme.colorAccent, theme.colorScrim]);

      expect(selectionColors, isEmpty);
    });

    testWidgets('selected: same two-ring treatment as the task pill — '
        'accent ring and dark separator ring both present', (tester) async {
      await pump(tester, isSelected: true);

      final borderColors = <Color>{
        for (final decoration
            in tester
                .widgetList<DecoratedBox>(find.byType(DecoratedBox))
                .map((w) => w.decoration)
                .whereType<BoxDecoration>())
          if (decoration.border case Border(:final top))
            top.color,
      };

      expect(borderColors, containsAll([theme.colorAccent, theme.colorScrim]));
    });

    // Real bug, reported directly: "apart from that solid 1px bg color
    // inner, which is correct, there is lighter one more inner which
    // should not be there (transparent or lighter gray)." The fill's own
    // corner curve was painted at the CALLER's original (larger) radius
    // while the scrim ring around it used a smaller, inset radius — the
    // mismatch let the fill's own corner peek out past the scrim ring's
    // stroke, reading as a third, lighter ring. Each nested layer's
    // radius must be strictly smaller than the layer enclosing it.
    testWidgets('selected: every nested ring/fill radius is strictly '
        'smaller than the one enclosing it — no mismatched corners', (
      tester,
    ) async {
      await pump(tester, isSelected: true);

      final radii = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.borderRadius)
          .whereType<BorderRadius>()
          .map((r) => r.topLeft.x)
          .toList();

      // Outermost (accent ring) -> innermost (fill): strictly decreasing,
      // never equal and never inverted.
      final sorted = [...radii]..sort((a, b) => b.compareTo(a));
      expect(
        radii,
        sorted,
        reason: 'each ring/fill must nest at a strictly smaller radius '
            'than its enclosing layer, or their corners will not be '
            'concentric',
      );
      expect(radii.toSet().length, radii.length, reason: 'no two layers '
          'should share the exact same radius — that is what let a fill '
          'corner peek out past its enclosing ring in the reported bug');
    });
  });
}
