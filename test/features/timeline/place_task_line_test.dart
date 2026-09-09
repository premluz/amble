import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/place_task_line.dart';

/// Mirrors the real timeline's own geometry closely enough to exercise the
/// gesture: a scrollable, a fixed-height day column, and the layer as the
/// FIRST child of that column's Stack (its documented contract).
const _pixelsPerMinute = 1.5;

class _PlacedResult {
  final placed = <DateTime>[];
  final tapped = <DateTime>[];
}

Future<_PlacedResult> _pumpLayer(
  WidgetTester tester, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  bool withOnTapAt = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final result = _PlacedResult();
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
                    // First and last, exactly as TimelineScreen mounts
                    // them — the split is part of the contract under test.
                    PlaceTaskLineLayer(
                      theme: theme,
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      pixelsPerMinute: _pixelsPerMinute,
                      controller: controller,
                      onPlaced: result.placed.add,
                      onTapAt: withOnTapAt ? result.tapped.add : null,
                    ),
                    PlaceTaskLineOverlay(
                      theme: theme,
                      rangeStart: rangeStart,
                      pixelsPerMinute: _pixelsPerMinute,
                      controller: controller,
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

  testWidgets('a long press shows the line at the pressed position', (
    tester,
  ) async {
    await _pumpLayer(tester, rangeStart: rangeStart, rangeEnd: rangeEnd);

    // Nothing until the hold completes.
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

    // The line's own time label is what proves both that it appeared AND
    // that it landed on the pressed position rather than the top of the
    // column (the reported bug).
    expect(find.text('11:00 AM'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('dragging after the hold moves the line and its time', (
    tester,
  ) async {
    await _pumpLayer(tester, rangeStart: rangeStart, rangeEnd: rangeEnd);

    final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
    final gesture = await tester.startGesture(
      columnTopLeft + const Offset(150, 180),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('11:00 AM'), findsOneWidget);

    // +90px == +60 minutes == 12:00.
    await gesture.moveBy(const Offset(0, 90));
    await tester.pump();

    expect(find.text('12:00 PM'), findsOneWidget);
    expect(find.text('11:00 AM'), findsNothing);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('releasing reports the dropped time, snapped to 5 minutes', (
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

    expect(result.placed.single, DateTime(2026, 8, 31, 12));
  });

  testWidgets('the line disappears once released', (tester) async {
    await _pumpLayer(tester, rangeStart: rangeStart, rangeEnd: rangeEnd);

    final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
    final gesture = await tester.startGesture(
      columnTopLeft + const Offset(150, 180),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('11:00 AM'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('11:00 AM'), findsNothing);
  });

  testWidgets('a quick drag scrolls instead of placing a line', (tester) async {
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

    // Nothing placed, and no line was ever shown.
    expect(result.placed, isEmpty);
  });

  // New tap-empty-space interaction, requested directly: "tap on an empty
  // space in timeline view... puts a wiggly gray default task and opens a
  // small sheet" — distinct from the existing long-press-and-drag flow
  // above, which stays unchanged.
  group('onTapAt (2026-09-07)', () {
    testWidgets('a plain tap fires onTapAt with the tapped time, snapped '
        'to 5 minutes', (tester) async {
      final result = await _pumpLayer(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        withOnTapAt: true,
      );

      final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
      // 180px below the column's top == 120 minutes == 11:00.
      await tester.tapAt(columnTopLeft + const Offset(150, 180));
      await tester.pumpAndSettle();

      expect(result.tapped.single, DateTime(2026, 8, 31, 11));
      expect(result.placed, isEmpty);
    });

    testWidgets('a plain tap never shows the placement line or fires '
        'onPlaced', (tester) async {
      final result = await _pumpLayer(
        tester,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        withOnTapAt: true,
      );

      final columnTopLeft = tester.getTopLeft(find.byType(PlaceTaskLineLayer));
      await tester.tapAt(columnTopLeft + const Offset(150, 180));
      await tester.pumpAndSettle();

      expect(find.text('11:00 AM'), findsNothing);
      expect(result.placed, isEmpty);
    });

    testWidgets(
      'a long press still shows the line and fires onPlaced, unaffected '
      'by onTapAt being wired up',
      (tester) async {
        final result = await _pumpLayer(
          tester,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          withOnTapAt: true,
        );

        final columnTopLeft = tester.getTopLeft(
          find.byType(PlaceTaskLineLayer),
        );
        final gesture = await tester.startGesture(
          columnTopLeft + const Offset(150, 180),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('11:00 AM'), findsOneWidget);

        await gesture.up();
        await tester.pumpAndSettle();

        expect(result.placed.single, DateTime(2026, 8, 31, 11));
        expect(result.tapped, isEmpty);
      },
    );
  });
}
