import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/pending_task_draft_provider.dart';
import 'package:amble/features/timeline/task_overlap_layout.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/scheduled_block.dart';
import 'package:amble/shared/models/task.dart';

/// The quick-add placeholder participates in the SAME lane/cluster layout
/// real tasks and imported events do — 2026-09-08, reversing its original
/// "positioned absolutely over everything, invisible to the layout"
/// treatment after that was questioned directly.
///
/// Tested at the layout level rather than through a rendered Timeline:
/// this is where the behaviour actually lives, and a widget-level check
/// can pass or fail for unrelated reasons (a pill missing entirely reads
/// the same as a pill in the wrong lane).
void main() {
  Task taskAt({required int hour, required int durationMinutes}) => Task.create(
    title: 'Task $hour',
    scheduledAt: DateTime(2026, 9, 8, hour),
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.general,
  );

  PendingTaskDraft draftAt({
    required int hour,
    int durationMinutes = quickAddDefaultMinutes,
  }) => PendingTaskDraft(
    id: 'draft-1',
    scheduledAt: DateTime(2026, 9, 8, hour),
    durationMinutes: durationMinutes,
  );

  test('a draft is a ScheduledBlock, so the shared layout accepts it at '
      'all', () {
    expect(draftAt(hour: 9), isA<ScheduledBlock>());
  });

  test('its scheduledEnd derives from start + duration', () {
    final draft = draftAt(hour: 9, durationMinutes: 15);
    expect(draft.scheduledStart, DateTime(2026, 9, 8, 9));
    expect(draft.scheduledEnd, DateTime(2026, 9, 8, 9, 15));
  });

  test('a draft overlapping a task is given its OWN lane, not lane 0 on '
      'top of it', () {
    final task = taskAt(hour: 9, durationMinutes: 60);
    final draft = draftAt(hour: 9);

    final slots = layoutOverlappingTasks(<ScheduledBlock>[task, draft]);
    final taskSlot = slots.firstWhere((s) => s.block.id == task.id);
    final draftSlot = slots.firstWhere((s) => s.block.id == draft.id);

    // The actual property: they do not share a column.
    expect(draftSlot.column, isNot(taskSlot.column));
    // And both know the group is two deep, so each is sized for it.
    expect(taskSlot.columnCount, 2);
    expect(draftSlot.columnCount, 2);
  });

  test('a draft that overlaps nothing stays in lane 0, full width', () {
    final task = taskAt(hour: 9, durationMinutes: 60);
    // Well clear of the task.
    final draft = draftAt(hour: 14);

    final slots = layoutOverlappingTasks(<ScheduledBlock>[task, draft]);
    final draftSlot = slots.firstWhere((s) => s.block.id == draft.id);

    expect(draftSlot.column, 0);
    expect(draftSlot.columnCount, 1);
  });

  test('a draft overlapping TWO tasks joins a three-deep group', () {
    final a = taskAt(hour: 9, durationMinutes: 120);
    final b = taskAt(hour: 10, durationMinutes: 120);
    final draft = draftAt(hour: 10, durationMinutes: 30);

    final slots = layoutOverlappingTasks(<ScheduledBlock>[a, b, draft]);
    final draftSlot = slots.firstWhere((s) => s.block.id == draft.id);

    expect(draftSlot.columnCount, 3);
    // Every block in the group holds a distinct lane.
    final columns = slots.map((s) => s.column).toSet();
    expect(columns.length, 3);
  });
}
