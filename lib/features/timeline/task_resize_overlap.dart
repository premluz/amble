import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_context_menu.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/services/cascade_reschedule.dart';
import '../../shared/services/move_resize_undo.dart';
import '../../shared/services/overlap_checker.dart';
import '../../shared/services/trim_reschedule.dart';
import 'tasks_for_selected_day_provider.dart';

/// The Overlap / Push all / Trim choice every conflicting drop — and now
/// resize — offers.
List<AppContextMenuAction> taskOverlapMenuActions({
  required VoidCallback onOverlap,
  required VoidCallback onPushAll,
  required VoidCallback onTrim,
}) => [
  AppContextMenuAction(
    icon: Icons.layers_outlined,
    label: 'Overlap',
    onTap: onOverlap,
  ),
  AppContextMenuAction(
    icon: Icons.arrow_forward_rounded,
    label: 'Push all',
    onTap: onPushAll,
  ),
  AppContextMenuAction(
    icon: Icons.content_cut_rounded,
    label: 'Trim',
    onTap: onTrim,
  ),
];

/// Commits a single task's resize, asking first when the new span lands on
/// another task — requested directly: "resize when hits clash/overlap
/// should also trigger that context menu with options."
///
/// The resized task keeps plain resize semantics (no `rescheduled` status);
/// only the neighbours it pushes or trims get a drop's bookkeeping. Each
/// choice is one undo step covering every task it touched. A dismissed
/// menu falls back to Overlap, like a drop's; an infeasible Push all or
/// Trim writes nothing, like a drop's snap-back.
///
/// [onApplied] runs in the same synchronous step that puts the new span on
/// the live task, so the caller can drop its drag preview then. Released
/// any earlier, the pill snaps back while the menu is open. Released any
/// later, the preview stacks on the already-updated duration.
Future<void> commitTaskResize(
  BuildContext context,
  WidgetRef ref, {
  required Task task,
  required DateTime newStart,
  required int newDuration,
  required Offset anchor,
  required VoidCallback onApplied,
}) async {
  // The day being shown, occurrences included.
  final tasks = ref.read(tasksForSelectedDayProvider);
  final notifier = ref.read(taskListProvider.notifier);
  final message = "Resized '${task.title}'";

  // Mutation stays inside `commit` — `task` is the live Hive object the
  // undo snapshot reads from, see `commitTaskChangeWithUndo`.
  Future<void> writeResize() {
    task.scheduledAt = newStart;
    task.durationMinutes = newDuration;
    onApplied();
    return notifier.updateTask(task);
  }

  Future<void> commit(Iterable<String> others, Future<void> Function() then) =>
      commitTaskChangeWithUndo(
        context,
        ref,
        taskIds: [task.id, ...others],
        message: message,
        commit: () async {
          await writeResize();
          await then();
        },
      );

  if (!overlapsExistingTask(
    scheduledAt: newStart,
    durationMinutes: newDuration,
    existingTasks: tasks,
    excludeTaskId: task.id,
  )) {
    return commit(const [], () async {});
  }

  final sameDayTasks = tasks
      .where(
        (other) =>
            other.id != task.id &&
            other.isScheduled &&
            _isSameDay(other.scheduledAt!, newStart),
      )
      .toList();
  // The cascade/trim math reads only the mover's id and duration, so a
  // transient stand-in carries the resized span without touching the
  // live task before a choice is made.
  final candidate = Task(
    id: task.id,
    title: task.title,
    scheduledAt: newStart,
    durationMinutes: newDuration,
  );
  final pushes = computeCascadeMoves(
    draggedTask: candidate,
    newStart: newStart,
    sameDayTasks: sameDayTasks,
  )?.where((move) => move.taskId != task.id).toList();
  final trims = computeTrimMoves(
    draggedTask: candidate,
    newStart: newStart,
    sameDayTasks: sameDayTasks,
  );

  // The menu runs an action's onTap right after closing itself, before
  // `showAt` returns, so the chosen write is known by then. Awaiting it
  // lets the caller hold its live preview until the task list has the new
  // span — otherwise the pill snaps back while the menu is open.
  Future<void>? chosen;
  var resolved = false;
  await AppContextMenu.showAt(
    context,
    position: anchor,
    actions: taskOverlapMenuActions(
      onOverlap: () {
        resolved = true;
        chosen = commit(const [], () async {});
      },
      onPushAll: () {
        resolved = true;
        if (pushes == null) return;
        chosen = commit(
          pushes.map((move) => move.taskId),
          () => notifier.rescheduleTaskWithCascade(pushes),
        );
      },
      onTrim: () {
        resolved = true;
        if (trims == null) return;
        chosen = commit(
          trims.map((trim) => trim.taskId),
          () => notifier.trimTasks(trims),
        );
      },
    ),
  );
  if (chosen case final write?) return write;
  if (!resolved && context.mounted) await commit(const [], () async {});
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
