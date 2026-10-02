import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

import '../../support/timeline_harness.dart';

final _noon = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}();

/// Requested directly: "zoom in pinch should treat the whole canvas at
/// once; atm timeline zooms in and tasks follow." A task's pill must be at
/// its new place and height in the same frame as the scale change, not ease
/// there afterwards.
void main() {
  late TimelineHarness harness;

  setUp(() async {
    harness = await TimelineHarness.open('test_hive_pinch_canvas', now: _noon);
  });
  tearDown(() => harness.close());

  testWidgets('a pinch moves and resizes task pills in the same frame', (
    tester,
  ) async {
    await harness.pump(tester, [
      Task.create(
        title: 'Focus',
        scheduledAt: _noon.add(const Duration(minutes: 30)),
        durationMinutes: 60,
        categoryId: BuiltInCategoryIds.work,
      ),
    ]);
    // Settle the timeline's own opening motion first.
    await tester.pump(const Duration(seconds: 1));
    final rail = find
        .descendant(
          of: find.byType(TaskCapsuleBlock),
          matching: find.byType(AnimatedContainer),
        )
        .first;
    final before = tester.getRect(rail);

    // Two fingers in the hour gutter, spread apart: zoom in.
    final a = await tester.startGesture(const Offset(40, 360), pointer: 1);
    final b = await tester.startGesture(const Offset(40, 460), pointer: 2);
    await tester.pump();
    // Real I/O: the scale is saved to preferences as it changes.
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await a.moveBy(const Offset(0, -12));
        await b.moveBy(const Offset(0, 12));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    final firstFrame = tester.getRect(rail);
    await tester.pump(const Duration(milliseconds: 600));
    final settled = tester.getRect(rail);

    expect(firstFrame.height, greaterThan(before.height), reason: 'zoomed');
    expect(firstFrame, settled, reason: 'no easing after the scale changed');

    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 600));
  });
}
