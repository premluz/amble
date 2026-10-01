import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_status.dart';

import '../../support/timeline_harness.dart';

final _noon = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}();

/// Requested directly: "as long as they are in edit mode they are on top /
/// and resize when hits clash/overlap should also trigger that context
/// menu with options."
void main() {
  late TimelineHarness harness;

  setUp(() async {
    harness = await TimelineHarness.open(
      'test_hive_resize_overlap_menu',
      now: _noon,
    );
  });
  tearDown(() => harness.close());

  Task makeTask(String title, int startMinute, int minutes) => Task.create(
    title: title,
    scheduledAt: _noon.add(Duration(minutes: startMinute)),
    durationMinutes: minutes,
    categoryId: BuiltInCategoryIds.work,
  );

  Finder bottomHandleFor(String title) => find
      .descendant(
        of: find.byWidgetPredicate(
          (w) => w is TaskCapsuleBlock && w.task.title == title,
        ),
        matching: find.byType(ResizeHandle),
      )
      .last;

  DateTime endOf(Task task) =>
      task.scheduledAt!.add(Duration(minutes: task.durationMinutes!));

  /// Arms "Focus", stretches its end well into "Standup", and releases.
  Future<(Task, Task)> resizeIntoNeighbour(WidgetTester tester) async {
    final focus = makeTask('Focus', 0, 30);
    final standup = makeTask('Standup', 35, 60);
    await harness.pump(tester, [focus, standup]);
    await tester.longPress(find.text('Focus'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.drag(bottomHandleFor('Focus'), const Offset(0, 60));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
    return (focus, standup);
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.runAsync(() async {
      await tester.tap(find.text(label));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a resize onto another task asks Overlap / Push all / Trim', (
    tester,
  ) async {
    await resizeIntoNeighbour(tester);
    expect(find.text('Overlap'), findsOneWidget);
    expect(find.text('Push all'), findsOneWidget);
    expect(find.text('Trim'), findsOneWidget);
  });

  testWidgets('Push all moves the neighbour past the new end; the resized '
      'task keeps plain resize status', (tester) async {
    final (focus, standup) = await resizeIntoNeighbour(tester);
    await choose(tester, 'Push all');
    final savedFocus = harness.taskBox.get(focus.id)!;
    final savedStandup = harness.taskBox.get(standup.id)!;
    expect(savedFocus.durationMinutes, greaterThan(35));
    expect(savedFocus.status, TaskStatus.pending);
    expect(savedStandup.scheduledAt, endOf(savedFocus));
    expect(savedStandup.durationMinutes, 60);
  });

  testWidgets('Trim shortens the neighbour and keeps its end', (tester) async {
    final (focus, standup) = await resizeIntoNeighbour(tester);
    final standupEnd = endOf(standup);
    await choose(tester, 'Trim');
    final savedFocus = harness.taskBox.get(focus.id)!;
    final savedStandup = harness.taskBox.get(standup.id)!;
    expect(savedStandup.scheduledAt, endOf(savedFocus));
    expect(endOf(savedStandup), standupEnd);
  });

  testWidgets('Overlap keeps the resize and leaves the neighbour alone', (
    tester,
  ) async {
    final (focus, standup) = await resizeIntoNeighbour(tester);
    final standupStart = standup.scheduledAt;
    await choose(tester, 'Overlap');
    expect(harness.taskBox.get(focus.id)!.durationMinutes, greaterThan(35));
    expect(harness.taskBox.get(standup.id)!.scheduledAt, standupStart);
  });

  testWidgets('the pill holds its stretched size while the menu is open, '
      'and Overlap keeps it', (tester) async {
    await harness.pump(tester, [
      makeTask('Focus', 0, 30),
      makeTask('Standup', 35, 60),
    ]);
    await tester.longPress(find.text('Focus'));
    await tester.pump();
    final rail = find
        .descendant(
          of: find.byWidgetPredicate(
            (w) => w is TaskCapsuleBlock && w.task.title == 'Focus',
          ),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final resting = tester.getRect(rail).height;
    final gesture = await tester.startGesture(
      tester.getCenter(bottomHandleFor('Focus')),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    final stretched = tester.getRect(rail).height;
    expect(stretched, greaterThan(resting + 30));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Overlap'), findsOneWidget);
    // Snapping to the 5-minute grid may still move the end a few pixels.
    expect(tester.getRect(rail).height, closeTo(stretched, 8));

    await choose(tester, 'Overlap');
    expect(tester.getRect(rail).height, closeTo(stretched, 8));
  });

  testWidgets('a resize into free time asks nothing', (tester) async {
    await harness.pump(tester, [makeTask('Focus', 0, 30)]);
    await tester.longPress(find.text('Focus'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.drag(bottomHandleFor('Focus'), const Offset(0, 60));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Push all'), findsNothing);
    expect(
      harness.taskBox.get(harness.taskBox.keys.single)!.durationMinutes,
      greaterThan(30),
    );
  });

  testWidgets('the task being resized paints on top, even when another '
      'selected task was picked last', (tester) async {
    await harness.pump(tester, [
      makeTask('Focus', 0, 30),
      makeTask('Standup', 90, 30),
    ], multiSelect: true);
    await tester.tap(find.text('Focus'));
    await tester.pump();
    await tester.tap(find.text('Standup'));
    await tester.pump();

    String topmost() => tester
        .widgetList<TaskCapsuleBlock>(find.byType(TaskCapsuleBlock))
        .last
        .task
        .title;
    expect(topmost(), 'Standup');

    final gesture = await tester.startGesture(
      tester.getCenter(bottomHandleFor('Focus')),
    );
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(topmost(), 'Focus');
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
