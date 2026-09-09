import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_boundary_markers.dart';

void main() {
  test('starts at the next whole hour at or after rangeStart', () {
    final ticks = hourlyGridTimes(
      DateTime(2026, 8, 21, 6, 47),
      DateTime(2026, 8, 21, 9, 0),
    );

    final times = ticks.map((t) => t.time).toList();
    expect(times, [
      DateTime(2026, 8, 21, 7, 0),
      DateTime(2026, 8, 21, 8, 0),
      DateTime(2026, 8, 21, 9, 0),
    ]);
  });

  test(
    'a rangeStart already on a whole hour is included as the first tick',
    () {
      final ticks = hourlyGridTimes(
        DateTime(2026, 8, 21, 11, 0),
        DateTime(2026, 8, 21, 13, 0),
      );

      final times = ticks.map((t) => t.time).toList();
      expect(times, [
        DateTime(2026, 8, 21, 11, 0),
        DateTime(2026, 8, 21, 12, 0),
        DateTime(2026, 8, 21, 13, 0),
      ]);
    },
  );

  test('the last tick is at or before rangeEnd, never after', () {
    final ticks = hourlyGridTimes(
      DateTime(2026, 8, 21, 6, 0),
      DateTime(2026, 8, 21, 8, 59),
    );

    final times = ticks.map((t) => t.time).toList();
    expect(times, [
      DateTime(2026, 8, 21, 6, 0),
      DateTime(2026, 8, 21, 7, 0),
      DateTime(2026, 8, 21, 8, 0),
    ]);
  });

  test(
    'a range shorter than one hour with no whole hour inside produces no ticks',
    () {
      final ticks = hourlyGridTimes(
        DateTime(2026, 8, 21, 6, 10),
        DateTime(2026, 8, 21, 6, 40),
      );

      expect(ticks, isEmpty);
    },
  );

  test(
    'intervalHours spaces ticks further apart, still anchored to whole hours',
    () {
      final ticks = hourlyGridTimes(
        DateTime(2026, 8, 21, 6, 0),
        DateTime(2026, 8, 21, 12, 0),
        intervalHours: 2,
      );

      final times = ticks.map((t) => t.time).toList();
      expect(times, [
        DateTime(2026, 8, 21, 6, 0),
        DateTime(2026, 8, 21, 8, 0),
        DateTime(2026, 8, 21, 10, 0),
        DateTime(2026, 8, 21, 12, 0),
      ]);
    },
  );

  test('a range crossing midnight into the next day still ticks correctly', () {
    final ticks = hourlyGridTimes(
      DateTime(2026, 8, 21, 23, 30),
      DateTime(2026, 8, 22, 1, 30),
    );

    final times = ticks.map((t) => t.time).toList();
    expect(times, [DateTime(2026, 8, 22, 0, 0), DateTime(2026, 8, 22, 1, 0)]);
  });

  // Widget-level coverage, not just the pure hourlyGridTimes math above.
  // Reported directly, TWICE: a first fix (extra bottom padding on the
  // scroll view around this widget) didn't actually solve it, because
  // the real clip boundary was this widget's OWN inner Stack, one layer
  // further in — the padding fix only grew the SCROLL viewport's room,
  // it couldn't undo a hard clip happening inside this widget itself.
  // "00:00 hours on top and bottom are cut off."
  testWidgets(
    'the 00:00 label at the very first tick is NOT clipped, even when '
    'this widget sits in a tightly-sized box with no surrounding slack',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Center(
              // Deliberately tight — no extra room above/below, so a
              // half-label overflow can only survive via Clip.none on
              // the widget's OWN Stack, not via outer padding.
              child: SizedBox(
                width: 200,
                height: 60,
                child: TaskBoundaryMarkers(
                  rangeStart: DateTime(2026, 9, 8, 0, 0),
                  rangeEnd: DateTime(2026, 9, 8, 1, 0),
                  pixelsPerMinute: 1.0,
                ),
              ),
            ),
          ),
        ),
      );

      // Not matching literal "00:00" text — the test harness's default
      // locale may format midnight as "12:00 AM" instead, which isn't
      // what this test is about. The actual property under test is
      // structural: the Stack this widget builds must be Clip.none, so a
      // label positioned above its own top edge (see the
      // FractionalTranslation in the widget's own build) isn't silently
      // dropped from the render — that's what "cut off" looked like.
      final markerStack = tester.widget<Stack>(
        find.descendant(
          of: find.byType(TaskBoundaryMarkers),
          matching: find.byType(Stack),
        ),
      );
      expect(markerStack.clipBehavior, Clip.none);

      // And the label genuinely rendered with real geometry, not just
      // present with a zero-size layout.
      final labels = find.descendant(
        of: find.byType(TaskBoundaryMarkers),
        matching: find.byType(Text),
      );
      expect(labels, findsWidgets);
      for (final element in labels.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThan(0));
        expect(size.width, greaterThan(0));
      }
    },
  );
}
