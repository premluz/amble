import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_edge_time_label.dart';

/// The reusable "accent hairline + time pill on the right" visual —
/// promoted out of `place_task_line.dart`'s own placement line so it can
/// be reused by the pending draft pill and Edit Mode's wiggling selected
/// task. Requested directly: "we have that mechanism to show on the
/// right time in accent color bg, we use it for quick task add on long
/// press[;] we need to use it... when quick new add task is dropped and
/// wiggly showing start and end of task."
void main() {
  Future<void> pump(
    WidgetTester tester,
    TimeOfDay time, {
    bool showLine = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskEdgeTimeLabel(
            theme: AmbleTheme.light,
            time: time,
            showLine: showLine,
          ),
        ),
      ),
    );
  }

  testWidgets('renders the given time, formatted', (tester) async {
    await pump(tester, const TimeOfDay(hour: 9, minute: 30));

    expect(find.text('9:30 AM'), findsOneWidget);
  });

  testWidgets('the time pill uses the accent background color', (tester) async {
    await pump(tester, const TimeOfDay(hour: 14, minute: 0));

    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text('2:00 PM'), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AmbleTheme.light.colorAccent);
  });

  testWidgets('uses the shared compact task-time style', (tester) async {
    await pump(tester, const TimeOfDay(hour: 14, minute: 0));

    final text = tester.widget<Text>(find.text('2:00 PM'));
    expect(text.style?.fontSize, AmbleTheme.light.textTaskEdgeTime.fontSize);
    expect(
      text.style?.fontFamily,
      AmbleTheme.light.textTaskEdgeTime.fontFamily,
    );
  });

  testWidgets('the hairline also uses the accent color, matching the pill', (
    tester,
  ) async {
    await pump(tester, const TimeOfDay(hour: 8, minute: 0));

    // The hairline is the Expanded child's own Container — found by its
    // fixed hairline height rather than by content, since it has none.
    final containers = tester.widgetList<Container>(find.byType(Container));
    final hairline = containers.firstWhere(
      (c) => c.constraints?.maxHeight == AmbleTheme.light.borderWidthHairline,
    );
    expect(hairline.color, AmbleTheme.light.colorAccent);
  });

  testWidgets('purely visual — its own content sits inside an IgnorePointer', (
    tester,
  ) async {
    await pump(tester, const TimeOfDay(hour: 12, minute: 0));

    expect(
      find.descendant(
        of: find.byType(TaskEdgeTimeLabel),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
  });

  // Requested directly: "shouldn't have lines just the hour on bg" —
  // the pending draft pill and Edit Mode's wiggling task both need just
  // the accent time badge, no hairline, unlike the original long-press
  // placement line (which keeps `showLine`'s own default of true).
  group('showLine: false', () {
    testWidgets('renders no hairline Container at all', (tester) async {
      await pump(tester, const TimeOfDay(hour: 8, minute: 0), showLine: false);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasHairline = containers.any(
        (c) => c.constraints?.maxHeight == AmbleTheme.light.borderWidthHairline,
      );
      expect(
        hasHairline,
        isFalse,
        reason: 'no Container should carry the hairline\'s own fixed height',
      );
    });

    testWidgets('still renders the time, in the accent-coloured pill', (
      tester,
    ) async {
      await pump(tester, const TimeOfDay(hour: 8, minute: 0), showLine: false);

      expect(find.text('8:00 AM'), findsOneWidget);
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('8:00 AM'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AmbleTheme.light.colorAccent);
    });

    testWidgets('defaulting to true (unset) still shows the hairline — the '
        'placement line\'s own existing look is unchanged', (tester) async {
      await pump(tester, const TimeOfDay(hour: 8, minute: 0));

      final containers = tester.widgetList<Container>(find.byType(Container));
      final hasHairline = containers.any(
        (c) => c.constraints?.maxHeight == AmbleTheme.light.borderWidthHairline,
      );
      expect(hasHairline, isTrue);
    });
  });

  // Design-system consolidation (2026-09-19), requested directly: "hour
  // start end has blue bg on create/edit task (on create is on right, on
  // edit is on left) should be consistent on left." pillAlignment lets the
  // one full-width-hairline caller (the placement line) keep its box
  // stretched edge-to-edge while still moving the PILL itself to the left
  // — see docs/DESIGN_SYSTEM.md.
  group('pillAlignment', () {
    testWidgets('defaults to start (left) — the pill is the FIRST Row '
        'child, with the hairline after it', (tester) async {
      await pump(tester, const TimeOfDay(hour: 8, minute: 0));

      final row = tester.widget<Row>(find.byType(Row));
      // Row's own children list, in build order: pill, gap, hairline for
      // `start`; hairline, gap, pill for `end`. Identify the pill by its
      // Container ancestor carrying the accent-fill decoration, rather
      // than by position alone, so this assertion fails loudly if the
      // ordering assumption ever changes.
      final firstChild = row.children.first;
      expect(
        firstChild,
        isA<Container>().having(
          (c) => (c.decoration! as BoxDecoration).color,
          'decoration.color',
          AmbleTheme.light.colorAccent,
        ),
      );
    });

    testWidgets('pillAlignment: end puts the hairline first, pill last — '
        'the placement line\'s own explicit opt-in', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskEdgeTimeLabel(
              theme: AmbleTheme.light,
              time: const TimeOfDay(hour: 8, minute: 0),
              pillAlignment: TaskEdgeTimeLabelAlignment.end,
            ),
          ),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));
      final lastChild = row.children.last;
      expect(
        lastChild,
        isA<Container>().having(
          (c) => (c.decoration! as BoxDecoration).color,
          'decoration.color',
          AmbleTheme.light.colorAccent,
        ),
      );
    });
  });
}
