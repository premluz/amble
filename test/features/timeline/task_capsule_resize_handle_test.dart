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

  testWidgets('the handle renders only when BOTH Edit Mode is on AND a '
      'resize end callback is wired', (tester) async {
    await pump(
      tester,
      editModeEnabled: true,
      onResizeStart: (_) {},
      onResizeUpdate: (_) {},
      onResizeEnd: (_) {},
    );

    expect(find.byType(ResizeHandle), findsOneWidget);
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
}
