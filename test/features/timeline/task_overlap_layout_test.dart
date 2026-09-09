import 'package:flutter_test/flutter_test.dart';
import 'package:amble/features/timeline/task_overlap_layout.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/external_calendar_event.dart';
import 'package:amble/shared/models/task.dart';

Task _task(String title, int hour, int minute, int durationMinutes) {
  return Task.create(
    title: title,
    scheduledAt: DateTime(2026, 8, 21, hour, minute),
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.work,
  );
}

// `.task!` — this file only ever feeds real Task lists into
// layoutOverlappingTasks, so every returned slot is guaranteed to carry a
// non-null task.
TaskLayoutSlot _slotFor(List<TaskLayoutSlot> slots, String title) =>
    slots.firstWhere((slot) => slot.task!.title == title);

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

  // Reported directly: "the imported tasks should also stack in the same
  // way as native tasks... otherwise exactly the same, with different
  // styling" — layoutOverlappingTasks was generalized from `List<Task>` to
  // `List<ScheduledBlock>` so an ExternalCalendarEvent can share a lane
  // with real tasks instead of positioning independently with no overlap
  // awareness.
  group('mixing tasks and external events (2026-09-07)', () {
    ExternalCalendarEvent event(
      String title,
      int hour,
      int minute,
      int durationMinutes,
    ) {
      final start = DateTime(2026, 8, 21, hour, minute);
      return ExternalCalendarEvent(
        id: title,
        title: title,
        start: start,
        end: start.add(Duration(minutes: durationMinutes)),
        sourceCalendarId: 'cal-1',
      );
    }

    test('a task and an overlapping event split into two columns, exactly '
        'like two overlapping tasks would', () {
      final slots = layoutOverlappingTasks([
        _task('Standup', 9, 0, 60),
        event('Dentist', 9, 30, 60),
      ]);

      expect(slots, hasLength(2));
      final taskSlot = slots.firstWhere((s) => s.task?.title == 'Standup');
      final eventSlot = slots.firstWhere((s) => s.block.id == 'Dentist');
      expect(taskSlot.columnCount, 2);
      expect(eventSlot.columnCount, 2);
      expect(taskSlot.column, isNot(eventSlot.column));
    });

    test('a non-overlapping event takes the full width, same as a lone '
        'task', () {
      final slots = layoutOverlappingTasks([event('Solo', 14, 0, 30)]);

      expect(slots, hasLength(1));
      expect(slots.single.columnCount, 1);
      expect(slots.single.widthFraction, 1.0);
    });

    test('TaskLayoutSlot.task is null for an event slot, non-null for a '
        'task slot', () {
      final slots = layoutOverlappingTasks([
        _task('Standup', 9, 0, 30),
        event('Dentist', 10, 0, 30),
      ]);

      final taskSlot = slots.firstWhere((s) => s.task?.title == 'Standup');
      final eventSlot = slots.firstWhere((s) => s.block.id == 'Dentist');
      expect(taskSlot.task, isNotNull);
      expect(taskSlot.task!.title, 'Standup');
      expect(eventSlot.task, isNull);
      expect(eventSlot.block, isA<ExternalCalendarEvent>());
    });

    test('sorts a task and event together by start time, not by kind', () {
      final slots = layoutOverlappingTasks([
        _task('Later', 11, 0, 30),
        event('Earlier', 8, 0, 30),
      ]);

      // Neither overlaps, so both take the full width — this only checks
      // that construction with a mixed, out-of-order list doesn't throw
      // and produces one slot per block.
      expect(slots, hasLength(2));
      expect(slots.every((s) => s.columnCount == 1), isTrue);
    });
  });
}
