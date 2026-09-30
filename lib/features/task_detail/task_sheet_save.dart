import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_trial_gate.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/trial_providers.dart';
import '../timeline/pending_task_draft_provider.dart';
import '../timeline/recently_saved_task_provider.dart';
import 'task_sheet_form.dart';

/// Writes [form]: creates a task (retrying once after the paywall if the
/// trial has ended), or writes the task being edited back — taking the
/// series into account. Records the change for the Timeline's save
/// animation, and clears the Timeline draft ([draftId]) it came from.
/// Returns whether anything was written. The form must be [canSave].
Future<bool> saveTaskSheet(
  BuildContext context,
  WidgetRef ref,
  TaskSheetForm form, {
  String? draftId,
}) async {
  final scheduledAt = form.scheduledAt;
  final durationMinutes = form.durationMinutes;
  final title = form.title.text.trim();
  if (title.isEmpty || scheduledAt == null || durationMinutes == null) {
    throw StateError('saveTaskSheet called on a form that cannot save');
  }
  final description = form.description.text.trim();
  final notifier = ref.read(taskListProvider.notifier);
  final saved = ref.read(recentlySavedTaskProvider.notifier);
  final existing = form.task;

  if (existing == null) {
    Future<Task> attempt() => notifier.createTask(
      title: title,
      description: description.isEmpty ? null : description,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      categoryId: form.categoryId,
      recurrenceRule: form.repeats ? form.recurrenceRule : null,
      behaviorId: form.behaviorId,
      notificationsEnabled: form.notificationsEnabled,
      isImportant: form.isImportant,
      templateId: form.templateId,
    );
    Task created;
    try {
      created = await attempt();
    } on TrialExpiredException {
      if (!context.mounted) return false;
      final unlocked = await presentPaywallForTrialExpired(context, ref);
      if (!unlocked || !context.mounted) return false;
      try {
        created = await attempt();
      } on TrialExpiredException {
        return false;
      }
    }
    saved.record(created.id, SavedTaskChange.created);
  } else {
    await _update(notifier, form, existing, title, description, scheduledAt);
    final durationChanged =
        form.initialDurationMinutes != existing.durationMinutes;
    saved.record(
      existing.id,
      // A Things item getting its first time reads as new on the Timeline.
      durationChanged
          ? SavedTaskChange.durationChanged
          : SavedTaskChange.created,
      previousDurationMinutes: durationChanged
          ? form.initialDurationMinutes
          : null,
      checkForOverlapAfterSave:
          form.initialScheduledAt != scheduledAt || durationChanged,
    );
  }
  if (draftId != null) ref.read(pendingTaskDraftProvider.notifier).clear();
  return true;
}

Future<void> _update(
  TaskList notifier,
  TaskSheetForm form,
  Task existing,
  String title,
  String description,
  DateTime scheduledAt,
) async {
  existing.title = title;
  existing.description = description.isEmpty ? null : description;
  // A recurring occurrence moved by editing must remember its slot, or the
  // next materialization regenerates a duplicate at the old hour — as
  // `TaskList.rescheduleTask` does for a drag.
  if (existing.isRecurring && existing.scheduledAt != scheduledAt) {
    existing.originalScheduledAt ??= existing.scheduledAt;
  }
  existing.scheduledAt = scheduledAt;
  existing.durationMinutes = form.durationMinutes;
  existing.categoryId = form.categoryId;
  existing.notificationsEnabled = form.notificationsEnabled;
  existing.isImportant = form.isImportant;
  final behaviorChanged = form.behaviorId != form.initialBehaviorId;
  if (form.behaviorId == null) existing.actualAmount = null;
  existing.behaviorId = form.behaviorId;

  final was = form.wasRecurring ?? false;
  if (!was && form.repeats) {
    await notifier.updateTaskWithNewRecurrence(existing, form.recurrenceRule);
  } else if (was && !form.repeats) {
    await notifier.disableTaskRecurrence(existing);
  } else if (was &&
      form.showFutureInstancesChoice &&
      !form.affectFutureInstances) {
    await notifier.updateTaskThisInstanceOnly(existing);
  } else if (was) {
    await notifier.updateTaskWithChangedRecurrence(
      existing,
      form.recurrenceRule,
    );
  } else {
    await notifier.updateTask(existing);
  }
  // A tracked-behaviour link belongs to the whole series.
  if (behaviorChanged && existing.isRecurring) {
    await notifier.propagateBehaviorLinkToSeries(existing);
  }
}
