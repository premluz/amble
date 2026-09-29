import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/place_task_line.dart';

/// Mirrors the real timeline's own geometry closely enough to exercise the
/// gesture: a scrollable, a fixed-height day column, and the layer as the
/// FIRST child of that column's Stack (its documented contract).
const _pixelsPerMinute = 1.5;

class _HoldResult {
  final started = <DateTime>[];
  final durationDeltas = <int>[];
  int releasedCount = 0;
  int emptyTapCount = 0;
}

Future<_HoldResult> _pumpLayer(
  WidgetTester tester, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final result = _HoldResult();
  final controller = PlaceTaskLineController(null);
  addTearDown(controller.dispose);
  final dayHeight =
      rangeEnd.difference(rangeStart).inMinutes * _pixelsPerMinute;

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context).extension<AmbleTheme>()!;
          return Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                height: dayHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // First, exactly as TimelineScreen mounts it — the
                    // stacking order is part of the contract under test.
                    PlaceTaskLineLayer(
                      theme: theme,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      pixelsPerMinute: _pixelsPerMinute,
                      controller: controller,
                      onHoldStarted: result.started.add,
                      onDurationDeltaChanged: result.durationDeltas.add,
                      onHoldReleased: () => result.releasedCount++,
                      onEmptyTap: () => result.emptyTapCount++,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
  return result;
}

void main() {
  // 09:00 -> 17:00, so the column is 8h * 60 * 1.5 = 720px tall.
  final rangeStart = DateTime(2026, 8, 31, 9);
  final rangeEnd = DateTime(2026, 8, 31, 17);

  testWidgets('a short empty-space tap is observed without a tap recognizer', (
    tester,
  ) async {
    final result = await _pumpLayer(
      tester,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    await tester.tap(find.byType(PlaceTaskLineLayer));

    expect(result.emptyTapCount, 1);
    expect(result.started, isEmpty);
    expect(result.releasedCount, 0);
  });

  testWidgets(
    'a long press fires onHoldStarted with the pressed position, snapped '
    'to 5 minutes',
    (tester) async {
      final result = await _pumpLayer(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(PlaceTaskLineLayer), findsOneWidget);

      // 180px below the column's top == 120 minutes == 11:00.
      final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
      final pressPoint = columnTopLeft + const Offset(150, 180);

      // A bare pump() FIRST, before the timed one — matches Flutter's own
      // draggable_test.dart pattern for exercising LongPressDraggable.
      // Without it the delayed-drag recognizer's internal Timer can miss
      // this test's advance, and the drag never starts at all.
      final gesture = await tester.startGesture(pressPoint);
      await tester.pump();
      // Past kLongPressTimeout, so the hold is recognized.
      await tester.pump(const Duration(milliseconds: 600));

      expect(result.started.single, DateTime(2026, 8, 31, 11));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('dragging after the hold reports a snapped duration delta', (
    tester,
  ) async {
    final result = await _pumpLayer(
      tester,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
    final gesture = await tester.startGesture(
      columnTopLeft + const Offset(150, 180),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(result.started.single, DateTime(2026, 8, 31, 11));

    // +90px == +60 minutes, matching the resize snap.
    await gesture.moveBy(const Offset(0, 90));
    await tester.pump();

    expect(result.durationDeltas.last, 60);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('moving back up reports a negative duration delta', (
    tester,
  ) async {
    final result = await _pumpLayer(
      tester,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
    final gesture = await tester.startGesture(
      columnTopLeft + const Offset(150, 180),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();

    expect(result.durationDeltas.last, -20);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('releasing after a real hold fires onHoldReleased exactly once', (
    tester,
  ) async {
    final result = await _pumpLayer(
      tester,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );

    final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
    final gesture = await tester.startGesture(
      columnTopLeft + const Offset(150, 180),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, 90));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(result.releasedCount, 1);
  });

  testWidgets('a quick drag scrolls instead of starting a hold', (
    tester,
  ) async {
      final result = await _pumpLayer(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // No hold — an immediate drag, which is what an ordinary scroll is.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Nothing started, and no release ever fired.
      expect(result.started, isEmpty);
      expect(result.releasedCount, 0);
  });
}
