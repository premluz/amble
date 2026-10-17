import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/task_detail/task_recurrence_days.dart';
import '../models/recurrence_command.dart';
import '../models/series_revision.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../services/assistant/assistant_task_edit.dart';
import '../services/assistant/assistant_tool.dart';
import '../services/occurrence_task_projection.dart';
import 'occurrence_store.dart';
import 'task_providers.dart';
import 'trial_providers.dart';

typedef Undo = Future<void> Function();

/// Saves an assistant's edit exactly the way Amble's task sheet does
/// (`task_sheet_save.dart`, `task_sheet_series_save.dart`), and returns an
/// undo for the activity list.
///
/// One-off task: fields are written back; turning repeat on replaces it with
/// a series from its day. Repeating occurrence: turning repeat off ends the
/// series; new repeat days or "this and following" make a new revision from
/// this date; anything else is a "this occurrence" override.
class AssistantTaskEditor {
  AssistantTaskEditor(this._ref);

  final Ref _ref;

  TaskList get _tasks => _ref.read(taskListProvider.notifier);
  OccurrenceStore get _store => _ref.read(occurrenceStoreProvider.notifier);

  Future<Undo?> apply(Task task, AssistantTaskEdit edit) =>
      isOccurrenceTaskId(task.id)
      ? _occurrence(task, edit)
      : _oneOff(task, edit);

  Future<Undo?> _oneOff(Task task, AssistantTaskEdit edit) async {
    final before = Task.fromJson(task.toJson());
    final days = edit.repeatDays;
    if (days != null && days.isNotEmpty) {
      final created = await _createSeries(task, edit, days);
      await _tasks.deleteTask(task.id);
      return () async {
        await _tasks.undoSeriesChange(created.recurrenceId!);
        await _tasks.restoreTasksInBatch([before]);
      };
    }
    _applyFields(task, edit);
    await _tasks.updateTask(task);
    await _setDone(task, edit.done);
    return () => _tasks.restoreTasksInBatch([before]);
  }

  Future<Task> _createSeries(Task task, AssistantTaskEdit edit, Set<int> days) {
    try {
      return _tasks.createTask(
        title: edit.title ?? task.title,
        description: _description(edit, task),
        scheduledAt: edit.start ?? task.scheduledAt!,
        durationMinutes: edit.durationMinutes ?? task.durationMinutes!,
        categoryId: edit.categoryId ?? task.categoryId!,
        recurrenceRule: recurrenceRuleFromDays(days),
        behaviorId: task.behaviorId,
        notificationsEnabled: edit.reminder ?? task.notificationsEnabled,
        isImportant: edit.important ?? task.isImportant,
        templateId: task.templateId,
      );
    } on TrialExpiredException {
      throw const AssistantToolError(
        'The Amble trial has ended, so no new repeating tasks can be made.',
      );
    }
  }

  Future<Undo?> _occurrence(Task task, AssistantTaskEdit edit) async {
    final days = edit.repeatDays;
    if (days != null && days.isEmpty) {
      final commandId = await _store.endSeriesOf(task);
      return () => _tasks.undoSeriesChange(commandId);
    }
    final rule = task.recurrenceRule;
    if (rule == null) throw StateError('Occurrence ${task.id} has no rule');
    final daysChanged =
        days != null && !setEquals(days, daysFromRecurrenceRule(rule));
    if (daysChanged || edit.scope == AssistantEditScope.thisAndFollowing) {
      return _revise(task, edit, daysChanged ? days : null);
    }
    final before = Task.fromJson(task.toJson());
    final wasDone = task.status == TaskStatus.completed;
    _applyFields(task, edit);
    await _tasks.updateTask(task);
    await _setDone(task, edit.done);
    return () async {
      final current = _store.currentTask(occurrenceKeyOfTask(task));
      await _setDone(current, wasDone);
      await _tasks.updateTask(before);
    };
  }

  /// A new revision from this occurrence's date. "Done" still applies to
  /// this occurrence only.
  Future<Undo?> _revise(
    Task task,
    AssistantTaskEdit edit,
    Set<int>? days,
  ) async {
    final start = edit.start ?? task.scheduledAt!;
    final commandId = await _store.reviseFrom(
      task,
      SeriesRevisionDraft(
        rule: days == null
            ? task.recurrenceRule!
            : recurrenceRuleFromDays(days),
        startMinutes: localSlotOf(start).minutes,
        durationMinutes: edit.durationMinutes ?? task.durationMinutes!,
        defaults: SeriesDefaults(
          title: edit.title ?? task.title,
          description: _description(edit, task),
          categoryId: edit.categoryId ?? task.categoryId,
          behaviorId: task.behaviorId,
          notificationsEnabled: edit.reminder ?? task.notificationsEnabled,
          isImportant: edit.important ?? task.isImportant,
        ),
      ),
    );
    final key = occurrenceKeyOfTask(task);
    final wasDone = task.status == TaskStatus.completed;
    await _setDone(_store.currentTask(key), edit.done);
    return () async {
      await _setDone(_store.currentTask(key), wasDone);
      await _tasks.undoSeriesChange(commandId);
    };
  }

  Future<void> _setDone(Task task, bool? done) async {
    if (done == null || done == (task.status == TaskStatus.completed)) return;
    await _tasks.toggleComplete(task);
  }

  static String? _description(AssistantTaskEdit edit, Task task) {
    final notes = edit.notes;
    if (notes == null) return task.description;
    return notes.isEmpty ? null : notes;
  }

  static void _applyFields(Task task, AssistantTaskEdit edit) {
    task
      ..title = edit.title ?? task.title
      ..scheduledAt = edit.start ?? task.scheduledAt
      ..durationMinutes = edit.durationMinutes ?? task.durationMinutes
      ..categoryId = edit.categoryId ?? task.categoryId
      ..isImportant = edit.important ?? task.isImportant
      ..notificationsEnabled = edit.reminder ?? task.notificationsEnabled
      ..description = _description(edit, task);
  }
}
