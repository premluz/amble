import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task_status.dart';
import 'package:amble/shared/services/overlap_checker.dart';

Task _task({
  required DateTime scheduledAt,
  required int durationMinutes,
  TaskStatus status = TaskStatus.pending,
}) {
  final task = Task.create(
    title: 'Task',
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.personal,
  );
  task.status = status;
  return task;
}

void main() {
  group('overlapsExistingTask', () {
    test('no overlap when times are far apart', () {
      final existing = [
        _task(scheduledAt: DateTime(2026, 8, 24, 9), durationMinutes: 30),
      ];

      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 11),
          durationMinutes: 30,
          existingTasks: existing,
        ),
        isFalse,
      );
    });

    test('exact overlap (identical slot) is detected', () {
      final existing = [
        _task(scheduledAt: DateTime(2026, 8, 24, 9), durationMinutes: 30),
      ];

      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 30,
          existingTasks: existing,
        ),
        isTrue,
      );
    });

    test('partial overlap is detected', () {
      final existing = [
        _task(scheduledAt: DateTime(2026, 8, 24, 9), durationMinutes: 30),
      ];

      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 9, 15),
          durationMinutes: 30,
          existingTasks: existing,
        ),
        isTrue,
      );
    });

    test('back-to-back tasks do not overlap — half-open interval', () {
      final existing = [
        _task(scheduledAt: DateTime(2026, 8, 24, 9), durationMinutes: 30),
      ];

      // Starts exactly when the existing task ends.
      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 9, 30),
          durationMinutes: 30,
          existingTasks: existing,
        ),
        isFalse,
      );

      // Ends exactly when the existing task starts.
      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 8, 30),
          durationMinutes: 30,
          existingTasks: existing,
        ),
        isFalse,
      );
    });

    test('excludes the task with excludeTaskId from comparison', () {
      final self = _task(
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 30,
      );

      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 30,
          existingTasks: [self],
          excludeTaskId: self.id,
        ),
        isFalse,
      );
    });

    test('completed tasks still block — they still occupy their slot', () {
      final existing = [
        _task(
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 30,
          status: TaskStatus.completed,
        ),
      ];

      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 9, 10),
          durationMinutes: 20,
          existingTasks: existing,
        ),
        isTrue,
      );
    });

    test('different days never overlap, even at the same time', () {
      final existing = [
        _task(scheduledAt: DateTime(2026, 8, 24, 9), durationMinutes: 30),
      ];

      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 25, 9),
          durationMinutes: 30,
          existingTasks: existing,
        ),
        isFalse,
      );
    });

    test('unscheduled (Inbox) tasks are never considered', () {
      final existing = [Task.captured(title: 'Someday')];

      expect(
        overlapsExistingTask(
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 30,
          existingTasks: existing,
        ),
        isFalse,
      );
    });
  });
}
