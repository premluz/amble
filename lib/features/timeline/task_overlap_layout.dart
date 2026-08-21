import '../../shared/models/task.dart';

/// Where a task sits horizontally when it shares time with others.
///
/// The Timeline never moves a task the user didn't drag (cascade
/// replanning is explicitly out of MVP scope — see docs/SCOPE.md), so
/// overlapping tasks are shown side by side instead: the conflict stays
/// visible and the user decides what to do about it. This is the standard
/// calendar treatment and matches design principle 1 (the plan is
/// provisional, not a verdict).
class TaskLayoutSlot {
  const TaskLayoutSlot({
    required this.task,
    required this.column,
    required this.columnCount,
  });

  final Task task;

  /// 0-based horizontal position within this task's overlap group.
  final int column;

  /// How many columns the task's overlap group needs. 1 means the task
  /// overlaps nothing and takes the full width.
  final int columnCount;

  /// Fraction of the available width this task occupies (1.0 when alone).
  double get widthFraction => 1 / columnCount;

  /// Fraction of the available width to offset this task from the left.
  double get leftFraction => column / columnCount;
}

/// Assigns each of [tasks] a horizontal column so overlapping tasks render
/// side by side rather than stacked invisibly on top of each other.
///
/// Tasks that don't overlap anything get the full width. A set of tasks
/// that mutually overlap forms a group, and every task in that group is
/// laid out against the same column count — so two overlapping tasks each
/// take half the width, three take a third, and so on. Column count is
/// computed per group rather than globally, so one busy hour doesn't
/// narrow the whole day.
///
/// Every task must be scheduled (`isScheduled == true`); callers get their
/// tasks from `tasksForSelectedDayProvider`, which already guarantees this.
List<TaskLayoutSlot> layoutOverlappingTasks(List<Task> tasks) {
  if (tasks.isEmpty) return const [];

  final sorted = [...tasks]
    ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

  final slots = <TaskLayoutSlot>[];

  // Walk the day in time order, accumulating a group of tasks that overlap
  // each other. A group ends at the first task starting at or after the
  // group's latest end time — nothing after that point can overlap anything
  // already in the group.
  var groupStart = 0;
  var groupEnd = _endOf(sorted.first);

  for (var i = 1; i <= sorted.length; i++) {
    final startsNewGroup =
        i == sorted.length || !sorted[i].scheduledAt!.isBefore(groupEnd);

    if (startsNewGroup) {
      slots.addAll(_layoutGroup(sorted.sublist(groupStart, i)));
      if (i == sorted.length) break;
      groupStart = i;
      groupEnd = _endOf(sorted[i]);
    } else {
      final end = _endOf(sorted[i]);
      if (end.isAfter(groupEnd)) groupEnd = end;
    }
  }

  return slots;
}

/// Packs one overlap group into the fewest columns that keep every pair of
/// genuinely-overlapping tasks apart. A task reuses the first column whose
/// last occupant has already finished, so a group like 9:00-10:00,
/// 9:30-10:30, 10:00-11:00 needs two columns rather than three.
List<TaskLayoutSlot> _layoutGroup(List<Task> group) {
  if (group.length == 1) {
    return [TaskLayoutSlot(task: group.single, column: 0, columnCount: 1)];
  }

  final columnEndTimes = <DateTime>[];
  final assignedColumns = <int>[];

  for (final task in group) {
    var column = columnEndTimes.indexWhere(
      (end) => !end.isAfter(task.scheduledAt!),
    );
    if (column == -1) {
      column = columnEndTimes.length;
      columnEndTimes.add(_endOf(task));
    } else {
      columnEndTimes[column] = _endOf(task);
    }
    assignedColumns.add(column);
  }

  final columnCount = columnEndTimes.length;
  return [
    for (var i = 0; i < group.length; i++)
      TaskLayoutSlot(
        task: group[i],
        column: assignedColumns[i],
        columnCount: columnCount,
      ),
  ];
}

DateTime _endOf(Task task) =>
    task.scheduledAt!.add(Duration(minutes: task.durationMinutes!));
