import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/models/task_category.dart';
import 'package:amble/shared/services/cascade_reschedule.dart';

Task _task({
  required DateTime scheduledAt,
  required int durationMinutes,
}) {
  return Task.create(
    title: 'Task',
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    category: TaskCategory.personal,
  );
}

DateTime? _moveFor(List<TaskMove> moves, String taskId) {
  for (final move in moves) {
    if (move.taskId == taskId) return move.newScheduledAt;
  }
  return null;
}

/// Asserts every pair of tasks in [moves] (applied on top of [allTasks]'
/// original schedules) ends up genuinely non-overlapping — the actual
/// correctness property a cascade must deliver, not just "produced some
/// output" or "terminated." Used by the multi-simultaneous-conflict
/// regression tests below, where the bug this file guards against
/// (multiple tasks pushed by the same mover landing on identical or
/// colliding slots) would otherwise go undetected by asserting only
/// individual expected positions.
void _expectNoOverlaps(List<TaskMove> moves, List<Task> allTasks) {
  final slots = <String, (DateTime start, DateTime end)>{
    for (final task in allTasks)
      task.id: (
        task.scheduledAt!,
        task.scheduledAt!.add(Duration(minutes: task.durationMinutes!)),
      ),
  };
  for (final move in moves) {
    final task = allTasks.firstWhere((t) => t.id == move.taskId);
    slots[move.taskId] = (
      move.newScheduledAt,
      move.newScheduledAt.add(Duration(minutes: task.durationMinutes!)),
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
        reason:
            '${ids[i]} ($aStart-$aEnd) overlaps ${ids[j]} ($bStart-$bEnd)',
      );
    }
  }
}

void main() {
  group('computeCascadeMoves', () {
    test(
      'worked example 1: drop closer to existing end pushes existing earlier',
      () {
        // Existing 11:00-12:00 (60min). Dragged task (60min) dropped so its
        // new start is 11:45 — 15min from existing's end (12:00), 45min
        // from existing's start (11:00), so existing's end is the nearer
        // edge and it shifts earlier, keeping its own duration: its end
        // lands exactly on the dragged task's new start (11:45), giving
        // 10:45-11:45.
        final dragged = _task(
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 60,
        );
        final existing = _task(
          scheduledAt: DateTime(2026, 8, 24, 11),
          durationMinutes: 60,
        );

        final moves = computeCascadeMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 8, 24, 11, 45),
          sameDayTasks: [existing],
        );

        expect(moves, isNotNull);
        expect(moves!.length, 2);
        expect(
          _moveFor(moves, dragged.id),
          DateTime(2026, 8, 24, 11, 45),
        );
        expect(
          _moveFor(moves, existing.id),
          DateTime(2026, 8, 24, 10, 45),
        );
      },
    );

    test(
      'worked example 2: drop closer to existing start pushes existing later',
      () {
        // Existing 11:00-12:00 (60min). Dragged task (60min) dropped so its
        // new start is 10:15 (new end 11:15) — 45min from existing's start
        // (11:00), 105min from existing's end (12:00), so existing's start
        // is the nearer edge and it shifts later, clearing the dragged
        // task's full span: its start lands on the dragged task's new end
        // (11:15), giving 11:15-12:15.
        final dragged = _task(
          scheduledAt: DateTime(2026, 8, 24, 9),
          durationMinutes: 60,
        );
        final existing = _task(
          scheduledAt: DateTime(2026, 8, 24, 11),
          durationMinutes: 60,
        );

        final moves = computeCascadeMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 8, 24, 10, 15),
          sameDayTasks: [existing],
        );

        expect(moves, isNotNull);
        expect(moves!.length, 2);
        expect(
          _moveFor(moves, dragged.id),
          DateTime(2026, 8, 24, 10, 15),
        );
        expect(
          _moveFor(moves, existing.id),
          DateTime(2026, 8, 24, 11, 15),
        );
      },
    );

    test('no overlap at all returns just the dragged task\'s own move', () {
      final dragged = _task(
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 30,
      );
      final other = _task(
        scheduledAt: DateTime(2026, 8, 24, 14),
        durationMinutes: 30,
      );

      final moves = computeCascadeMoves(
        draggedTask: dragged,
        newStart: DateTime(2026, 8, 24, 10),
        sameDayTasks: [other],
      );

      expect(moves, isNotNull);
      expect(moves!.length, 1);
      expect(_moveFor(moves, dragged.id), DateTime(2026, 8, 24, 10));
    });

    test('back-to-back (touching) slot is not treated as an overlap', () {
      final dragged = _task(
        scheduledAt: DateTime(2026, 8, 24, 9),
        durationMinutes: 60,
      );
      final other = _task(
        scheduledAt: DateTime(2026, 8, 24, 12),
        durationMinutes: 60,
      );

      // New start 11:00, new end 12:00 — exactly touches other's start,
      // which is a half-open boundary, not an overlap.
      final moves = computeCascadeMoves(
        draggedTask: dragged,
        newStart: DateTime(2026, 8, 24, 11),
        sameDayTasks: [other],
      );

      expect(moves, isNotNull);
      expect(moves!.length, 1);
    });

    test('3-task chain cascades in the push direction', () {
      // A: 11:00-12:00, B: 12:00-13:00 (back to back, no gap). Dragging a
      // 60min task to a new start of 11:45 pushes A earlier (end lands on
      // 11:45 -> 10:45-11:45). A's push doesn't touch B (B is untouched by
      // A moving earlier). Reconfigure so B is close enough to A's *new*
      // slot to also need a push: instead push A later so it chains into B.
      final dragged = _task(
        scheduledAt: DateTime(2026, 8, 24, 8),
        durationMinutes: 60,
      );
      final a = _task(
        scheduledAt: DateTime(2026, 8, 24, 11),
        durationMinutes: 60,
      );
      final b = _task(
        scheduledAt: DateTime(2026, 8, 24, 12),
        durationMinutes: 60,
      );

      // Drop dragged so its new start (10:15) is nearer A's start (11:00,
      // 45min away) than A's end (12:00, 105min away) -> A pushes later,
      // clearing dragged's new end (11:15): A becomes 11:15-12:15. That now
      // overlaps B (12:00-13:00): distance from A's new start (11:15) to
      // B's start (12:00) is 45min, to B's end (13:00) is 105min -> B's
      // start is nearer -> B pushes later too, clearing A's new end
      // (12:15): B becomes 12:15-13:15.
      final moves = computeCascadeMoves(
        draggedTask: dragged,
        newStart: DateTime(2026, 8, 24, 10, 15),
        sameDayTasks: [a, b],
      );

      expect(moves, isNotNull);
      expect(moves!.length, 3);
      expect(_moveFor(moves, dragged.id), DateTime(2026, 8, 24, 10, 15));
      expect(_moveFor(moves, a.id), DateTime(2026, 8, 24, 11, 15));
      expect(_moveFor(moves, b.id), DateTime(2026, 8, 24, 12, 15));
    });

    test(
      'a push that would cross midnight falls back to the opposite '
      'direction instead of rejecting the drop',
      () {
        // This case USED to be rejected outright (the cascade returned
        // null and the drag snapped back). Requested directly that a drop
        // onto a busy zone should always be allowed — "it'd just move
        // other items up down or some up some down" — so the preferred
        // push direction running out of day now falls back to the other
        // direction rather than failing.
        final dragged = _task(
          scheduledAt: DateTime(2026, 8, 24, 8),
          durationMinutes: 60,
        );
        // Existing task sits right at the end of the day; pushing it
        // LATER would run past 24:00, so it must go earlier instead.
        final existing = _task(
          scheduledAt: DateTime(2026, 8, 24, 23, 30),
          durationMinutes: 30,
        );

        final moves = computeCascadeMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 8, 24, 23),
          sameDayTasks: [existing],
        );

        expect(moves, isNotNull);
        // Pushed earlier, ending exactly where the dragged task now starts.
        expect(_moveFor(moves!, existing.id), DateTime(2026, 8, 24, 22, 30));
        _expectNoOverlaps(moves, [existing, dragged]);
      },
    );

    test(
      'a dense late-evening cluster is accepted, splitting pushes across '
      'both directions rather than rejecting the drop',
      () {
        // Regression test for the reported behaviour: dropping into a
        // condensed zone late in the day used to snap back, because every
        // conflicting task preferred to shift later and ran out of room
        // before midnight. Some now shift earlier instead.
        final dragged = _task(
          scheduledAt: DateTime(2026, 8, 24, 22, 20),
          durationMinutes: 40,
        );
        final a = _task(
          scheduledAt: DateTime(2026, 8, 24, 22),
          durationMinutes: 40,
        );
        final b = _task(
          scheduledAt: DateTime(2026, 8, 24, 22, 40),
          durationMinutes: 40,
        );
        final c = _task(
          scheduledAt: DateTime(2026, 8, 24, 23, 20),
          durationMinutes: 40,
        );

        final moves = computeCascadeMoves(
          draggedTask: dragged,
          newStart: dragged.scheduledAt!,
          sameDayTasks: [a, b, c],
        );

        expect(moves, isNotNull);
        _expectNoOverlaps(moves!, [a, b, c, dragged]);
      },
    );

    test(
      'day-boundary guard also aborts when the dragged task itself would '
      'start before 00:00',
      () {
        final dragged = _task(
          scheduledAt: DateTime(2026, 8, 24, 8),
          durationMinutes: 60,
        );

        final moves = computeCascadeMoves(
          draggedTask: dragged,
          newStart: DateTime(2026, 8, 23, 23, 30),
          sameDayTasks: const [],
        );

        expect(moves, isNull);
      },
    );

    test('cycle guard: many tasks packed tightly does not loop forever, '
        'and if it succeeds the result is genuinely overlap-free', () {
      final dragged = _task(
        scheduledAt: DateTime(2026, 8, 24, 6),
        durationMinutes: 30,
      );
      // Five back-to-back 30-minute tasks starting at 9:00.
      final tasks = [
        for (var i = 0; i < 5; i++)
          _task(
            scheduledAt: DateTime(2026, 8, 24, 9).add(
              Duration(minutes: 30 * i),
            ),
            durationMinutes: 30,
          ),
      ];

      // Drop into the middle of the tightly-packed block.
      final moves = computeCascadeMoves(
        draggedTask: dragged,
        newStart: DateTime(2026, 8, 24, 10),
        sameDayTasks: tasks,
      );

      // Must terminate (the original point of this test), AND — since the
      // bidirectional fallback landed — actually succeed: this block sits
      // mid-morning with hours free on both sides, so there is no honest
      // reason to reject it. The assertion used to allow isNull, which
      // would have hidden exactly the over-eager rejection that was later
      // reported. The result must also be genuinely non-overlapping.
      expect(moves, isNotNull);
      _expectNoOverlaps(moves!, [...tasks, dragged]);
    });

    test(
      'multiple tasks overlapping the SAME mover simultaneously all end '
      'up non-overlapping, not collapsed onto the same slot',
      () {
        // Regression test for a real reported bug: dropping a task into a
        // dense cluster where 3+ existing tasks all overlap the drop
        // simultaneously used to push every one of them independently
        // from the dragged task's own edges, with no check against each
        // other — so same-direction pushes landed on the exact same slot
        // (confirmed via a standalone reproduction before this fix).
        final dragged = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 20),
          durationMinutes: 40,
        );
        final a = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 15),
          durationMinutes: 40,
        );
        final b = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 30),
          durationMinutes: 40,
        );
        final c = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 45),
          durationMinutes: 40,
        );
        final d = _task(
          scheduledAt: DateTime(2026, 8, 20, 21),
          durationMinutes: 40,
        );

        final moves = computeCascadeMoves(
          draggedTask: dragged,
          newStart: dragged.scheduledAt!,
          sameDayTasks: [a, b, c, d],
        );

        expect(moves, isNotNull);
        _expectNoOverlaps(moves!, [a, b, c, d, dragged]);
      },
    );

    test(
      'a push that would land on a task already placed by an earlier '
      'branch of the same cascade walks further instead of colliding',
      () {
        // Chosen so B is pushed BEFORE D in one mover's pass, and a later
        // mover pass (A, now occupying B's old territory) tries to push D
        // into exactly where B already landed — the second layer of the
        // same bug: not just simultaneous conflicts on one mover, but a
        // later mover's push colliding with an earlier mover's result.
        final dragged = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 20),
          durationMinutes: 40,
        );
        final a = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 15),
          durationMinutes: 40,
        );
        final b = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 30),
          durationMinutes: 40,
        );
        final c = _task(
          scheduledAt: DateTime(2026, 8, 20, 20, 45),
          durationMinutes: 40,
        );
        final d = _task(
          scheduledAt: DateTime(2026, 8, 20, 21),
          durationMinutes: 40,
        );

        final moves = computeCascadeMoves(
          draggedTask: dragged,
          newStart: dragged.scheduledAt!,
          sameDayTasks: [a, b, c, d],
        );

        expect(moves, isNotNull);
        // d's own explicit position, not just "no overlaps" — d does not
        // directly overlap the dragged task at all; it's only reached
        // once a's own push (a later mover pass) collides with it, which
        // is exactly the second-layer case this test targets.
        expect(_moveFor(moves!, d.id), isNot(d.scheduledAt));
        _expectNoOverlaps(moves, [a, b, c, d, dragged]);
      },
    );
  });
}
