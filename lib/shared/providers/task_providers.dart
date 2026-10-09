import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/category.dart';
import '../models/recurrence_rule.dart';
import '../models/series_revision.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../repositories/hive_task_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/preferences_repository.dart';
import '../services/cascade_reschedule.dart';
import '../services/trim_reschedule.dart';
import 'notification_providers.dart';
import 'occurrence_store.dart';
import 'preferences_providers.dart';
import 'series_routing_task_repository.dart';
import 'trial_providers.dart';

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
  // Series occurrences shown as tasks are routed to the series model; real
  // tasks are untouched — see the class's own doc.
  return SeriesRoutingTaskRepository(
    HiveTaskRepository(box),
    () => ref.read(occurrenceStoreProvider.notifier),
  );
}

@Riverpod(keepAlive: true)
class TaskList extends _$TaskList {
  @override
  List<Task> build() {
    return ref.watch(taskRepositoryProvider).getTasks();
  }

  /// Creates a task. Passing [recurrenceRule] creates a repeating series
  /// instead (docs/RECURRENCE_CONTRACT.md) and returns its first occurrence,
  /// shown as a task. Returns the saved task, so a caller can refer to it
  /// afterwards
  /// without a second lookup — the Timeline uses this to know which block
  /// to animate in (see `recently_saved_task_provider.dart`). Callers with
  /// no such need simply ignore the value.
  ///
  /// Throws [TrialExpiredException] once the 21-day trial has ended and
  /// `panta_pro` is not active — requested directly ("lock behind 21 day
  /// trial ability to add new tasks via any route"). Checked HERE, not at
  /// each of the 4+ UI call sites (quick capture, task detail sheet,
  /// quick-create overlay, both native App Intent platforms) — this and
  /// [captureTask] are the only two methods that ever persist a brand-new
  /// Task, so gating them is the one place a future 5th creation route
  /// can't slip past. See `trial_providers.dart`.
  Future<Task> createTask({
    required String title,
    String? notes,
    String? description,
    required DateTime scheduledAt,
    required int durationMinutes,
    required String categoryId,
    RecurrenceRule? recurrenceRule,
    String? behaviorId,
    bool notificationsEnabled = true,
    bool isImportant = false,
    // Set only when this task was spawned from a TaskTemplate — recorded
    // for future frequency-ranking of the quick-drop drawer, never read
    // for cascade or validation. See Task.templateId's own doc comment.
    String? templateId,
  }) async {
    if (!ref.read(canCreateTaskProvider)) {
      throw const TrialExpiredException();
    }
    if (recurrenceRule != null) {
      return ref
          .read(occurrenceStoreProvider.notifier)
          .createSeries(
            rule: recurrenceRule,
            startAt: scheduledAt,
            durationMinutes: durationMinutes,
            defaults: SeriesDefaults(
              title: title,
              description: description,
              categoryId: categoryId,
              behaviorId: behaviorId,
              notificationsEnabled: notificationsEnabled,
              isImportant: isImportant,
            ),
          );
    }
    final task = Task.create(
      title: title,
      notes: notes,
      description: description,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      categoryId: categoryId,
      notificationsEnabled: notificationsEnabled,
      isImportant: isImportant,
      templateId: templateId,
    )..behaviorId = behaviorId;
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);
    _refresh();
    return task;
  }

  /// One-time migration, gated exactly like `CategoryList
  /// .seedBuiltInsAndBackfillIfNeeded`: every pre-existing [Task] read
  /// back with no stored `createdAt` (a row saved before that field
  /// existed) gets one WRITTEN now, rather than left to fall back to
  /// [Task]'s own `?? DateTime.now()` constructor default forever — that
  /// default recomputes "now" on every single load, which would jump an
  /// old note back to the top of the newest-first Inbox sort on every app
  /// launch. Requested directly: "notes in inbox should have created
  /// timestamp if not have already."
  ///
  /// There is no better proxy for an old row's TRUE creation time — a
  /// scheduled task's own [Task.scheduledAt] is when it's DUE, not when
  /// it was captured, so backfilling from it would misorder an old task
  /// planned far in the future/past ahead of/behind newer captures. This
  /// backfill instead freezes "now" as a one-time value per task, in
  /// stable ID order (so the relative order among backfilled rows is at
  /// least deterministic, even though it can't reflect their real,
  /// unrecorded history) — a reasonable stand-in specifically because a
  /// FUTURE session should never re-run this and shuffle them again.
  Future<void> backfillCreatedAtIfNeeded() async {
    final prefs = ref.read(preferencesRepositoryProvider);
    final alreadyBackfilled =
        prefs.getValue<bool>(PreferenceKeys.taskCreatedAtBackfilled) ?? false;
    if (alreadyBackfilled) return;

    final repository = ref.read(taskRepositoryProvider);
    final tasks = repository.getTasks().toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final now = DateTime.now();
    for (var i = 0; i < tasks.length; i++) {
      // Spaced a millisecond apart (oldest id first) purely so no two
      // backfilled rows tie exactly — ties are otherwise harmless (the
      // Inbox sort doesn't need a strict order among them), but a stable
      // spread costs nothing and avoids relying on sort stability for
      // rows that otherwise share one identical instant.
      tasks[i].createdAt = now.subtract(
        Duration(milliseconds: tasks.length - i),
      );
      await repository.saveTask(tasks[i]);
    }
    await prefs.setValue(PreferenceKeys.taskCreatedAtBackfilled, true);
    if (tasks.isNotEmpty) _refresh();
  }

  /// Registers OS alarms for every task now inside the notification
  /// horizon. Called once at launch, after [materializeDueRecurrences], so
  /// freshly-materialized instances are included.
  ///
  /// This is the counterpart to *not* scheduling per instance during
  /// materialization: rather than registering an alarm for all 8 weeks of a
  /// series up front (which blows Android's 500-alarm cap), only the near
  /// window is registered, and each launch rolls that window forward. See
  /// [NotificationService.refreshScheduled] and docs/ERROR_LOG.md.
  Future<void> refreshScheduledNotifications() async {
    final service = ref.read(notificationServiceProvider);
    final withinHorizon = ref
        .read(taskRepositoryProvider)
        .getTasks()
        .where(
          (task) =>
              task.scheduledAt != null &&
              // A finished task has nothing left to alert about — the same
              // rule syncForTask applies on every ordinary write path.
              task.status != TaskStatus.completed &&
              service.isWithinSchedulingHorizon(task.scheduledAt!),
        )
        .toList();

    await service.refreshScheduled(withinHorizon);
  }

  /// Captures a title-only, unscheduled Inbox item. Per design principle 2
  /// (capture is frictionless, prioritization is deferred) — no other
  /// fields are required. No notification to sync — an unscheduled task has
  /// no start time to alert on.
  ///
  /// Throws [TrialExpiredException] — see [createTask]'s own doc comment;
  /// this is the other of the two methods that ever persist a brand-new
  /// Task, so it carries the identical gate.
  /// Returns the created task, so a caller can follow it on screen (voice
  /// mode flies each new task into its Inbox row).
  Future<Task> captureTask(String title) async {
    if (!ref.read(canCreateTaskProvider)) {
      throw const TrialExpiredException();
    }
    final task = Task.captured(title: title);
    await ref.read(taskRepositoryProvider).saveTask(task);
    _refresh();
    return task;
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
    _syncNotificationInBackground(task);
    _refresh();
  }

  Future<void> updateTask(Task task) async {
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);
    _refresh();
  }

  /// Re-saves every [tasks] in one call, refreshing [state] ONCE at the
  /// end rather than once per row — same "many writes, one refresh" fix
  /// as [deleteTasksInBatch], applied to the RESTORE side of Undo: every
  /// `onUndo` callback that snapshots several tasks (a group delete, a
  /// whole-series delete, a move/resize commit) was looping
  /// [updateTask] once per snapshot, so Undo made them reappear one at a
  /// time just like delete used to remove them one at a time. Reported
  /// directly: "when they reappear also not at once."
  Future<void> restoreTasksInBatch(Iterable<Task> tasks) async {
    final repository = ref.read(taskRepositoryProvider);
    for (final task in tasks) {
      await repository.saveTask(task);
      _syncNotificationInBackground(task);
    }
    _refresh();
  }

  /// Creates a standalone copy of [source] — same title/category/
  /// description/schedule as the original, but a fresh UUID (via
  /// [Task.create]) and no link to any series: a duplicate is a new,
  /// independent task, not another occurrence. Status/completion are
  /// deliberately not copied either — a duplicate starts fresh as
  /// `pending`, matching [Task.create]'s own
  /// defaults. [notes] is also deliberately NOT copied — it's a snapshot
  /// of that specific day (see its own doc comment), which a new,
  /// independent task shouldn't inherit; [description] (what the task
  /// IS) copies over the same way title/category do. Returns the saved
  /// task so the caller can open it for review (e.g. in "Edit details")
  /// without a second lookup.
  Future<Task> duplicateTask(Task source) async {
    final duplicate = Task.create(
      title: source.title,
      description: source.description,
      scheduledAt: source.scheduledAt!,
      durationMinutes: source.durationMinutes!,
      // Defensive fallback for a not-yet-backfilled source task — every
      // task post-migration has a real categoryId, but this must not
      // crash if one somehow doesn't.
      categoryId: source.categoryId ?? BuiltInCategoryIds.general,
    )..behaviorId = source.behaviorId;
    await ref.read(taskRepositoryProvider).saveTask(duplicate);
    _syncNotificationInBackground(duplicate);
    _refresh();
    return duplicate;
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
    _syncNotificationInBackground(task);
    _refresh();
  }

  /// Moves [task] to [newScheduledAt] AND sets its explicit [zoneId] in one
  /// write — the Spatial Zone View's own drag-and-drop: dropping a task
  /// inside a container assigns it to that zone explicitly (confirmed
  /// directly), dropping it back on the outer axis clears the assignment
  /// (`zoneId: null`). Deliberately a separate method from [rescheduleTask]
  /// rather than an added optional parameter there — every other
  /// `rescheduleTask` caller (the Task view's own drag) must never
  /// accidentally touch `zoneId`, which stays untouched by that method.
  /// Same `originalScheduledAt`/`status` semantics as [rescheduleTask].
  Future<void> rescheduleTaskWithZone(
    Task task,
    DateTime newScheduledAt,
    String? zoneId,
  ) async {
    task.originalScheduledAt ??= task.scheduledAt;
    task.scheduledAt = newScheduledAt;
    task.status = TaskStatus.rescheduled;
    task.zoneId = zoneId;
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);
    _refresh();
  }

  /// Applies every move in a cascade reschedule (see
  /// `shared/services/cascade_reschedule.dart`) — the dragged task's own
  /// move plus every task it pushed out of the way. Each move goes through
  /// the exact same per-task semantics as [rescheduleTask] (looked up fresh
  /// by id, `originalScheduledAt` preserved on first reschedule only,
  /// `status` set to `rescheduled`), just applied to more than one task in
  /// one call — mirrors how [_materializeSeries] loops and writes several
  /// tasks through the repository rather than the UI layer looping over
  /// individual mutator calls. One [_refresh] at the end, not one per move,
  /// so the Timeline doesn't rebuild mid-cascade.
  Future<void> rescheduleTaskWithCascade(List<TaskMove> moves) async {
    final repository = ref.read(taskRepositoryProvider);
    for (final move in moves) {
      final task = repository.getTaskById(move.taskId);
      if (task == null) continue;
      task.originalScheduledAt ??= task.scheduledAt;
      task.scheduledAt = move.newScheduledAt;
      task.status = TaskStatus.rescheduled;
      await repository.saveTask(task);
      _syncNotificationInBackground(task);
    }
    _refresh();
  }

  /// Applies the "Trim" drop-resolution popover choice: the dragged task's
  /// own move to [newScheduledAt], plus every trim from
  /// `shared/services/trim_reschedule.dart`'s `computeTrimMoves` (each
  /// conflicting task shortened, or — below the minimum floor — pushed
  /// wholesale keeping its own duration, to start where the thing in front
  /// of it now ends). Mirrors [rescheduleTaskWithCascade]'s own shape,
  /// where the dragged task's move is just one more entry applied in the
  /// SAME loop as the tasks it affected, rather than a separate call — so
  /// this is one write pass and one [_refresh] for the whole drop, not two
  /// (which double-triggered a Timeline rebuild when this first called
  /// [rescheduleTask] separately for the dragged task).
  Future<void> rescheduleTaskWithTrim({
    required Task draggedTask,
    required DateTime newScheduledAt,
    required List<TaskTrim> trims,
  }) async {
    final repository = ref.read(taskRepositoryProvider);

    draggedTask.originalScheduledAt ??= draggedTask.scheduledAt;
    draggedTask.scheduledAt = newScheduledAt;
    draggedTask.status = TaskStatus.rescheduled;
    await repository.saveTask(draggedTask);
    _syncNotificationInBackground(draggedTask);
    await _writeTrims(trims);
    _refresh();
  }

  /// Trims neighbours alone, with a drop's reschedule bookkeeping — a
  /// resize's "Trim" choice, where the resized task itself keeps plain
  /// resize semantics and is written separately.
  Future<void> trimTasks(List<TaskTrim> trims) async {
    await _writeTrims(trims);
    _refresh();
  }

  Future<void> _writeTrims(List<TaskTrim> trims) async {
    final repository = ref.read(taskRepositoryProvider);
    for (final trim in trims) {
      final task = repository.getTaskById(trim.taskId);
      if (task == null) continue;
      task.originalScheduledAt ??= task.scheduledAt;
      task.scheduledAt = trim.newScheduledAt;
      task.durationMinutes = trim.newDurationMinutes;
      task.status = TaskStatus.rescheduled;
      await repository.saveTask(task);
      _syncNotificationInBackground(task);
    }
  }

  /// Shifts every named task's `scheduledAt` by its own minutes delta —
  /// Zone move/resize's own cascade committing alongside a zone
  /// (`ZoneList`'s batch commit, `shared/providers/zone_providers.dart`),
  /// requested directly: a zone's assigned tasks move WITH it by the same
  /// delta the zone itself moved. Deliberately a MAP of per-task deltas,
  /// not a single shared one or a list of absolute [TaskMove]s: different
  /// tasks assigned to different zones in the same cascade chain can each
  /// carry a different NET delta (see `computeZoneCascadeMoves`'s own doc
  /// comment on why a chained zone's tasks use one net shift, not one per
  /// intermediate push), and a delta (not an absolute time) is what a
  /// zone's own minutes-since-midnight representation naturally produces
  /// — the caller never has to reach back into a specific day's `DateTime`
  /// to express "this zone moved 30 minutes later."
  ///
  /// Same reschedule bookkeeping as [rescheduleTask]/
  /// [rescheduleTaskWithCascade] — confirmed via AskUserQuestion: a task
  /// whose zone moved really did have its own time change, so its history
  /// should reflect that the same way a direct drag would, regardless of
  /// what caused the change. One [_refresh] at the end, not one per task.
  Future<void> shiftTasksByMinutes(
    Map<String, int> deltaMinutesByTaskId,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    for (final entry in deltaMinutesByTaskId.entries) {
      final task = repository.getTaskById(entry.key);
      if (task == null || task.scheduledAt == null) continue;
      task.originalScheduledAt ??= task.scheduledAt;
      task.scheduledAt = task.scheduledAt!.add(Duration(minutes: entry.value));
      task.status = TaskStatus.rescheduled;
      await repository.saveTask(task);
      _syncNotificationInBackground(task);
    }
    _refresh();
  }

  /// Applies the SAME duration delta (see `_snappedResizeDelta` in
  /// `timeline_screen.dart`) to every task in [newDurationMinutesByTaskId]
  /// in one call — Edit Mode's multi-task resize route, requested directly
  /// ("resizing, all would resize, all selected"). Deliberately a
  /// duration-only batch write, never touching `scheduledAt`/`status`: a
  /// resize is not a reschedule, exactly the same distinction
  /// [rescheduleTaskWithCascade] draws against `rescheduleTask` but for
  /// the resize axis instead of the move axis. Mirrors
  /// [rescheduleTaskWithCascade]'s own shape (looked up fresh by id, one
  /// [_refresh] at the end rather than one per task) — the two are
  /// intentionally structural twins, one per gesture.
  Future<void> resizeTasksInBatch(
    Map<String, int> newDurationMinutesByTaskId,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    for (final entry in newDurationMinutesByTaskId.entries) {
      final task = repository.getTaskById(entry.key);
      if (task == null) continue;
      task.durationMinutes = entry.value;
      await repository.saveTask(task);
      _syncNotificationInBackground(task);
    }
    _refresh();
  }

  /// The TOP-edge equivalent of [resizeTasksInBatch]: writes a new start
  /// AND a new duration for every task in one call.
  ///
  /// A separate method rather than a flag on [resizeTasksInBatch] because
  /// the two edges genuinely differ in what they touch — the bottom edge
  /// changes duration alone, while the top edge moves the start and
  /// compensates the duration so each task's END stays anchored. Folding
  /// them together would mean a duration-only batch that sometimes
  /// silently rewrites `scheduledAt`, which is exactly the conflation
  /// [resizeTasksInBatch]'s own doc comment exists to prevent.
  ///
  /// Not a reschedule despite writing `scheduledAt`: no cascade runs, per
  /// CONSTITUTION.md scoping the cascade to move/create. That matches the
  /// single-task top-resize this batches over.
  Future<void> resizeTasksFromTopInBatch(
    Map<String, ({DateTime scheduledAt, int durationMinutes})> changesByTaskId,
  ) async {
    final repository = ref.read(taskRepositoryProvider);
    for (final entry in changesByTaskId.entries) {
      final task = repository.getTaskById(entry.key);
      if (task == null) continue;
      task.scheduledAt = entry.value.scheduledAt;
      task.durationMinutes = entry.value.durationMinutes;
      await repository.saveTask(task);
      _syncNotificationInBackground(task);
    }
    _refresh();
  }

  /// Toggles [task] between `completed` and `pending`, writing/clearing
  /// `completedAt` alongside `status` per the Constitution (a separate
  /// timestamp from `scheduledAt`, never conflated with it). Syncing the
  /// notification here cancels the alert when a task is marked done early
  /// (no reason to alert for something already finished) and restores it if
  /// toggled back to pending while still in the future.
  /// Toggles completion. [actualAmount] is the outcome recorded against a
  /// linked [TrackedBehavior], and is only ever passed for a task that has
  /// a `behaviorId` — an ordinary task's call site omits it entirely, so
  /// ordinary completion is byte-for-byte the same operation it was before
  /// tracked behaviors existed.
  ///
  /// Un-completing clears any recorded amount: the outcome described a
  /// completion that no longer stands, so leaving it would misreport
  /// history.
  Future<void> toggleComplete(Task task, {num? actualAmount}) async {
    if (task.status == TaskStatus.completed) {
      task.status = TaskStatus.pending;
      task.completedAt = null;
      task.actualAmount = null;
    } else {
      task.status = TaskStatus.completed;
      task.completedAt = DateTime.now();
      if (actualAmount != null) task.actualAmount = actualAmount;
    }
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);
    _refresh();
  }

  /// Deletes one task by id. For a series occurrence the repository
  /// routes this to a cancellation (see `SeriesRoutingTaskRepository`).
  Future<void> deleteTask(String id) async {
    final repository = ref.read(taskRepositoryProvider);
    await repository.deleteTask(id);
    await _cancelNotificationSafely(id);
    _refresh();
  }

  /// Deletes every id in [ids] in one call, refreshing [state] ONCE at the
  /// end rather than once per row — requested directly: multi-select
  /// Remove was calling [deleteTask] in a loop, so each row's own
  /// `_refresh()` rebuilt the UI separately and selected zones/tasks
  /// visibly disappeared one at a time instead of together. Mirrors
  /// [resizeTasksInBatch]/[rescheduleTaskWithCascade]'s own shape (loop
  /// over the raw repository call, one `_refresh()` after the loop) —
  /// same fix, same established pattern, applied to delete.
  ///
  /// Preserves [deleteTask]'s own per-row side effect (notification
  /// cancellation) for every row — this is NOT a naive
  /// `repository.deleteTask` loop, it's the same
  /// logic [deleteTask] runs, just sharing one `_refresh()` at the end.
  /// **Notification cancellation is deliberately NOT awaited here**, unlike
  /// [deleteTask]'s own single-row path. `cancelForTask` is a real
  /// platform-channel round trip; awaiting one per row made a multi-row
  /// delete take visibly longer per extra row, which is what was still
  /// being reported ("one disappears instant, then after long delay the
  /// others") even after this method already shared one [_refresh]. The
  /// Hive writes — the only thing [state] is rendered from — now all land
  /// before that single refresh, and the alarms are cancelled in the
  /// background afterward. Same "the write must not wait on the
  /// notification layer" contract [_syncNotificationInBackground] and
  /// `ZoneList._syncNotification` already apply on the write side; this
  /// extends it to the delete side, where it was the one remaining
  /// blocking platform call.
  Future<void> deleteTasksInBatch(Iterable<String> ids) async {
    final repository = ref.read(taskRepositoryProvider);
    final deletedIds = <String>[];
    for (final id in ids) {
      await repository.deleteTask(id);
      deletedIds.add(id);
    }
    _refresh();
    unawaited(_cancelNotificationsInBackground(deletedIds));
  }

  /// Cancels every id's alarm off the critical path — see
  /// [deleteTasksInBatch]'s own note on why this isn't awaited. Each
  /// cancel is individually guarded by [_cancelNotificationSafely], so one
  /// failure never stops the rest.
  Future<void> _cancelNotificationsInBackground(List<String> ids) async {
    for (final id in ids) {
      await _cancelNotificationSafely(id);
    }
  }

  /// "Delete series": ends [instance]'s series from today, keeping its
  /// history (docs/RECURRENCE_CONTRACT.md §8). Returns the command id so the
  /// caller's Undo can reverse exactly this change.
  Future<String> deleteTaskSeries(Task instance) =>
      ref.read(occurrenceStoreProvider.notifier).endSeriesOf(instance);

  /// "Remove this occurrence" of a series: a cancellation, not a deletion
  /// (docs/RECURRENCE_CONTRACT.md §5). Returns the command id for Undo.
  Future<String> cancelOccurrence(Task occurrence) => ref
      .read(occurrenceStoreProvider.notifier)
      .cancelOccurrence(occurrence.id);

  /// Undo for a series change ([deleteTaskSeries], [cancelOccurrence], or a
  /// series created via [createTask]). Throws `UndoConflictException` if
  /// what it changed has changed since.
  Future<void> undoSeriesChange(String commandId) =>
      ref.read(occurrenceStoreProvider.notifier).undo(commandId);

  /// Cancels [id]'s notification without letting a platform failure block
  /// the delete that prompted it — mirrors [_syncNotificationSafely].
  Future<void> _cancelNotificationSafely(String id) async {
    try {
      await ref.read(notificationServiceProvider).cancelForTask(id);
    } catch (error) {
      debugPrint('Notification cancel failed for task $id: $error');
    }
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

  /// Fire-and-forget [_syncNotificationSafely] — deliberately NOT awaited by
  /// its callers.
  ///
  /// The task is already persisted by the time this runs, so scheduling an
  /// OS alert is a side effect, not part of the save. Awaiting it put a
  /// native platform-channel round-trip on the critical path of every write:
  /// the task detail modal only pops once its `updateTask` future resolves,
  /// so a slow — or failing — `zonedSchedule` was felt directly as a stuck
  /// spinner. Real case that motivated this: once Android's 500-concurrent-
  /// alarm cap is hit, every `zonedSchedule` throws a deeply-nested
  /// PlatformException that takes 3-4 seconds to surface, making every save
  /// feel broken even though the write itself took 18ms. See
  /// docs/ERROR_LOG.md.
  ///
  /// Errors are still reported (the callee catches and [debugPrint]s them);
  /// dropping the future only means nobody waits for it, not that failure
  /// goes unseen.
  void _syncNotificationInBackground(Task task) {
    unawaited(_syncNotificationSafely(task));
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

  /// Dev-only: deletes every task, unconditionally. Gated at every call
  /// site by `kDebugMode` (see `settings_screen.dart`'s Developer section)
  /// — this is a destructive bulk operation with no place in a real build.
  Future<void> clearAllTasks() async {
    final repository = ref.read(taskRepositoryProvider);
    for (final task in repository.getTasks()) {
      await repository.deleteTask(task.id);
      await _cancelNotificationSafely(task.id);
    }
    _refresh();
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
