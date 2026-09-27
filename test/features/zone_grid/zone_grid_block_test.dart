import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_edge_time_label.dart';
import 'package:amble/features/zone_grid/zone_grid_block.dart';
import 'package:amble/shared/models/zone.dart';

/// Covers the corrected gutter alignment for `ZoneGridBlock`'s own live
/// start/end time labels — reported directly: "zones also blue time from
/// to on the left." The label must sit on the grid's own hour-axis
/// column (the SAME x every "HH:00" tick uses), not merely at this day
/// column's own left edge.
void main() {
  final theme = AmbleTheme.light;
  final zone = Zone(
    id: 'z',
    title: 'Focus block',
    startMinutes: 9 * 60,
    endMinutes: 10 * 60,
  );

  Future<void> pump(WidgetTester tester, {required double dayColumnLeft}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [theme]),
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: Stack(
              children: [
                Positioned(
                  left: dayColumnLeft,
                  width: 80,
                  top: 0,
                  bottom: 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ZoneGridBlock(
                        theme: theme,
                        zone: zone,
                        top: 0,
                        height: 90,
                        isSelected: true,
                        dayColumnLeft: dayColumnLeft,
                        liveStartMinutes: 9 * 60,
                        liveEndMinutes: 10 * 60,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'the live start label sits at the SAME absolute x regardless of which '
    'day column the block is in — the shared gutter x, not the column\'s '
    'own left edge',
    (tester) async {
      await pump(tester, dayColumnLeft: 60);
      final day1X = tester.getTopLeft(find.byType(TaskEdgeTimeLabel).first).dx;

      await pump(tester, dayColumnLeft: 60 + 80 * 5);
      final day6X = tester.getTopLeft(find.byType(TaskEdgeTimeLabel).first).dx;

      expect(
        day1X,
        moreOrLessEquals(day6X, epsilon: 0.5),
        reason:
            'a zone in a LATER day column must show its live time label '
            'at the exact same x as one in an earlier column — both are '
            'the same hour-axis gutter, not the day column\'s own edge',
      );
    },
  );

  testWidgets(
    'the live label sits well LEFT of the day column\'s own left edge — '
    'inside the gutter, not hugging the column',
    (tester) async {
      const dayColumnLeft = 200.0;
      await pump(tester, dayColumnLeft: dayColumnLeft);

      final labelX = tester.getTopLeft(find.byType(TaskEdgeTimeLabel).first).dx;

      expect(labelX, lessThan(dayColumnLeft - 50));
    },
  );

  // Body ownership persists when a drag changes direction; handles alone
  // invoke extension. One pan recognizer keeps both movement axes available.
  group('zone body gesture ownership', () {
    Future<void> pumpBlock(
      WidgetTester tester, {
      required VoidCallback onMoveStart,
      required ValueChanged<DragUpdateDetails> onMoveUpdate,
      required VoidCallback onMoveEnd,
      required VoidCallback onExtendStart,
      required ValueChanged<DragUpdateDetails> onExtendUpdate,
      required VoidCallback onExtendEnd,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: Stack(
                children: [
                  ZoneGridBlock(
                    theme: theme,
                    zone: zone,
                    top: 100,
                    height: 200,
                    isSelected: true,
                    dayColumnLeft: 100,
                    onTap: () {},
                    onMoveStart: (_) => onMoveStart(),
                    onMoveUpdate: onMoveUpdate,
                    onMoveEnd: (_) => onMoveEnd(),
                    onExtendStart: (_) => onExtendStart(),
                    onExtendUpdate: onExtendUpdate,
                    onExtendEnd: (_) => onExtendEnd(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'a horizontal body drag keeps moving during vertical drift '
      'without invoking side-handle extension',
      (tester) async {
        var moveStarts = 0;
        var moveUpdates = 0;
        var moveEnds = 0;
        var extendStarts = 0;
        var extendUpdates = 0;
        var extendEnds = 0;

        await pumpBlock(
          tester,
          onMoveStart: () => moveStarts++,
          onMoveUpdate: (_) => moveUpdates++,
          onMoveEnd: () => moveEnds++,
          onExtendStart: () => extendStarts++,
          onExtendUpdate: (_) => extendUpdates++,
          onExtendEnd: () => extendEnds++,
        );

        final gesture = await tester.startGesture(const Offset(140, 200));
        // Commits horizontal: the first movement is far larger on the x axis
        // than the y axis, which is what wins the arena for move.
        await gesture.moveBy(const Offset(30, 2));
        await tester.pump();
        expect(moveStarts, 1, reason: 'move should have started');
        expect(extendStarts, 0, reason: 'extend must not also start');

        // The finger now drifts mostly VERTICALLY for several frames — the
        // exact drift that used to let the vertical recognizer steal the
        // gesture mid-drag.
        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(2, 15));
          await tester.pump();
        }

        await gesture.up();
        await tester.pump();

        expect(
          extendStarts,
          0,
          reason: 'extend must never start once move has committed',
        );
        expect(
          extendUpdates,
          0,
          reason: 'extend must never update once move has committed',
        );
        expect(
          extendEnds,
          0,
          reason: 'extend must never end a gesture it never started',
        );
        expect(moveStarts, 1);
        expect(moveUpdates, greaterThan(0));
        expect(moveEnds, 1);
      },
    );

    testWidgets(
      'a vertical-committed drag keeps moving even once the finger drifts '
      'horizontally mid-gesture, instead of handing off to extend',
      (tester) async {
        var moveStarts = 0;
        var moveUpdates = 0;
        var moveEnds = 0;
        var extendStarts = 0;
        var extendUpdates = 0;
        var extendEnds = 0;

        await pumpBlock(
          tester,
          onMoveStart: () => moveStarts++,
          onMoveUpdate: (_) => moveUpdates++,
          onMoveEnd: () => moveEnds++,
          onExtendStart: () => extendStarts++,
          onExtendUpdate: (_) => extendUpdates++,
          onExtendEnd: () => extendEnds++,
        );

        final gesture = await tester.startGesture(const Offset(140, 200));
        await gesture.moveBy(const Offset(2, 30));
        await tester.pump();
        expect(moveStarts, 1, reason: 'move should have started');
        expect(extendStarts, 0, reason: 'extend must not also start');

        for (var i = 0; i < 5; i++) {
          await gesture.moveBy(const Offset(15, 2));
          await tester.pump();
        }

        await gesture.up();
        await tester.pump();

        expect(
          extendStarts,
          0,
          reason: 'extend must never start once move has committed',
        );
        expect(
          extendUpdates,
          0,
          reason: 'extend must never update once move has committed',
        );
        expect(
          extendEnds,
          0,
          reason: 'extend must never end a gesture it never started',
        );
        expect(moveStarts, 1);
        expect(moveUpdates, greaterThan(0));
        expect(moveEnds, 1);
      },
    );
  });

  // Exercise the real scroll competitor rather than a bare Stack.
  group('zone body drag beats the enclosing scrollable', () {
    Future<ScrollController> pumpInScrollable(
      WidgetTester tester, {
      required ValueChanged<DragUpdateDetails> onMoveUpdate,
      required ValueChanged<DragUpdateDetails> onExtendUpdate,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [theme]),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 500,
              child: SingleChildScrollView(
                controller: controller,
                child: SizedBox(
                  height: 2000,
                  child: Stack(
                    children: [
                      ZoneGridBlock(
                        theme: theme,
                        zone: zone,
                        top: 100,
                        height: 300,
                        isSelected: true,
                        dayColumnLeft: 0,
                        onTap: () {},
                        onMoveStart: (_) {},
                        onMoveUpdate: onMoveUpdate,
                        onMoveEnd: (_) {},
                        onExtendStart: (_) {},
                        onExtendUpdate: onExtendUpdate,
                        onExtendEnd: (_) {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets(
      'a sideways body drag with vertical drift moves and does not scroll',
      (tester) async {
        var extendUpdates = 0;
        var moveUpdates = 0;
        final controller = await pumpInScrollable(
          tester,
          onMoveUpdate: (_) => moveUpdates++,
          onExtendUpdate: (_) => extendUpdates++,
        );

        final gesture = await tester.startGesture(const Offset(200, 250));
        // Mostly horizontal, but with the real vertical drift a finger
        // sweeping across columns actually produces — the exact motion
        // that used to be captured by the scroll view.
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(8, 3));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump();

        expect(
          moveUpdates,
          greaterThan(0),
          reason: 'the sideways drag must reach the move callback',
        );
        expect(
          extendUpdates,
          0,
          reason: 'a sideways drag must not invoke side-handle extension',
        );
        expect(
          controller.offset,
          0,
          reason:
              'the grid must NOT scroll during a sideways body move — '
              'scrolling here is the reported bug',
        );
      },
    );

    testWidgets(
      'a decisively vertical drag still moves the zone — the eager '
      'body recognizer supports either direction',
      (tester) async {
        var extendUpdates = 0;
        var moveUpdates = 0;
        await pumpInScrollable(
          tester,
          onMoveUpdate: (_) => moveUpdates++,
          onExtendUpdate: (_) => extendUpdates++,
        );

        final gesture = await tester.startGesture(const Offset(200, 250));
        for (var i = 0; i < 20; i++) {
          await gesture.moveBy(const Offset(0, 8));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump();

        expect(
          moveUpdates,
          greaterThan(0),
          reason: 'a vertical drag on a selected zone must still move it',
        );
        expect(
          extendUpdates,
          0,
          reason: 'a vertical drag must not trigger the sideways extend',
        );
      },
    );
  });

}
