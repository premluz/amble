import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/edit_mode_wiggle.dart';
import 'package:amble/features/timeline/pending_task_pill.dart';
import 'package:amble/features/timeline/resize_handle.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    ValueChanged<double>? onMoveUpdate,
    VoidCallback? onMoveEnd,
    ValueChanged<double>? onResizeUpdate,
    VoidCallback? onResizeEnd,
    ValueChanged<double>? onResizeTopUpdate,
    VoidCallback? onResizeTopEnd,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: Stack(
            children: [
              PendingTaskPill(
                theme: AmbleTheme.light,
                top: 100,
                left: 56,
                columnOffset: 0,
                width: 40,
                textColumnLeft: 120,
                textColumnRight: 0,
                height: 80,
                onMoveStart: (_) {},
                onMoveUpdate: onMoveUpdate ?? (_) {},
                onMoveEnd: onMoveEnd ?? () {},
                onResizeStart: (_) {},
                onResizeUpdate: onResizeUpdate ?? (_) {},
                onResizeEnd: onResizeEnd ?? () {},
                onResizeTopStart: (_) {},
                onResizeTopUpdate: onResizeTopUpdate ?? (_) {},
                onResizeTopEnd: onResizeTopEnd ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('renders at the given top/left and height, spanning to the '
      'right edge to carry its title', (tester) async {
    await pump(tester);

    final topLeft = tester.getTopLeft(find.byType(PendingTaskPill));
    final size = tester.getSize(find.byType(PendingTaskPill));

    expect(topLeft, const Offset(56, 100));
    // `width` sizes the coloured RAIL, not the widget: since the pill
    // became a real task-shaped capsule (2026-09-08) it also carries a
    // title beside that rail, so the widget itself stretches to the right
    // edge exactly as TaskCapsuleBlock's own row does. Height is still
    // the block's own.
    expect(size.height, 80);
    expect(size.width, greaterThan(40));
  });

  testWidgets('wraps its body in EditModeWiggle, enabled', (tester) async {
    await pump(tester);

    final wiggle = tester.widget<EditModeWiggle>(find.byType(EditModeWiggle));
    expect(wiggle.enabled, isTrue);
  });

  testWidgets('carries BOTH a top and a bottom ResizeHandle', (tester) async {
    await pump(tester);

    // Requested directly: "let's include resize up (so resize handle on
    // top) both in this scenario and edit mode" — mirroring the zone
    // blocks' own two-handle shape.
    expect(find.byType(ResizeHandle), findsNWidgets(2));
  });

  testWidgets('dragging the body fires onMoveUpdate with the frame delta, '
      'and onMoveEnd on release', (tester) async {
    final updates = <double>[];
    var moveEnded = false;
    await pump(
      tester,
      onMoveUpdate: updates.add,
      onMoveEnd: () => moveEnded = true,
    );

    // The RAIL's centre, not the widget's. Since the pill gained a title
    // in the shared text column (2026-09-08) its box spans the full row
    // width, so the widget's centre now lands in the title area — which
    // is deliberately not grabbable (IgnorePointer), because the box
    // overlaps real tasks underneath and must not swallow their taps.
    final railCenter = Offset(
      56 + 40 / 2, // left + width / 2
      tester.getCenter(find.byType(PendingTaskPill)).dy,
    );
    final gesture = await tester.startGesture(railCenter);
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(updates, isNotEmpty);
    expect(updates.reduce((a, b) => a + b), closeTo(20, 0.5));
    expect(moveEnded, isTrue);
  });

  testWidgets('dragging the BOTTOM resize handle fires onResizeUpdate/'
      'onResizeEnd, not onMoveUpdate or the top handle\'s callbacks', (
    tester,
  ) async {
    final moveUpdates = <double>[];
    final resizeUpdates = <double>[];
    final topUpdates = <double>[];
    var resizeEnded = false;
    await pump(
      tester,
      onMoveUpdate: moveUpdates.add,
      onResizeUpdate: resizeUpdates.add,
      onResizeEnd: () => resizeEnded = true,
      onResizeTopUpdate: topUpdates.add,
    );

    // `.last` — the top handle renders first in the Stack, so the bottom
    // one is last.
    await tester.drag(find.byType(ResizeHandle).last, const Offset(0, 15));
    await tester.pump();

    expect(resizeUpdates, isNotEmpty);
    expect(resizeUpdates.reduce((a, b) => a + b), closeTo(15, 0.5));
    expect(resizeEnded, isTrue);
    expect(moveUpdates, isEmpty);
    expect(topUpdates, isEmpty);
  });

  testWidgets('dragging the TOP resize handle fires onResizeTopUpdate/'
      'onResizeTopEnd, not the bottom handle\'s callbacks', (tester) async {
    final moveUpdates = <double>[];
    final resizeUpdates = <double>[];
    final topUpdates = <double>[];
    var topEnded = false;
    await pump(
      tester,
      onMoveUpdate: moveUpdates.add,
      onResizeUpdate: resizeUpdates.add,
      onResizeTopUpdate: topUpdates.add,
      onResizeTopEnd: () => topEnded = true,
    );

    await tester.drag(find.byType(ResizeHandle).first, const Offset(0, 15));
    await tester.pump();

    expect(topUpdates, isNotEmpty);
    expect(topUpdates.reduce((a, b) => a + b), closeTo(15, 0.5));
    expect(topEnded, isTrue);
    expect(resizeUpdates, isEmpty);
    expect(moveUpdates, isEmpty);
  });

  // Requested directly: "the task name should also be aligned as other
  // text (grey) but not wiggly, as if it was normally a task (in edit
  // mode the selected tasks to edit, name not wiggle)."
  group('title placement (2026-09-08)', () {
    testWidgets('the title sits at the shared text column, measured the '
        'same way a real task measures its own', (tester) async {
      await pump(tester);

      final titleLeft = tester.getTopLeft(find.text('New task')).dx;
      // left: 56 and textColumnLeft: 120 in this file's own harness.
      //
      // The expected value is `left + textColumnLeft`, because
      // `textColumnLeft` is expressed relative to the block's own box
      // (which starts at `left`) — exactly as `_buildSplit` uses it for a
      // real task. The first version of this test asserted a bare `120`,
      // which the buggy `textColumnLeft - left` formula ALSO satisfied:
      // 56 + (120 - 56) = 120. Both formulas agreed at this one point, so
      // the test passed while the real screen showed the name a full
      // hour-gutter width left of every other name. Asserting the sum
      // separates them: the bug gives 120, the fix gives 176.
      expect(titleLeft, closeTo(56 + 120, 0.5));
    });

    testWidgets('the title is OUTSIDE the wiggling subtree — only the rail '
        'wiggles, exactly as a real task does', (tester) async {
      await pump(tester);

      // The property, stated structurally: no EditModeWiggle anywhere
      // between the title and the pill's own root. A title nested inside
      // one would rotate along with the rail.
      expect(
        find.ancestor(
          of: find.text('New task'),
          matching: find.byType(EditModeWiggle),
        ),
        findsNothing,
      );
      // ...while the rail's own wiggle is still present and enabled.
      expect(find.byType(EditModeWiggle), findsOneWidget);
    });
  });
}
