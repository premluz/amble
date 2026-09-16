import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

void main() {
  final task = Task.create(
    title: 'Deep work',
    scheduledAt: DateTime(2026, 9, 4, 9),
    durationMinutes: 90,
    categoryId: BuiltInCategoryIds.work,
  );

  Future<void> pump(
    WidgetTester tester, {
    required bool editModeEnabled,
    // Defaults true: most tests in this file are about the OTHER gating
    // conditions (Edit Mode, wired callbacks), so selection is assumed
    // already satisfied unless a test says otherwise. Corrected directly:
    // "edit mode tasks shows handles for resize without selecting, that's
    // another thing to change, should only show after tapping/selecting
    // task" — handles now also require `isSelected`, matching the
    // selection border's own existing gate.
    bool isSelected = true,
    GestureDragStartCallback? onResizeStart,
    GestureDragUpdateCallback? onResizeUpdate,
    GestureDragEndCallback? onResizeEnd,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: task,
            editModeEnabled: editModeEnabled,
            isSelected: isSelected,
            onResizeStart: onResizeStart,
            onResizeUpdate: onResizeUpdate,
            onResizeEnd: onResizeEnd,
          ),
        ),
      ),
    );
  }

  testWidgets('no handle renders outside Edit Mode, even with callbacks '
      'wired', (tester) async {
    await pump(
      tester,
      editModeEnabled: false,
      onResizeStart: (_) {},
      onResizeUpdate: (_) {},
      onResizeEnd: (_) {},
    );

    expect(find.byType(ResizeHandle), findsNothing);
  });

  testWidgets('no handle renders in Edit Mode if the caller wires no '
      'resize callbacks', (tester) async {
    await pump(tester, editModeEnabled: true);

    expect(find.byType(ResizeHandle), findsNothing);
  });

  testWidgets('the handle renders only when Edit Mode is on, a resize end '
      'callback is wired, AND the task is selected', (tester) async {
    await pump(
      tester,
      editModeEnabled: true,
      onResizeStart: (_) {},
      onResizeUpdate: (_) {},
      onResizeEnd: (_) {},
    );

    expect(find.byType(ResizeHandle), findsOneWidget);
  });

  // Requested directly: "edit mode tasks shows handles for resize without
  // selecting, that's another thing to change actually, should only show
  // after tapping/selecting task and we should have blue border, same
  // style, unified, reusable." Handles used to show for EVERY task the
  // instant Edit Mode turned on; they now require selection too, matching
  // the accent border's own existing `isSelected` gate exactly.
  testWidgets('no handle renders in Edit Mode with callbacks wired if the '
      'task is NOT selected', (tester) async {
    await pump(
      tester,
      editModeEnabled: true,
      isSelected: false,
      onResizeStart: (_) {},
      onResizeUpdate: (_) {},
      onResizeEnd: (_) {},
    );

    expect(find.byType(ResizeHandle), findsNothing);
  });

  testWidgets('dragging the handle reports start/update/end without ever '
      'firing the move-drag handlers', (tester) async {
    var resizeStarted = false;
    var resizeUpdated = false;
    var resizeEnded = false;
    var moveDragged = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
        home: Scaffold(
          body: TaskCapsuleBlock(
            task: task,
            editModeEnabled: true,
            isSelected: true,
            onDragStart: (_) => moveDragged = true,
            onResizeStart: (_) => resizeStarted = true,
            onResizeUpdate: (_) => resizeUpdated = true,
            onResizeEnd: (_) => resizeEnded = true,
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ResizeHandle), const Offset(0, 20));
    await tester.pump();

    expect(resizeStarted, isTrue);
    expect(resizeUpdated, isTrue);
    expect(resizeEnded, isTrue);
    expect(moveDragged, isFalse);
  });

  // Requested directly: "let's include resize up (so resize handle on
  // top) both in this scenario and edit mode — we already have that in
  // zone resize." The top handle is gated independently of the bottom
  // one, exactly as ZoneBackgroundBlock's own two handles already are.
  group('top-edge resize handle (2026-09-08)', () {
    testWidgets('wiring only the TOP callbacks renders exactly one handle, '
        'and only the top one responds', (tester) async {
      var topStarted = false;
      var topUpdated = false;
      var topEnded = false;
      var bottomEnded = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskCapsuleBlock(
              task: task,
              editModeEnabled: true,
              isSelected: true,
              onResizeTopStart: (_) => topStarted = true,
              onResizeTopUpdate: (_) => topUpdated = true,
              onResizeTopEnd: (_) => topEnded = true,
            ),
          ),
        ),
      );

      expect(find.byType(ResizeHandle), findsOneWidget);

      await tester.drag(find.byType(ResizeHandle), const Offset(0, 20));
      await tester.pump();

      expect(topStarted, isTrue);
      expect(topUpdated, isTrue);
      expect(topEnded, isTrue);
      expect(bottomEnded, isFalse);
    });

    testWidgets('wiring BOTH renders two handles, each driving only its own '
        'callbacks', (tester) async {
      var topEnded = false;
      var bottomEnded = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskCapsuleBlock(
              task: task,
              editModeEnabled: true,
              isSelected: true,
              onResizeStart: (_) {},
              onResizeUpdate: (_) {},
              onResizeEnd: (_) => bottomEnded = true,
              onResizeTopStart: (_) {},
              onResizeTopUpdate: (_) {},
              onResizeTopEnd: (_) => topEnded = true,
            ),
          ),
        ),
      );

      expect(find.byType(ResizeHandle), findsNWidgets(2));

      // The top handle renders first in the Stack, so `.first` is it.
      await tester.drag(find.byType(ResizeHandle).first, const Offset(0, 20));
      await tester.pump();
      expect(topEnded, isTrue);
      expect(bottomEnded, isFalse);

      await tester.drag(find.byType(ResizeHandle).last, const Offset(0, 20));
      await tester.pump();
      expect(bottomEnded, isTrue);
    });

    testWidgets('no top handle outside Edit Mode, even with its callbacks '
        'wired', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskCapsuleBlock(
              task: task,
              editModeEnabled: false,
              onResizeTopStart: (_) {},
              onResizeTopUpdate: (_) {},
              onResizeTopEnd: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ResizeHandle), findsNothing);
    });
  });

  // Reported repeatedly across several rounds ("still cut off", "1 dots
  // are positioned good but cut off"), and the hardest part of this to
  // fix: the pill's resize dots are painted just OUTSIDE its own edges,
  // but the frosted card wrapper around the whole row carries a
  // `ClipRRect` that cut them off.
  //
  // Two attempts to move the dots OUT of that subtree instead both broke
  // real drag behaviour and were reverted (see `TaskCapsuleBlock.build`'s
  // own comment). The fix is that the wrapper doesn't clip while RESTING,
  // because at rest it has no visible shape of its own — no fill, no
  // blur, no shadow, all scaled by the same `t`. It still clips once
  // lifted, where the frosted card IS visible and wants its corner.
  group('the frosted wrapper does not clip the resize dots at rest', () {
    testWidgets('resting: clipBehavior is Clip.none', (tester) async {
      await pump(
        tester,
        editModeEnabled: true,
        onResizeStart: (_) {},
        onResizeUpdate: (_) {},
        onResizeEnd: (_) {},
      );

      expect(
        tester
            .widgetList<ClipRRect>(find.byType(ClipRRect))
            .map((c) => c.clipBehavior),
        everyElement(Clip.none),
        reason: 'a clipping wrapper at rest is what cut the dots off',
      );
    });

    testWidgets('lifted: it clips again', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: TaskCapsuleBlock(
              task: task,
              editModeEnabled: true,
              isSelected: true,
              isLifted: true,
              onResizeStart: (_) {},
              onResizeUpdate: (_) {},
              onResizeEnd: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<ClipRRect>(find.byType(ClipRRect))
            .map((c) => c.clipBehavior),
        contains(Clip.antiAlias),
        reason: 'the frosted card is genuinely visible while lifted and '
            'needs its own corner clipped',
      );
    });

    testWidgets('the dots sit just outside the pill, not inside it', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, extensions: [AmbleTheme.light]),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TaskCapsuleBlock(
                task: task,
                splitLayout: true,
                editModeEnabled: true,
                isSelected: true,
                onResizeTopStart: (_) {},
                onResizeTopUpdate: (_) {},
                onResizeTopEnd: (_) {},
                onResizeStart: (_) {},
                onResizeUpdate: (_) {},
                onResizeEnd: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pill = tester.getRect(find.byType(TaskCapsuleBlock));
      // Scoped to each `ResizeHandle`'s OWN dot: a bare circle-shaped
      // predicate also matches an unrelated, zero-width collapsed
      // Container elsewhere in the pill.
      final dots = find
          .byType(ResizeHandle)
          .evaluate()
          .map(
            (handle) => tester.getRect(
              find.descendant(
                of: find.byWidget(handle.widget),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Container &&
                      (w.decoration as BoxDecoration?)?.shape ==
                          BoxShape.circle,
                ),
              ),
            ),
          )
          .toList();

      expect(dots, hasLength(2));
      // Each dot's own CENTRE lands on the pill's edge, so it straddles
      // that edge half in and half out — requested directly: "50% height
      // of dot move inside, top one move bottom, bottom one move top."
      // The point of this test is that the dot is not CLIPPED: its outer
      // half paints past the pill, which the frosted wrapper used to cut.
      expect(dots.first.center.dy, moreOrLessEquals(pill.top, epsilon: 0.5));
      expect(dots.last.center.dy, moreOrLessEquals(pill.bottom, epsilon: 0.5));
      // The outer half genuinely extends beyond the pill's own bounds.
      expect(dots.first.top, lessThan(pill.top));
      expect(dots.last.bottom, greaterThan(pill.bottom));
    });
  });
}
