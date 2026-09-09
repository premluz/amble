import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/recurrence_rule.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../repositories/hive_task_repository.dart';
import '../repositories/task_repository.dart';
import '../services/cascade_reschedule.dart';
import '../services/recurrence_generator.dart';
import 'notification_providers.dart';

part 'task_providers.g.dart';

const taskBoxName = 'tasks';

const _uuid = Uuid();

/// Finds the template task (the one row carrying [Task.recurrenceRule])
/// for whichever series [instance] belongs to, searching [allTasks]. A
/// plain top-level function (not a provider method) so both
/// [TaskList._findSeriesTemplate] and Task Detail's edit-schedule UI can
/// resolve "which row actually owns this series' rule" against a list
/// they already have, without a second repository read.
///
/// Throws (via `firstWhere`'s default) if [instance] isn't recurring or
/// its series has no template — callers only reach this after confirming
/// `instance.isRecurring`, so that's a real invariant violation, not a
/// normal control-flow case to swallow.
Task findSeriesTemplate(Task instance, List<Task> allTasks) {
  final seriesId = instance.recurrenceId;
  return allTasks.firstWhere(
    (task) => task.recurrenceId == seriesId && task.isRecurrenceTemplate,
  );
}

/// The ids of every task in [allTasks] that is "bad state": recurring
/// (`recurrenceId != null`) but belonging to a series with NO template row
/// (no task sharing that `recurrenceId` has `isRecurrenceTemplate == true`)
/// — exactly the shape `findSeriesTemplate`'s `firstWhere` throws `Bad
/// state: No element` on. `deleteTask` now prevents this going forward (see
/// its own doc comment — deleting a template promotes a successor first),
/// but pre-existing data from before that fix (or any other path that
/// could orphan a series) can still have rows in this state, permanently
/// unopenable until removed. Pure and dev-tool-only — the real app has no
/// "repair" affordance for this by design; the fix is not creating the
/// orphan in the first place, not silently patching one back together.
List<String> findOrphanedRecurringTaskIds(List<Task> allTasks) {
  final templatedSeriesIds = <String>{
    for (final task in allTasks)
      if (task.isRecurrenceTemplate && task.recurrenceId != null)
        task.recurrenceId!,
  };
  return [
    for (final task in allTasks)
      if (task.recurrenceId != null &&
          !templatedSeriesIds.contains(task.recurrenceId))
        task.id,
  ];
}

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

  /// Creates a task. Passing [recurrenceRule] makes it the template of a
  /// new recurring series: the template is saved, then the rest of the
  /// rolling window is materialized immediately so the series is visible
  /// on the Timeline right away rather than only after the next launch.
  /// Returns the saved task, so a caller can refer to it afterwards
  /// without a second lookup — the Timeline uses this to know which block
  /// to animate in (see `recently_saved_task_provider.dart`). Callers with
  /// no such need simply ignore the value.
  Future<Task> createTask({
    required String title,
    String? notes,
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
    final task = Task.create(
      title: title,
      notes: notes,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      categoryId: categoryId,
      // A series is identified by its template's own id — no second
      // identifier to keep in sync, and the template is trivially findable.
      recurrenceId: recurrenceRule == null ? null : _uuid.v4(),
      recurrenceRule: recurrenceRule,
      notificationsEnabled: notificationsEnabled,
      isImportant: isImportant,
      templateId: templateId,
    )..behaviorId = behaviorId;
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);

    if (recurrenceRule != null) {
      await _materializeSeries(task);
    }
    _refresh();
    return task;
  }

  /// Generates and persists any missing instances for [template]'s series.
  /// Writes go through [TaskRepository] like every other mutation — the
  /// generator itself only computes, it never persists.
  Future<void> _materializeSeries(Task template) async {
    final repository = ref.read(taskRepositoryProvider);
    final seriesId = template.recurrenceId;
    if (seriesId == null) return;

    final existing = repository
        .getTasks()
        .where((task) => task.recurrenceId == seriesId)
        .toList();

    final generated = generateRecurrenceInstances(
      template: template,
      existingInstances: existing,
      now: DateTime.now(),
    );

    for (final instance in generated) {
      await repository.saveTask(instance);
      // Deliberately NOT synced per instance. Materialization writes up to
      // 8 weeks of rows at once, and scheduling an OS alarm for each one is
      // what drove this app past Android's 500-alarm cap (see
      // docs/ERROR_LOG.md). Instances inside the notification horizon get
      // their alarm from `refreshScheduled` at launch instead — which is
      // also where an instance that later moves *into* the horizon picks
      // one up.
    }
  }

  /// Tops up every recurring series' rolling window. Called once at app
  /// launch (see main.dart) — deliberately not on every Timeline build, so
  /// day-swiping stays a pure read. Idempotent: instances already covering
  /// an occurrence are skipped, so repeat calls create no duplicates.
  Future<void> materializeDueRecurrences() async {
    final templates = ref
        .read(taskRepositoryProvider)
        .getTasks()
        .where((task) => task.isRecurrenceTemplate)
        .toList();

    for (final template in templates) {
      await _materializeSeries(template);
    }
    if (templates.isNotEmpty) _refresh();
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
    _syncNotificationInBackground(task);
    _refresh();
  }

  Future<void> updateTask(Task task) async {
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);
    _refresh();
  }

  /// Saves [task]'s other field changes AND turns it into a new recurring
  /// series' template in one call — the edit-flow equivalent of
  /// [createTask]'s own `recurrenceRule` parameter, for a task that was
  /// plain (never recurring) when editing began. Requested directly: the
  /// "Repeats" panel is now also reachable from Task Detail's edit-schedule
  /// step, not just the create form.
  ///
  /// Deliberately a SEPARATE method from [updateTask], not an added
  /// optional parameter there — every other [updateTask] caller (a plain
  /// reschedule/retitle/etc.) must never accidentally materialize a
  /// series, and a method that only sometimes does something this
  /// consequential based on whether an argument happened to be null would
  /// be an easy future bug to introduce by omission.
  ///
  /// [task] must not already be recurring (`task.isRecurring == false`) —
  /// changing/cancelling an EXISTING series' rule is
  /// [updateTaskWithChangedRecurrence]/[disableTaskRecurrence] instead
  /// (a separate follow-up, since it needs a template lookup and a
  /// future-instances policy this method never had to consider). This is
  /// an assertion, not a runtime branch, so calling the wrong one fails
  /// loudly in debug rather than silently doing the wrong thing.
  Future<void> updateTaskWithNewRecurrence(
    Task task,
    RecurrenceRule recurrenceRule,
  ) async {
    assert(
      !task.isRecurring,
      'updateTaskWithNewRecurrence is for turning Repeats on for a '
      'previously-plain task only — task is already part of a series.',
    );
    task.recurrenceId = _uuid.v4();
    task.recurrenceRule = recurrenceRule;
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);
    await _materializeSeries(task);
    _refresh();
  }

  /// See the top-level [findSeriesTemplate] — this just supplies the
  /// current task list from the repository.
  Task _findSeriesTemplate(Task instance) {
    return findSeriesTemplate(
      instance,
      ref.read(taskRepositoryProvider).getTasks(),
    );
  }

  /// Deletes every future instance of [template]'s series that the user
  /// hasn't touched — confirmed via AskUserQuestion as the safe default
  /// for both a rule change and a disable: "untouched" is still `pending`,
  /// was never individually rescheduled (`originalScheduledAt` is null,
  /// so it's still sitting at the slot the series itself generated it
  /// for), and is scheduled today or later. Anything the user completed,
  /// skipped, or moved is a real action on that specific occurrence and is
  /// never deleted just because the series rule changed underneath it.
  /// The template itself is never a candidate (it's the row being edited,
  /// not one of its own generated instances).
  ///
  /// [alsoSpare] is the instance the CALLER is editing right now, if it's
  /// not the template — real bug, reported directly: a future instance's
  /// own field edit (category, duration, ...) is saved just before this
  /// runs (see [updateTaskWithChangedRecurrence]), but that instance is
  /// itself "untouched" by this method's own definition (still `pending`,
  /// `originalScheduledAt` still null — editing a plain field sets
  /// neither), so it was deleted and immediately replaced by a fresh copy
  /// regenerated from the template's OLD field values, silently discarding
  /// the very edit that was just saved.
  Future<void> _deleteUntouchedFutureInstances(
    Task template, {
    Task? alsoSpare,
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    final seriesId = template.recurrenceId;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final toDelete = repository
        .getTasks()
        .where(
          (task) =>
              task.recurrenceId == seriesId &&
              task.id != template.id &&
              task.id != alsoSpare?.id &&
              task.status == TaskStatus.pending &&
              task.originalScheduledAt == null &&
              task.scheduledAt != null &&
              !task.scheduledAt!.isBefore(todayStart),
        )
        .toList();

    for (final task in toDelete) {
      await repository.deleteTask(task.id);
    }
  }

  /// The "all future occurrences" counterpart to
  /// [_deleteUntouchedFutureInstances] — prunes every PENDING instance of
  /// [template]'s series dated [from] or later, **including ones the user
  /// previously moved individually**, so the series can be re-materialized
  /// wholesale at its new time/duration.
  ///
  /// Confirmed directly (2026-09-07), reversing CONSTITUTION.md's earlier
  /// "an individually-moved occurrence is never realigned by a series
  /// edit" rule: "each day ocurrence could be changed indivudally unless
  /// any change is with 'change all future' then they'd align with that."
  /// So an individual move is no longer permanent protection — an explicit
  /// "all future" edit is the stronger, later instruction and wins.
  ///
  /// `completed`/`skipped` instances are still spared, deliberately and
  /// unlike moved ones (confirmed directly): those are a record of what
  /// actually happened, not part of the plan going forward, and rewriting
  /// their time would be rewriting history.
  ///
  /// [from] is the DATE of the occurrence the user actually edited, not
  /// today — "this and all future occurrences" realigns from the edited
  /// day forward and leaves the days between now and it alone (confirmed
  /// directly, matching how the phrase reads in other calendar apps).
  Future<void> _deleteFutureInstancesForRealign(
    Task template, {
    required DateTime from,
    Task? alsoSpare,
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    final seriesId = template.recurrenceId;
    final fromDay = DateTime(from.year, from.month, from.day);

    final toDelete = repository
        .getTasks()
        .where(
          (task) =>
              task.recurrenceId == seriesId &&
              task.id != template.id &&
              task.id != alsoSpare?.id &&
              // Pending only: completed/skipped occurrences are history.
              task.status != TaskStatus.completed &&
              task.status != TaskStatus.skipped &&
              task.scheduledAt != null &&
              !task.scheduledAt!.isBefore(fromDay),
        )
        .toList();

    for (final task in toDelete) {
      await repository.deleteTask(task.id);
      await _cancelNotificationSafely(task.id);
    }
  }

  /// Changes an EXISTING series' rule (e.g. different days) from any of
  /// its instances — requested directly as the follow-up to
  /// [updateTaskWithNewRecurrence]. Resolves to the series' template
  /// (see [_findSeriesTemplate]) regardless of which instance [task] is,
  /// saves [task]'s own other field changes first, prunes untouched
  /// future instances under the OLD rule (see
  /// [_deleteUntouchedFutureInstances]), then re-materializes under the
  /// new one so the Timeline reflects the change immediately rather than
  /// only after the next rolling-window top-up.
  Future<void> updateTaskWithChangedRecurrence(
    Task task,
    RecurrenceRule recurrenceRule,
  ) async {
    assert(
      task.isRecurring,
      'updateTaskWithChangedRecurrence is for a task already part of a '
      'series — use updateTaskWithNewRecurrence to start one.',
    );

    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);

    final template = _findSeriesTemplate(task);

    // Did the edited instance move to a different time-of-day, or change
    // duration, relative to what the series itself generates? That's a
    // RE-ANCHOR, not just a rule change.
    //
    // Real bug, reported directly ("see duplicates, sometimes even 2") and
    // confirmed from an exported backup: this method used to update only
    // `template.recurrenceRule` and never `template.scheduledAt`, so an
    // "all future occurrences" TIME edit left the template anchored at its
    // old time. `_materializeSeries` then regenerated the whole window
    // back at that old time while the edited instance stayed stranded at
    // the new one — and because the generator matched exact `DateTime`s,
    // none of the old rows looked occupied, so a complete parallel series
    // was created. Three stacked generations of one daily series (56 rows
    // each) were found in real data, 232 stranded rows total.
    // Detected by comparing [task] against the series' OTHER untouched
    // instances, not against the template's own stored fields: the
    // repository hands back the same live object the caller already
    // mutated (Hive `get` is not a copy), and [task] is very often the
    // template itself, so any before/after comparison against it would
    // trivially read "unchanged" and the realign would never fire.
    // Sibling instances are the reliable witness of what the series
    // currently generates.
    final edited = task.scheduledAt;
    final siblings = ref
        .read(taskRepositoryProvider)
        .getTasks()
        .where(
          (other) =>
              other.recurrenceId == template.recurrenceId &&
              other.id != task.id &&
              other.status == TaskStatus.pending &&
              other.originalScheduledAt == null &&
              other.scheduledAt != null,
        )
        .toList();
    final witness = siblings.isEmpty ? null : siblings.first;
    final timeChanged =
        witness != null &&
        edited != null &&
        (witness.scheduledAt!.hour != edited.hour ||
            witness.scheduledAt!.minute != edited.minute);
    final durationChanged =
        witness != null &&
        task.durationMinutes != null &&
        witness.durationMinutes != task.durationMinutes;
    final isRealign = timeChanged || durationChanged;

    if (isRealign && edited != null) {
      // Everything from the EDITED occurrence's day forward is rebuilt at
      // the new time/duration — including instances the user had moved
      // individually, per the confirmed "'change all future' wins" rule
      // (see [_deleteFutureInstancesForRealign]).
      await _deleteFutureInstancesForRealign(
        template,
        from: edited,
        alsoSpare: task,
      );

      // Re-anchor the template's own time-of-day and duration, keeping its
      // own DATE — the template is the series' start, and "all future"
      // changes when occurrences happen, never which day the series began.
      final templateDate = template.scheduledAt;
      if (templateDate != null && timeChanged) {
        template.scheduledAt = DateTime(
          templateDate.year,
          templateDate.month,
          templateDate.day,
          edited.hour,
          edited.minute,
        );
      }
      if (durationChanged) template.durationMinutes = task.durationMinutes;

      // The edited instance now sits exactly where the series generates
      // it, so any `originalScheduledAt`/`rescheduled` marker left over
      // from an earlier individual move is stale — clearing it keeps it
      // eligible for a future prune (and stops it rendering as "moved"
      // when it no longer is). Only cleared when it genuinely realigns:
      // an edit that moved it to a time the series does NOT generate is
      // still a real individual move.
      if (task.id != template.id && task.originalScheduledAt != null) {
        task.originalScheduledAt = null;
        if (task.status == TaskStatus.rescheduled) {
          task.status = TaskStatus.pending;
        }
        await ref.read(taskRepositoryProvider).saveTask(task);
      }
    } else {
      // Rule-only change (e.g. different days): keep the long-standing
      // conservative prune, which spares anything the user completed,
      // skipped, or moved.
      await _deleteUntouchedFutureInstances(template, alsoSpare: task);
    }

    template.recurrenceRule = recurrenceRule;
    await ref.read(taskRepositoryProvider).saveTask(template);
    _syncNotificationInBackground(template);
    await _materializeSeries(template);
    _refresh();
  }

  /// Saves [task]'s own field changes — including a moved `scheduledAt`
  /// or a changed `durationMinutes` — without touching any other instance
  /// in its series or the series' own template/rule. The "just this
  /// occurrence" half of the recurring-edit scope choice requested
  /// directly (the "this and all future occurrences" half is
  /// [updateTaskWithChangedRecurrence], which already ran this exact
  /// cascade for every recurring edit before this method existed).
  ///
  /// Sets `originalScheduledAt` the same way a drag-reschedule
  /// ([rescheduleTask]) already does, if not already set — this is the
  /// single signal [_deleteUntouchedFutureInstances] uses to tell an
  /// intentionally-touched instance apart from one still sitting where
  /// the series generated it; without it, the next rule change or rolling
  /// materialization pass would treat this instance as untouched and
  /// silently delete/regenerate over the very edit this method just made.
  Future<void> updateTaskThisInstanceOnly(Task task) async {
    assert(
      task.isRecurring,
      'updateTaskThisInstanceOnly is for a single instance of an existing '
      'series — a plain task has no series to isolate the edit from, so '
      'use updateTask instead.',
    );
    task.originalScheduledAt ??= task.scheduledAt;
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);
    _refresh();
  }

  /// Turns off an EXISTING series from any of its instances — requested
  /// directly, "which would remove future instances." Saves [task]'s own
  /// other field changes, prunes untouched future instances (see
  /// [_deleteUntouchedFutureInstances]), then clears the TEMPLATE's own
  /// `recurrenceId`/`recurrenceRule` — confirmed via AskUserQuestion: the
  /// template becomes an ordinary task (same as one that never repeated),
  /// not a "was recurring" husk that keeps `recurrenceId` for history.
  /// Past/touched instances keep their own `recurrenceId` untouched, so
  /// they still show as having been part of a series — only the template
  /// detaches.
  Future<void> disableTaskRecurrence(Task task) async {
    assert(
      task.isRecurring,
      'disableTaskRecurrence is for a task already part of a series.',
    );
    await ref.read(taskRepositoryProvider).saveTask(task);
    _syncNotificationInBackground(task);

    final template = _findSeriesTemplate(task);
    await _deleteUntouchedFutureInstances(template);
    template.recurrenceId = null;
    template.recurrenceRule = null;
    await ref.read(taskRepositoryProvider).saveTask(template);
    _refresh();
  }

  /// Creates a standalone copy of [source] — same title/category/notes/
  /// schedule as the original, but a fresh UUID (via [Task.create]) and no
  /// link to the original's recurrence series: a duplicate is a new,
  /// independent task, not another instance of that series. Status/
  /// completion are deliberately not copied either — a duplicate starts
  /// fresh as `pending`, matching [Task.create]'s own defaults. Returns the
  /// saved task so the caller can open it for review (e.g. in "Edit
  /// details") without a second lookup.
  Future<Task> duplicateTask(Task source) async {
    final duplicate = Task.create(
      title: source.title,
      notes: source.notes,
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

  /// Deletes one task by id. When that task is a series TEMPLATE (the one
  /// row carrying the rule), the rule is handed to the earliest surviving
  /// instance first, so the series keeps exactly one template instead of
  /// being orphaned.
  ///
  /// Real bug, reported directly ("I removed the original as a single
  /// instance and have a read error, but state no element"): removing a
  /// template via the "Remove this occurrence" branch left every other
  /// instance still carrying the series' `recurrenceId` — so each still
  /// reported `isRecurring == true` — with NO row carrying the rule at
  /// all. `findSeriesTemplate`'s `firstWhere` then threw `Bad state: No
  /// element` on the next open/edit of ANY of them, including from the
  /// detail sheet's own `initState`, which made those tasks impossible to
  /// open at all. Reproduced directly: deleting the template of a daily
  /// series left 56 orphaned instances and threw on the first edit.
  ///
  /// Promotion (rather than detaching every instance, or refusing the
  /// delete) keeps the user's actual intent — "remove just this
  /// occurrence" — while preserving the series' own invariant that
  /// exactly one row carries the rule.
  Future<void> deleteTask(String id) async {
    final repository = ref.read(taskRepositoryProvider);
    final deleted = repository.getTaskById(id);
    if (deleted != null && deleted.isRecurrenceTemplate) {
      await _promoteSuccessorTemplate(deleted);
    }
    await repository.deleteTask(id);
    await _cancelNotificationSafely(id);
    _refresh();
  }

  /// Hands [outgoing]'s recurrence rule to the earliest other instance of
  /// its series, so deleting [outgoing] doesn't leave the series without a
  /// template. No-op when it's the series' last remaining row — nothing is
  /// left to carry the rule, and the series ceases to exist along with it.
  ///
  /// The successor keeps its own `scheduledAt`, so it becomes the series'
  /// new anchor. That genuinely re-anchors future generation (a weekly
  /// rule with no explicit `daysOfWeek` follows the anchor's own weekday),
  /// which is the correct reading of "the first occurrence was removed" —
  /// and for a rule with explicit days, generation is unchanged.
  Future<void> _promoteSuccessorTemplate(Task outgoing) async {
    final repository = ref.read(taskRepositoryProvider);
    final seriesId = outgoing.recurrenceId;
    if (seriesId == null) return;

    final candidates =
        repository
            .getTasks()
            .where(
              (task) =>
                  task.recurrenceId == seriesId &&
                  task.id != outgoing.id &&
                  task.scheduledAt != null,
            )
            .toList()
          ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    if (candidates.isEmpty) return;

    final successor = candidates.first;
    successor.recurrenceRule = outgoing.recurrenceRule;
    await repository.saveTask(successor);
  }

  /// Removes [instance] and every OTHER instance of its series scheduled
  /// today or later, then clears the template's recurrence fields so no
  /// further instances generate. Requested directly: removing a recurring
  /// task now asks "this one or all", and this is the "all" branch.
  ///
  /// Past instances are deliberately kept — same reasoning as
  /// [disableTaskRecurrence]: they're a record of work that actually
  /// happened, and "remove this repeating task" reads as "stop it from
  /// here on," not "erase its history." Confirmed via AskUserQuestion.
  ///
  /// Unlike [_deleteUntouchedFutureInstances], this does NOT spare future
  /// instances the user has completed/skipped/rescheduled. That protection
  /// exists so a *rule change* can't silently erase deliberate work; an
  /// explicit delete is the opposite — leaving a rescheduled future
  /// instance behind would look like the delete had failed. Also confirmed
  /// via AskUserQuestion rather than assumed.
  ///
  /// The template row itself is deleted too when it falls today or later.
  /// When it's in the past it survives (as history) but is stripped of its
  /// recurrence fields, so it stops being a template and generates
  /// nothing further.
  Future<void> deleteTaskSeries(Task instance) async {
    assert(
      instance.isRecurring,
      'deleteTaskSeries is for a task that belongs to a series — use '
      'deleteTask for a plain one.',
    );
    final repository = ref.read(taskRepositoryProvider);
    final seriesId = instance.recurrenceId;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final seriesTasks = repository
        .getTasks()
        .where((task) => task.recurrenceId == seriesId)
        .toList();

    // Resolved before any deletion, since the template may itself be one
    // of the rows about to be removed.
    final template = seriesTasks.firstWhere(
      (task) => task.isRecurrenceTemplate,
      orElse: () => instance,
    );

    for (final task in seriesTasks) {
      final isFuture =
          task.scheduledAt != null && !task.scheduledAt!.isBefore(todayStart);
      // The tapped instance goes regardless of when it falls — the user
      // asked for it directly.
      if (isFuture || task.id == instance.id) {
        await repository.deleteTask(task.id);
        await _cancelNotificationSafely(task.id);
      }
    }

    // A past template survives as history, so detach it explicitly or it
    // would keep generating new instances on the next rolling-window
    // top-up.
    final templateSurvived =
        template.scheduledAt != null &&
        template.scheduledAt!.isBefore(todayStart) &&
        template.id != instance.id;
    if (templateSurvived) {
      template.recurrenceId = null;
      template.recurrenceRule = null;
      await repository.saveTask(template);
    }

    _refresh();
  }

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

  /// Dev-only: deletes every "bad state" orphaned-recurring task (see
  /// [findOrphanedRecurringTaskIds]) — the rows that throw `Bad state: No
  /// element` on open because their series has no template. Returns the
  /// count removed, so the Settings button can report what it did.
  Future<int> clearBadStateTasks() async {
    final repository = ref.read(taskRepositoryProvider);
    final orphanedIds = findOrphanedRecurringTaskIds(repository.getTasks());
    for (final id in orphanedIds) {
      await repository.deleteTask(id);
      await _cancelNotificationSafely(id);
    }
    _refresh();
    return orphanedIds.length;
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
