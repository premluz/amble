import '../models/task.dart';

/// Which side of the picked point moves, and which way — see
/// `move_all_sheet.dart`'s own `_MoveAllDirection` doc comment for the
/// full reasoning (this is the same enum, promoted here so the pure
/// computation below can be unit-tested without a widget).
enum MoveAllDirection {
  /// Every task starting before the point moves LATER by the picked
  /// amount.
  beforeToLater,

  /// Every task starting at or after the point moves EARLIER by the
  /// picked amount.
  afterToEarlier,
}

/// Computes the per-task minute deltas `move_all_sheet.dart`'s "Move all"
/// button hands to [TaskList.shiftTasksByMinutes] — pulled out as a pure
/// function (no `ref`, no widget, no Hive) so the actual scope-filter and
/// sign logic can be verified directly, sidestepping a widget-test-only
/// `UnmountedRefException` this codebase hit trying to exercise the same
/// logic through a full tap-and-commit round trip (see
/// docs/ERROR_LOG.md).
///
/// Only tasks scheduled on [around]'s own calendar day are eligible —
/// confirmed via AskUserQuestion, "Move all" never reaches into another
/// day or a recurring series' other instances.
Map<String, int> computeMoveAllDeltas({
  required List<Task> tasks,
  required DateTime around,
  required MoveAllDirection direction,
  required int amountMinutes,
}) {
  final dayStart = DateTime(around.year, around.month, around.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final eligible = tasks.where(
    (t) =>
        t.scheduledAt != null &&
        !t.scheduledAt!.isBefore(dayStart) &&
        t.scheduledAt!.isBefore(dayEnd),
  );
  final scoped = eligible.where(
    (t) => direction == MoveAllDirection.beforeToLater
        ? t.scheduledAt!.isBefore(around)
        : !t.scheduledAt!.isBefore(around),
  );
  final signedDelta = direction == MoveAllDirection.beforeToLater
      ? amountMinutes
      : -amountMinutes;
  return {for (final t in scoped) t.id: signedDelta};
}
