import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/task_overlap_layout.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';

Task _task(String title, int hour, int minute, int durationMinutes) {
  return Task.create(
    title: title,
    scheduledAt: DateTime(2026, 8, 21, hour, minute),
    durationMinutes: durationMinutes,
    category: TaskCategory.work,
  );
}

TaskLayoutSlot _slotFor(List<TaskLayoutSlot> slots, String title) =>
    slots.firstWhere((slot) => slot.task.title == title);

void main() {
  test('an empty day produces no slots', () {
    expect(layoutOverlappingTasks([]), isEmpty);
  });

  test('a single task takes the full width', () {
    final slots = layoutOverlappingTasks([_task('Alone', 9, 0, 60)]);

    expect(slots, hasLength(1));
    expect(slots.single.columnCount, 1);
    expect(slots.single.column, 0);
    expect(slots.single.widthFraction, 1.0);
    expect(slots.single.leftFraction, 0.0);
  });

  test('non-overlapping tasks each take the full width', () {
    final slots = layoutOverlappingTasks([
      _task('Morning', 9, 0, 60),
      _task('Afternoon', 14, 0, 60),
    ]);

    expect(slots, hasLength(2));
    for (final slot in slots) {
      expect(slot.columnCount, 1);
      expect(slot.widthFraction, 1.0);
    }
  });

  test('a task starting exactly when another ends does not overlap', () {
    final slots = layoutOverlappingTasks([
      _task('First', 9, 0, 60),
      _task('Second', 10, 0, 60),
    ]);

    expect(_slotFor(slots, 'First').columnCount, 1);
    expect(_slotFor(slots, 'Second').columnCount, 1);
  });

  test('two overlapping tasks split the width and sit in separate columns', () {
    final slots = layoutOverlappingTasks([
      _task('A', 9, 0, 60),
      _task('B', 9, 30, 60),
    ]);

    final a = _slotFor(slots, 'A');
    final b = _slotFor(slots, 'B');

    expect(a.columnCount, 2);
    expect(b.columnCount, 2);
    expect(a.widthFraction, 0.5);
    expect({a.column, b.column}, {0, 1});
    expect(a.leftFraction, 0.0);
    expect(b.leftFraction, 0.5);
  });

  test('three mutually overlapping tasks split into three columns', () {
    final slots = layoutOverlappingTasks([
      _task('A', 9, 0, 90),
      _task('B', 9, 15, 90),
      _task('C', 9, 30, 90),
    ]);

    expect(slots.map((s) => s.columnCount), everyElement(3));
    expect(slots.map((s) => s.column).toSet(), {0, 1, 2});
  });

  test('a column is reused once its previous occupant has finished, so a '
      'chained group needs fewer columns than it has tasks', () {
    // 9:00-10:00 and 10:00-11:00 do not overlap each other, so they can
    // share a column; 9:30-10:30 overlaps both and needs its own.
    final slots = layoutOverlappingTasks([
      _task('First', 9, 0, 60),
      _task('Middle', 9, 30, 60),
      _task('Last', 10, 0, 60),
    ]);

    expect(slots.map((s) => s.columnCount), everyElement(2));
    expect(_slotFor(slots, 'First').column, 0);
    expect(_slotFor(slots, 'Middle').column, 1);
    expect(_slotFor(slots, 'Last').column, 0);
  });

  test('separate overlap groups are sized independently', () {
    // A busy morning shouldn't narrow an uncontended afternoon task.
    final slots = layoutOverlappingTasks([
      _task('Busy A', 9, 0, 60),
      _task('Busy B', 9, 30, 60),
      _task('Quiet', 15, 0, 60),
    ]);

    expect(_slotFor(slots, 'Busy A').columnCount, 2);
    expect(_slotFor(slots, 'Busy B').columnCount, 2);
    expect(_slotFor(slots, 'Quiet').columnCount, 1);
  });

  test('input order does not affect the resulting layout', () {
    final ordered = layoutOverlappingTasks([
      _task('A', 9, 0, 60),
      _task('B', 9, 30, 60),
    ]);
    final reversed = layoutOverlappingTasks([
      _task('B', 9, 30, 60),
      _task('A', 9, 0, 60),
    ]);

    expect(_slotFor(reversed, 'A').column, _slotFor(ordered, 'A').column);
    expect(_slotFor(reversed, 'B').column, _slotFor(ordered, 'B').column);
  });

  test('a fully contained task still gets its own column', () {
    final slots = layoutOverlappingTasks([
      _task('Long', 9, 0, 120),
      _task('Short', 9, 30, 15),
    ]);

    expect(_slotFor(slots, 'Long').columnCount, 2);
    expect(_slotFor(slots, 'Short').columnCount, 2);
    expect(
      _slotFor(slots, 'Long').column,
      isNot(_slotFor(slots, 'Short').column),
    );
  });
}
