import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/group_reschedule.dart';

void main() {
  Task task(String id, DateTime scheduledAt, int durationMinutes) => Task(
    id: id,
    title: id,
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.work,
    schemaVersion: 1,
  );

  test('an empty selection produces no moves', () {
    final moves = computeGroupMoves(selectedTasks: const [], deltaMinutes: 30);
    expect(moves, isEmpty);
  });

  test('a zero delta produces no moves', () {
    final moves = computeGroupMoves(
      selectedTasks: [task('a', DateTime(2026, 8, 20, 9), 30)],
      deltaMinutes: 0,
    );
    expect(moves, isEmpty);
  });

  test('applies the same delta to every selected task, each keeping its '
      'own duration', () {
    final moves = computeGroupMoves(
      selectedTasks: [
        task('a', DateTime(2026, 8, 20, 9), 30),
        task('b', DateTime(2026, 8, 20, 13), 60),
      ],
      deltaMinutes: 45,
    );

    expect(moves, hasLength(2));
    final byId = {for (final m in moves) m.taskId: m.newScheduledAt};
    expect(byId['a'], DateTime(2026, 8, 20, 9, 45));
    expect(byId['b'], DateTime(2026, 8, 20, 13, 45));
  });

  test('clamps a positive delta to the tightest member\'s own day-end '
      'boundary rather than rejecting the whole move', () {
    // b ends at 23:30 with 30min duration -> only 30 minutes of room to
    // move later before its own end crosses midnight.
    final moves = computeGroupMoves(
      selectedTasks: [
        task('a', DateTime(2026, 8, 20, 9), 30),
        task('b', DateTime(2026, 8, 20, 23), 30),
      ],
      deltaMinutes: 120,
    );

    final byId = {for (final m in moves) m.taskId: m.newScheduledAt};
    // Clamped to 30 minutes for both, not 120.
    expect(byId['a'], DateTime(2026, 8, 20, 9, 30));
    expect(byId['b'], DateTime(2026, 8, 20, 23, 30));
  });

  test('clamps a negative delta to the tightest member\'s own day-start '
      'boundary', () {
    // b starts at 00:15 -> only 15 minutes of room to move earlier
    // before its own start crosses midnight.
    final moves = computeGroupMoves(
      selectedTasks: [
        task('a', DateTime(2026, 8, 20, 9), 30),
        task('b', DateTime(2026, 8, 20, 0, 15), 30),
      ],
      deltaMinutes: -60,
    );

    final byId = {for (final m in moves) m.taskId: m.newScheduledAt};
    expect(byId['a'], DateTime(2026, 8, 20, 8, 45));
    expect(byId['b'], DateTime(2026, 8, 20, 0));
  });

  test('a member already at its own day boundary produces no moves for a '
      'delta pushing further past it', () {
    final moves = computeGroupMoves(
      selectedTasks: [task('a', DateTime(2026, 8, 20, 0), 30)],
      deltaMinutes: -15,
    );
    expect(moves, isEmpty);
  });

  test('each member clamps against its OWN day, not a shared one — two '
      'members on different days each get their own boundary check', () {
    final moves = computeGroupMoves(
      selectedTasks: [
        // Day 1: ends 23:45, only 15 min of room later.
        task('a', DateTime(2026, 8, 20, 23, 15), 30),
        // Day 2: ends 14:00, plenty of room later.
        task('b', DateTime(2026, 8, 21, 13, 30), 30),
      ],
      deltaMinutes: 60,
    );

    final byId = {for (final m in moves) m.taskId: m.newScheduledAt};
    // Clamped to 15 (the tighter of the two) for BOTH members, applying
    // one shared clamped delta — not each member independently allowed
    // its own max.
    expect(byId['a'], DateTime(2026, 8, 20, 23, 30));
    expect(byId['b'], DateTime(2026, 8, 21, 13, 45));
  });
}
