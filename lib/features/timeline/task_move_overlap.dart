import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_context_menu.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/cascade_reschedule.dart';
import '../../shared/services/move_resize_undo.dart';
import '../../shared/services/overlap_checker.dart';
import '../../shared/services/trim_reschedule.dart';
import 'task_resize_overlap.dart' show taskOverlapMenuActions;

/// Moves [task] to [newStart] — possibly another day — with the Day
/// screen's drop rules: a clear slot just moves it; landing on another task
/// asks Overlap / Push all / Trim (a dismissed menu means Overlap, an
/// infeasible choice writes nothing). Every write is one undo step.
///
/// [dayTasks] are the tasks on [newStart]'s day, occurrences included.
/// Completes once the chosen write has landed, so the caller can drop its
/// drag preview without the task snapping back first.
///
/// The Day screen's own drop (`_DraggableTaskBlock` in `timeline_screen.dart`)
/// follows the same contract inline.
Future<void> commitTaskMove(
  BuildContext context,
  WidgetRef ref, {
  required Task task,
  required DateTime newStart,
  required List<Task> dayTasks,
  required Offset anchor,
}) {
  final writes = _MoveWrites(
    context,
    ref,
    task: task,
    newStart: newStart,
    others: dayTasks
        .where((other) => other.id != task.id && other.isScheduled)
        .toList(),
  );
  final clear = !overlapsExistingTask(
    scheduledAt: newStart,
    durationMinutes: task.durationMinutes!,
    existingTasks: writes.others,
  );
  return clear ? writes.overlap() : _askOverlap(context, anchor, writes);
}

Future<void> _askOverlap(
  BuildContext context,
  Offset anchor,
  _MoveWrites writes,
) async {
  // The menu runs the chosen action before `showAt` returns.
  Future<void>? chosen;
  var resolved = false;
  await AppContextMenu.showAt(
    context,
    position: anchor,
    actions: taskOverlapMenuActions(
      onOverlap: () {
        resolved = true;
        chosen = writes.overlap();
      },
      onPushAll: () {
        resolved = true;
        chosen = writes.pushAll();
      },
      onTrim: () {
        resolved = true;
        chosen = writes.trim();
      },
    ),
  );
  if (chosen case final write?) return write;
  if (!resolved && context.mounted) await writes.overlap();
}

/// The three ways a move can land, each one undo step.
class _MoveWrites {
  _MoveWrites(
    this.context,
    this.ref, {
    required this.task,
    required this.newStart,
    required this.others,
  });

  final BuildContext context;
  final WidgetRef ref;
  final Task task;
  final DateTime newStart;

  /// The other scheduled tasks on [newStart]'s day.
  final List<Task> others;

  TaskList get _tasks => ref.read(taskListProvider.notifier);
  String get _moved => "Moved '${task.title}'";

  Future<void> _commit(
    Iterable<String> taskIds,
    String message,
    Future<void> Function() write,
  ) => commitTaskChangeWithUndo(
    context,
    ref,
    taskIds: taskIds,
    message: message,
    commit: write,
  );

  Future<void> overlap() =>
      _commit([task.id], _moved, () => _tasks.rescheduleTask(task, newStart));

  /// Null (nothing written) when the day has no room to push into.
  Future<void>? pushAll() {
    final pushes = computeCascadeMoves(
      draggedTask: task,
      newStart: newStart,
      sameDayTasks: others,
    );
    if (pushes == null) return null;
    return _commit(
      pushes.map((move) => move.taskId),
      pushes.length > 1 ? 'Moved ${pushes.length} task(s)' : _moved,
      () => _tasks.rescheduleTaskWithCascade(pushes),
    );
  }

  /// Null (nothing written) when trimming can't make room.
  Future<void>? trim() {
    final trims = computeTrimMoves(
      draggedTask: task,
      newStart: newStart,
      sameDayTasks: others,
    );
    if (trims == null) return null;
    return _commit(
      [task.id, ...trims.map((trim) => trim.taskId)],
      trims.isEmpty ? _moved : 'Trimmed ${trims.length} task(s)',
      () => _tasks.rescheduleTaskWithTrim(
        draggedTask: task,
        newScheduledAt: newStart,
        trims: trims,
      ),
    );
  }
}
