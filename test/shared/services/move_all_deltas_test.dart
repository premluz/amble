import 'package:flutter_test/flutter_test.dart';
import 'package:amble/shared/models/task.dart';
import 'package:amble/shared/services/move_all_deltas.dart';

Task _task({required String id, required DateTime scheduledAt}) =>
    Task(id: id, title: id, scheduledAt: scheduledAt, durationMinutes: 30);

/// Covers `computeMoveAllDeltas` — the pure scope-filter/sign logic behind
/// the hold-and-drag placement release menu's "Move all" entry (requested
/// directly: "this allows to move all tasks before/or after the selected
/// point, by selected h:m from wheeler, later or earlier"). Pulled out of
/// `move_all_sheet.dart`'s widget so this can be verified directly,
/// without a full tap-and-commit widget-test round trip through real Hive
/// I/O — see docs/ERROR_LOG.md's own entry on why that round trip isn't
/// viable for this particular commit path.
void main() {
  final around = DateTime(2026, 1, 5, 12);

  test('beforeToLater moves only tasks strictly before the point, later', () {
    final tasks = [
      _task(id: 'early', scheduledAt: DateTime(2026, 1, 5, 9)),
      _task(id: 'late', scheduledAt: DateTime(2026, 1, 5, 15)),
    ];
    final deltas = computeMoveAllDeltas(
      tasks: tasks,
      around: around,
      direction: MoveAllDirection.beforeToLater,
      amountMinutes: 30,
    );
    expect(deltas, {'early': 30});
  });

  test(
    'afterToEarlier moves tasks AT-OR-AFTER the point, earlier, and leaves '
    'earlier tasks untouched',
    () {
      final tasks = [
        _task(id: 'early', scheduledAt: DateTime(2026, 1, 5, 9)),
        _task(id: 'atPoint', scheduledAt: around),
      ];
      final deltas = computeMoveAllDeltas(
        tasks: tasks,
        around: around,
        direction: MoveAllDirection.afterToEarlier,
        amountMinutes: 30,
      );
      expect(deltas, {'atPoint': -30});
    },
  );

  test('tasks on a different day are never included, either direction', () {
    final tasks = [_task(id: 'otherDay', scheduledAt: DateTime(2026, 1, 6, 9))];
    expect(
      computeMoveAllDeltas(
        tasks: tasks,
        around: around,
        direction: MoveAllDirection.beforeToLater,
        amountMinutes: 30,
      ),
      isEmpty,
    );
    expect(
      computeMoveAllDeltas(
        tasks: tasks,
        around: around,
        direction: MoveAllDirection.afterToEarlier,
        amountMinutes: 30,
      ),
      isEmpty,
    );
  });

  test('a task with no scheduledAt is never included', () {
    final tasks = [Task(id: 'unscheduled', title: 'unscheduled')];
    expect(
      computeMoveAllDeltas(
        tasks: tasks,
        around: around,
        direction: MoveAllDirection.beforeToLater,
        amountMinutes: 30,
      ),
      isEmpty,
    );
  });
}
