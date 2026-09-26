import 'package:amble/core/tokens/semantic_theme.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/features/timeline/task_manipulation_targets.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _task = Task.create(
  title: 'Short task',
  scheduledAt: DateTime(2026, 9, 26, 9),
  durationMinutes: 60,
  categoryId: BuiltInCategoryIds.work,
);

Widget _harness({
  required double pillHeight,
  required void Function(String) record,
  VoidCallback? onBackgroundTap,
  VoidCallback? onStartResizeCancel,
  bool isSelected = true,
}) {
  final bottomTrim = pillHeight < 24 ? 24 - pillHeight : 0.0;
  return MaterialApp(
    theme: ThemeData(extensions: [AmbleTheme.light]),
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBackgroundTap,
            ),
          ),
          Positioned(
            left: 40,
            top: 80,
            width: 144,
            child: TaskCapsuleBlock(
              task: _task,
              pixelsPerMinute: 1,
              durationMinutesOverride: pillHeight < 24 ? 24 : pillHeight,
              bottomTrim: bottomTrim,
              showCompletionCheckbox: false,
              splitLayout: true,
              editModeEnabled: true,
              isSelected: isSelected,
              onTap: () => record('task tap'),
              onDragStart: (_) => record('move'),
              onDragUpdate: (_) {},
              onDragEnd: (_) {},
              onResizeTopStart: (_) => record('start'),
              onResizeTopUpdate: (_) {},
              onResizeTopEnd: (_) {},
              onResizeTopCancel: onStartResizeCancel,
              onResizeStart: (_) => record('end'),
              onResizeUpdate: (_) {},
              onResizeEnd: (_) {},
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _dragCell(WidgetTester tester, Offset down) async {
  final gesture = await tester.startGesture(down);
  await tester.pump();
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  for (final height in [4.0, 16.0, 24.0, 48.0, 72.0, 139.0, 200.0]) {
    testWidgets('edge resize and side move targets work at $height px', (
      tester,
    ) async {
      final operations = <String>[];
      var backgroundTaps = 0;
      await tester.pumpWidget(
        _harness(
          pillHeight: height,
          record: operations.add,
          onBackgroundTap: () => backgroundTaps++,
        ),
      );

      final target = find.byType(TaskManipulationTargets);
      final rect = tester.getRect(target);
      expect(rect.width, 48);
      expect(rect.height, height);
      expect(find.text('Start'), findsNothing);
      expect(find.text('End'), findsNothing);
      if (height >= 16) {
        final handles = find.byType(ResizeHandle);
        final dots = find.descendant(
          of: handles,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        );
        expect(dots, findsNWidgets(2));
        final visual = tester.getRect(
          find
              .descendant(
                of: find.byType(TaskCapsuleBlock),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        expect(tester.getCenter(dots.first), visual.topCenter + Offset(0, AmbleTheme.light.borderWidthHairline / 2));
        expect(tester.getCenter(dots.last), visual.bottomCenter - Offset(0, AmbleTheme.light.borderWidthHairline / 2));
      }

      await _dragCell(tester, rect.topLeft + Offset(36, height / 2));
      await _dragCell(tester, rect.topLeft + const Offset(12, 1));
      await _dragCell(tester, rect.topLeft + Offset(12, height - 1));

      expect(operations, ['move', 'start', 'end']);
      expect(backgroundTaps, 0);
    });
  }

  testWidgets('a tap on a edge handle is consumed without a task tap', (
    tester,
  ) async {
    final operations = <String>[];
    var backgroundTaps = 0;
    await tester.pumpWidget(
      _harness(
        pillHeight: 16,
        record: operations.add,
        onBackgroundTap: () => backgroundTaps++,
      ),
    );
    final rect = tester.getRect(find.byType(TaskManipulationTargets));
    await tester.tapAt(rect.topLeft + const Offset(12, 1));
    await tester.pump();
    expect(operations, isEmpty);
    expect(backgroundTaps, 0);
  });

  testWidgets('selecting the edge controls does not shift the visual pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(pillHeight: 16, record: (_) {}, isSelected: false),
    );
    final visual = find
        .descendant(
          of: find.byType(TaskCapsuleBlock),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final before = tester.getRect(visual);

    await tester.pumpWidget(_harness(pillHeight: 16, record: (_) {}));
    final after = tester.getRect(visual);
    expect(after.topLeft, before.topLeft);
    expect(after.size, before.size);
  });

  testWidgets('a cancelled edge resize reports cancel without committing', (
    tester,
  ) async {
    final operations = <String>[];
    await tester.pumpWidget(
      _harness(
        pillHeight: 16,
        record: operations.add,
        onStartResizeCancel: () => operations.add('cancel'),
      ),
    );

    final rect = tester.getRect(find.byType(TaskManipulationTargets));
    final gesture = await tester.startGesture(
      rect.topLeft + const Offset(12, 1),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 5));
    await tester.pump();
    await gesture.cancel();
    await tester.pump();

    expect(operations, ['start', 'cancel']);
  });
}
