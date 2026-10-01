import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/current_time_indicator.dart';
import 'package:amble/features/timeline/resize_handle.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

import '../../support/timeline_harness.dart';

final _noon = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}();

/// Requested directly: a resizing task should be "raised" — it keeps
/// growing through a neighbour instead of stopping at it, and it paints
/// above the current-time line.
void main() {
  late TimelineHarness harness;

  setUp(() async {
    harness = await TimelineHarness.open('test_hive_resize_raised', now: _noon);
  });
  tearDown(() => harness.close());

  Task makeTask(String title, int startMinute, int minutes) => Task.create(
    title: title,
    scheduledAt: _noon.add(Duration(minutes: startMinute)),
    durationMinutes: minutes,
    categoryId: BuiltInCategoryIds.work,
  );

  Finder pillFor(String title) => find.byWidgetPredicate(
    (w) => w is TaskCapsuleBlock && w.task.title == title,
  );
  // The rail — the only part sized by duration (see
  // resize_anchored_edge_test for why not the capsule root).
  Finder railFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(AnimatedContainer))
      .first;
  Finder bottomHandleFor(String title) => find
      .descendant(of: pillFor(title), matching: find.byType(ResizeHandle))
      .last;

  /// Arms "Focus" (just above "Standup") and starts a bottom-edge resize.
  Future<TestGesture> startResize(WidgetTester tester) async {
    await harness.pump(tester, [
      makeTask('Focus', 0, 30),
      makeTask('Standup', 35, 60),
    ]);
    await tester.longPress(find.text('Focus'));
    await tester.pump();
    return tester.startGesture(tester.getCenter(bottomHandleFor('Focus')));
  }

  Future<void> release(WidgetTester tester, TestGesture gesture) async {
    await tester.runAsync(() async {
      await gesture.up();
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the pill keeps growing through the task below it', (
    tester,
  ) async {
    final gesture = await startResize(tester);
    final before = tester.getRect(railFor('Focus')).height;
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getRect(railFor('Focus')).height,
      greaterThan(before + 30),
      reason:
          'the rail must follow the finger past the neighbour, not '
          'stop at the resting gap above it',
    );
    await release(tester, gesture);
  });

  testWidgets('a selected task following a group resize also grows through '
      'the task below it', (tester) async {
    await harness.pump(tester, [
      makeTask('Lead', 0, 30),
      makeTask('Follower', 60, 30),
      makeTask('Blocker', 95, 30),
    ], multiSelect: true);
    await tester.tap(find.text('Lead'));
    await tester.pump();
    await tester.tap(find.text('Follower'));
    await tester.pump();

    final before = tester.getRect(railFor('Follower')).height;
    final gesture = await tester.startGesture(
      tester.getCenter(bottomHandleFor('Lead')),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getRect(railFor('Follower')).height,
      greaterThan(before + 30),
    );
    await release(tester, gesture);
  });

  testWidgets('the task being resized paints above the now-line', (
    tester,
  ) async {
    List<Type> order() => tester
        .widgetList(
          find.byWidgetPredicate(
            (w) =>
                w is CurrentTimeIndicator ||
                (w is TaskCapsuleBlock && w.task.title == 'Focus'),
          ),
        )
        .map((w) => w.runtimeType)
        .toList();

    final gesture = await startResize(tester);
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    expect(order(), [CurrentTimeIndicator, TaskCapsuleBlock]);
    await release(tester, gesture);
  });
}
