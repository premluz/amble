import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/task.dart';
import '../models/task_category.dart';
import '../models/task_status.dart';
import '../repositories/hive_task_repository.dart';
import '../repositories/task_repository.dart';
import 'notification_providers.dart';

part 'task_providers.g.dart';

const taskBoxName = 'tasks';

/// Outcome of [TaskList.importTasks] — per-task counts so the caller can
/// show a summary without needing to inspect individual tasks. See
/// docs/DECISIONS.md for the conflict-handling rationale (skip + report,
/// never silently overwrite).
class ImportResult {
  const ImportResult({
    required this.imported,
    required this.alreadyPresent,
    required this.conflicts,
  });

  /// New tasks (id not previously seen) written.
  final int imported;

  /// Tasks skipped because an identical task with that id already existed.
  final int alreadyPresent;

  /// Tasks skipped because a task with that id already existed but with
  /// different field values — a real conflict, left for the user to
  /// resolve manually rather than auto-overwritten.
  final int conflicts;

  int get total => imported + alreadyPresent + conflicts;
}

@Riverpod(keepAlive: true)
TaskRepository taskRepository(Ref ref) {
  final box = Hive.box<Task>(taskBoxName);
  return HiveTaskRepository(box);
}

@Riverpod(keepAlive: true)
class TaskList extends _$TaskList {
  @override
  List<Task> build() {
    return ref.watch(taskRepositoryProvider).getTasks();
  }

  Future<void> createTask({
    required String title,
    String? notes,
    required DateTime scheduledAt,
    required int durationMinutes,
    required TaskCategory category,
  }) async {
    final task = Task.create(
      title: title,
      notes: notes,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      category: category,
    );
    await ref.read(taskRepositoryProvider).saveTask(task);
    await _syncNotificationSafely(task);
    _refresh();
  }

  /// Captures a title-only, unscheduled Inbox item. Per design principle 2
  /// (capture is frictionless, prioritization is deferred) — no other
  /// fields are required. No notification to sync — an unscheduled task has
  /// no start time to alert on.
  Future<void> captureTask(String title) async {
    final task = Task.captured(title: title);
    await ref.read(taskRepositoryProvider).saveTask(task);
    _refresh();
  }

  /// Moves an Inbox [task] onto the Timeline by giving it a schedule —
  /// the same fields [Task.create] requires, filled in after the fact.
  Future<void> scheduleTask(
    Task task, {
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    task.scheduledAt = scheduledAt;
    task.durationMinutes = durationMinutes;
    await ref.read(taskRepositoryProvider).saveTask(task);
    await _syncNotificationSafely(task);
    _refresh();
  }

  Future<void> updateTask(Task task) async {
    await ref.read(taskRepositoryProvider).saveTask(task);
    await _syncNotificationSafely(task);
    _refresh();
  }

  /// Moves [task] to [newScheduledAt]. Per the Constitution's data model:
  /// `originalScheduledAt` is set only on the *first* reschedule and
  /// preserved afterward (never overwritten), and `status` moves to
  /// `rescheduled`.
  Future<void> rescheduleTask(Task task, DateTime newScheduledAt) async {
    task.originalScheduledAt ??= task.scheduledAt;
    task.scheduledAt = newScheduledAt;
    task.status = TaskStatus.rescheduled;
    await ref.read(taskRepositoryProvider).saveTask(task);
    await _syncNotificationSafely(task);
    _refresh();
  }

  /// Toggles [task] between `completed` and `pending`, writing/clearing
  /// `completedAt` alongside `status` per the Constitution (a separate
  /// timestamp from `scheduledAt`, never conflated with it). Syncing the
  /// notification here cancels the alert when a task is marked done early
  /// (no reason to alert for something already finished) and restores it if
  /// toggled back to pending while still in the future.
  Future<void> toggleComplete(Task task) async {
    if (task.status == TaskStatus.completed) {
      task.status = TaskStatus.pending;
      task.completedAt = null;
    } else {
      task.status = TaskStatus.completed;
      task.completedAt = DateTime.now();
    }
    await ref.read(taskRepositoryProvider).saveTask(task);
    await _syncNotificationSafely(task);
    _refresh();
  }

  Future<void> deleteTask(String id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    try {
      await ref.read(notificationServiceProvider).cancelForTask(id);
    } catch (error) {
      debugPrint('Notification cancel failed for task $id: $error');
    }
    _refresh();
  }

  /// Syncs [task]'s notification without letting a scheduling failure block
  /// the write that already happened above. Notification scheduling is a
  /// real native platform-channel call (`zonedSchedule`) that can throw for
  /// reasons unrelated to the task data itself (permission edge cases,
  /// platform-channel hiccups) — the task is already saved by the time this
  /// runs, and a user tapping Continue/Save must always see the save
  /// succeed, never a silently-stuck sheet because a notification failed to
  /// schedule. Failure is surfaced via [debugPrint], not swallowed
  /// silently, per CLAUDE.md's "fail loud" rule — just not allowed to abort
  /// the caller.
  Future<void> _syncNotificationSafely(Task task) async {
    try {
      await ref.read(notificationServiceProvider).syncForTask(task);
    } catch (error) {
      debugPrint('Notification sync failed for task ${task.id}: $error');
    }
  }

  /// Merges [tasks] (already parsed and schema-validated by the caller —
  /// see `BackupService.import`) into local storage. Never overwrites: a
  /// new id is written as-is, a matching id with identical fields is
  /// counted but not rewritten, and a matching id with different fields is
  /// left untouched and counted as a conflict for the user to resolve
  /// manually. Goes through the same [TaskRepository.saveTask] every other
  /// write uses — bulk import gets no special-cased path around it.
  ///
  /// Deliberately notification-agnostic: unlike every other mutator here,
  /// this does not call [NotificationService.syncForTask] — a bulk/backup
  /// restore (often historical data on a fresh install) shouldn't silently
  /// schedule a wave of notifications or trigger the permission prompt as
  /// a side effect. Confirmed with the user rather than assumed; see
  /// docs/DECISIONS.md.
  Future<ImportResult> importTasks(List<Task> tasks) async {
    final repository = ref.read(taskRepositoryProvider);
    var imported = 0;
    var alreadyPresent = 0;
    var conflicts = 0;

    for (final task in tasks) {
      final existing = repository.getTaskById(task.id);
      if (existing == null) {
        await repository.saveTask(task);
        imported++;
      } else if (existing.hasSameFieldsAs(task)) {
        alreadyPresent++;
      } else {
        conflicts++;
      }
    }

    _refresh();
    return ImportResult(
      imported: imported,
      alreadyPresent: alreadyPresent,
      conflicts: conflicts,
    );
  }

  void _refresh() {
    state = ref.read(taskRepositoryProvider).getTasks();
  }
}

@riverpod
Task? taskById(Ref ref, String id) {
  final tasks = ref.watch(taskListProvider);
  for (final task in tasks) {
    if (task.id == id) return task;
  }
  return null;
}
