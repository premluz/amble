import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/category.dart';
import 'package:amble/shared/services/trim_reschedule.dart';

Task _task({required DateTime scheduledAt, required int durationMinutes}) {
  return Task.create(
    title: 'Task',
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    categoryId: BuiltInCategoryIds.personal,
  );
}

TaskTrim? _trimFor(List<TaskTrim> trims, String taskId) {
  for (final trim in trims) {
    if (trim.taskId == taskId) return trim;
  }
  return null;
}

/// Asserts every pair of tasks in [trims] (applied on top of [allTasks]'
/// original schedules) ends up genuinely non-overlapping, using each
/// task's OWN post-trim duration for a trimmed task rather than its
/// original one — the actual correctness property a chain of trims must
/// deliver. Mirrors `cascade_reschedule_test.dart`'s own
/// `_expectNoOverlaps`.
void _expectNoOverlaps(List<TaskTrim> trims, List<Task> allTasks) {
  final slots = <String, (DateTime start, DateTime end)>{
    for (final task in allTasks)
      task.id: (
        task.scheduledAt!,
        task.scheduledAt!.add(Duration(minutes: task.durationMinutes!)),
      ),
  };
  for (final trim in trims) {
    slots[trim.taskId] = (
      trim.newScheduledAt,
      trim.newScheduledAt.add(Duration(minutes: trim.newDurationMinutes)),
    );
  }

  final ids = slots.keys.toList();
  for (var i = 0; i < ids.length; i++) {
    for (var j = i + 1; j < ids.length; j++) {
      final (aStart, aEnd) = slots[ids[i]]!;
      final (bStart, bEnd) = slots[ids[j]]!;
      final overlaps = aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
      expect(
        overlaps,
        isFalse,
        reason: '${ids[i]} ($aStart-$aEnd) overlaps ${ids[j]} ($bStart-$bEnd)',
      );
    }
  }
}

void main() {
  group('computeTrimMoves', () {
    test('no conflict: returns an empty list, touches nothing', () {
      final dragged = _task(
        scheduledAt: DateTime(2026, 1, 1, 9),
        durationMinutes: 30,
      );
      final other = _task(
        scheduledAt: DateTime(2026, 1, 1, 11),
        durationMinutes: 30,
      );
      final trims = computeTrimMoves(
        draggedTask: dragged,
        newStart: DateTime(2026, 1, 1, 9),
        sameDayTasks: [other],
      );
      expect(trims, isNotNull);
      expect(trims, isEmpty);
    });

    test(
      'single overlap: the conflicting task is shortened to start where '
      'the drop ends, keeping its own end fixed',
      () {
        // Existing 10:00-11:00 (60min). Dragged (30min) dropped at 9:45, so
        // its new end is 10:15 — 15min into the existing task. Existing
        // should trim to 10:15-11:00 (45min), end unchanged.
        final existing = _task(
          scheduledAt: DateTime(2026, 1, 1, 10),
          durationMinutes: 60,
        );
        final dragged = _task(
          scheduledAt: DateTime(2026, 1, 1, 8),
          durationMinutes: 30,
        );

        final trims = computeTrimMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 1, 1, 9, 45),
          sameDayTasks: [existing],
        );

        expect(trims, isNotNull);
        final trim = _trimFor(trims!, existing.id);
        expect(trim, isNotNull);
        expect(trim!.newScheduledAt, DateTime(2026, 1, 1, 10, 15));
        expect(trim.newDurationMinutes, 45);
        _expectNoOverlaps(trims, [existing]);
      },
    );

    test(
      'chains through a second task when the first trim still overlaps it',
      () {
        // Existing A: 10:00-10:10 (10min) — will be entirely swallowed
        // then some. Existing B: 10:10-11:00 (50min), starts exactly where
        // A ends (back-to-back, not itself an overlap with A).
        // Dragged (40min) dropped at 9:50 -> new end 10:30.
        // A (10:00-10:10) fully inside the drop -> too short to trim (its
        // whole original 10min duration ends before the frontier even
        // reaches its own end), so A is pushed wholesale to start at
        // 10:30, keeping its 10min duration -> 10:30-10:40.
        // Frontier now 10:40. B (10:10-11:00) overlaps 10:40 -> trimmed to
        // start at 10:40, end fixed at 11:00 -> 20min.
        final a = _task(
          scheduledAt: DateTime(2026, 1, 1, 10),
          durationMinutes: 10,
        );
        final b = _task(
          scheduledAt: DateTime(2026, 1, 1, 10, 10),
          durationMinutes: 50,
        );
        final dragged = _task(
          scheduledAt: DateTime(2026, 1, 1, 8),
          durationMinutes: 40,
        );

        final trims = computeTrimMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 1, 1, 9, 50),
          sameDayTasks: [a, b],
        );

        expect(trims, isNotNull);
        final trimA = _trimFor(trims!, a.id);
        final trimB = _trimFor(trims, b.id);
        expect(trimA, isNotNull);
        expect(trimA!.newScheduledAt, DateTime(2026, 1, 1, 10, 30));
        expect(trimA.newDurationMinutes, 10, reason: 'pushed, not trimmed');

        expect(trimB, isNotNull);
        expect(trimB!.newScheduledAt, DateTime(2026, 1, 1, 10, 40));
        expect(trimB.newDurationMinutes, 20);

        _expectNoOverlaps(trims, [a, b]);
      },
    );

    test(
      'a trim that would shrink below the minimum floor pushes the whole '
      'task instead, preserving its original duration',
      () {
        // Existing 10:00-10:08 (8min). Dragged (30min) dropped at 9:45 ->
        // new end 10:15, which is past existing's own end entirely — the
        // "trim" would be negative, so it must push wholesale.
        final existing = _task(
          scheduledAt: DateTime(2026, 1, 1, 10),
          durationMinutes: 8,
        );
        final dragged = _task(
          scheduledAt: DateTime(2026, 1, 1, 8),
          durationMinutes: 30,
        );

        final trims = computeTrimMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 1, 1, 9, 45),
          sameDayTasks: [existing],
        );

        expect(trims, isNotNull);
        final trim = _trimFor(trims!, existing.id);
        expect(trim, isNotNull);
        expect(trim!.newScheduledAt, DateTime(2026, 1, 1, 10, 15));
        expect(
          trim.newDurationMinutes,
          8,
          reason: 'pushed wholesale, original 8min duration preserved',
        );
      },
    );

    test(
      'a trim landing exactly at the minimum floor is trimmed, not pushed',
      () {
        // Existing 10:00-11:00 (60min). Dragged (30min) dropped so its new
        // end is 10:55 -> trimmed duration would be exactly 5min, the
        // floor — must trim, not push.
        final existing = _task(
          scheduledAt: DateTime(2026, 1, 1, 10),
          durationMinutes: 60,
        );
        final dragged = _task(
          scheduledAt: DateTime(2026, 1, 1, 8),
          durationMinutes: 30,
        );

        final trims = computeTrimMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 1, 1, 10, 25),
          sameDayTasks: [existing],
        );

        expect(trims, isNotNull);
        final trim = _trimFor(trims!, existing.id);
        expect(trim!.newScheduledAt, DateTime(2026, 1, 1, 10, 55));
        expect(trim.newDurationMinutes, 5);
      },
    );

    test(
      'a task entirely BEFORE the drop is never touched, even if another '
      'task after the drop is',
      () {
        final before = _task(
          scheduledAt: DateTime(2026, 1, 1, 7),
          durationMinutes: 30,
        );
        final after = _task(
          scheduledAt: DateTime(2026, 1, 1, 10),
          durationMinutes: 60,
        );
        final dragged = _task(
          scheduledAt: DateTime(2026, 1, 1, 8),
          durationMinutes: 30,
        );

        final trims = computeTrimMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 1, 1, 9, 45),
          sameDayTasks: [before, after],
        );

        expect(trims, isNotNull);
        expect(_trimFor(trims!, before.id), isNull);
        expect(_trimFor(trims, after.id), isNotNull);
      },
    );

    test('a task ending exactly when the drop starts is not touched '
        '(back-to-back is not an overlap)', () {
      final adjacent = _task(
        scheduledAt: DateTime(2026, 1, 1, 9),
        durationMinutes: 45,
      );
      final dragged = _task(
        scheduledAt: DateTime(2026, 1, 1, 12),
        durationMinutes: 30,
      );

      final trims = computeTrimMoves(
        draggedTask: dragged,
        newStart: DateTime(2026, 1, 1, 9, 45),
        sameDayTasks: [adjacent],
      );

      expect(trims, isNotNull);
      expect(trims, isEmpty);
    });

    test(
      'returns null when resolving a conflict would push a task past '
      'midnight',
      () {
        final existing = _task(
          scheduledAt: DateTime(2026, 1, 1, 23, 50),
          durationMinutes: 5,
        );
        final dragged = _task(
          scheduledAt: DateTime(2026, 1, 1, 8),
          durationMinutes: 30,
        );

        // Dragged dropped so its end (23:55) is inside existing's 5min
        // slot, and existing is too short to trim (its own duration is
        // already below the floor) — pushing it wholesale would end at
        // 00:00 exactly, which is fine (end-of-day, not past it), but
        // shift the drop 1 minute later and it must fail.
        final trims = computeTrimMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 1, 1, 23, 26),
          sameDayTasks: [existing],
        );
        // 23:26 + 30min = 23:56 end, existing pushed to 23:56, +5min =
        // 00:01 next day -> past day end -> null.
        expect(trims, isNull);
      },
    );

    test(
      'the dragged task itself is excluded from candidates even if passed '
      'in sameDayTasks',
      () {
        final dragged = _task(
          scheduledAt: DateTime(2026, 1, 1, 9),
          durationMinutes: 30,
        );
        final trims = computeTrimMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 1, 1, 9),
          sameDayTasks: [dragged],
        );
        expect(trims, isNotNull);
        expect(trims, isEmpty);
      },
    );
  });
}
