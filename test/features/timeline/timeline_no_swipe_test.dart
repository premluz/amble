import 'package:flutter_test/flutter_test.dart';
import 'package:amble/core/widgets/app_swipe_actions.dart';
import 'package:amble/features/timeline/task_capsule_block.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';

import '../../support/timeline_harness.dart';

final _noon = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 12);
}();

/// Requested directly: "disable slide left right task pill for options on
/// spatial view, only on zone view we'll have it."
void main() {
  late TimelineHarness harness;

  setUp(() async {
    harness = await TimelineHarness.open('test_hive_no_swipe', now: _noon);
  });
  tearDown(() => harness.close());

  testWidgets('task pills on the spatial Timeline have no swipe actions', (
    tester,
  ) async {
    await harness.pump(tester, [
      Task.create(
        title: 'Focus',
        scheduledAt: _noon,
        durationMinutes: 30,
        categoryId: BuiltInCategoryIds.work,
      ),
    ]);

    final swipe = tester.widget<AppSwipeActions>(
      find.descendant(
        of: find.byType(TaskCapsuleBlock),
        matching: find.byType(AppSwipeActions),
      ),
    );
    expect(swipe.startAction, isNull);
    expect(swipe.endAction, isNull);
  });
}
