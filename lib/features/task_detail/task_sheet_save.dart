import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_trial_gate.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/task_providers.dart';
import '../../shared/providers/trial_providers.dart';
import '../../shared/services/occurrence_task_projection.dart';
import '../timeline/pending_task_draft_provider.dart';
import '../timeline/recently_saved_task_provider.dart';
import 'task_sheet_form.dart';
import 'task_sheet_series_save.dart';

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
    // A repeating task becomes a series (see `TaskList.createTask`).
    Future<String> attempt() async => (await notifier.createTask(
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
    )).id;
    String createdId;
    try {
      createdId = await attempt();
    } on TrialExpiredException {
      if (!context.mounted) return false;
      final unlocked = await presentPaywallForTrialExpired(context, ref);
      if (!unlocked || !context.mounted) return false;
      try {
        createdId = await attempt();
      } on TrialExpiredException {
        return false;
      }
    }
    saved.record(createdId, SavedTaskChange.created);
  } else if (isOccurrenceTaskId(existing.id)) {
    await saveOccurrenceFromSheet(
      ref,
      form,
      existing,
      title: title,
      description: description,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
    );
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
  // Turning repeat on for a plain task makes it a series from this date; the
  // plain task is replaced by the series' first occurrence.
  if (form.repeats) {
    await notifier.createTask(
      title: title,
      description: description.isEmpty ? null : description,
      scheduledAt: scheduledAt,
      durationMinutes: form.durationMinutes!,
      categoryId: form.categoryId,
      recurrenceRule: form.recurrenceRule,
      behaviorId: form.behaviorId,
      notificationsEnabled: form.notificationsEnabled,
      isImportant: form.isImportant,
      templateId: existing.templateId,
    );
    await notifier.deleteTask(existing.id);
    return;
  }
  existing.title = title;
  existing.description = description.isEmpty ? null : description;
  existing.scheduledAt = scheduledAt;
  existing.durationMinutes = form.durationMinutes;
  existing.categoryId = form.categoryId;
  existing.notificationsEnabled = form.notificationsEnabled;
  existing.isImportant = form.isImportant;
  if (form.behaviorId == null) existing.actualAmount = null;
  existing.behaviorId = form.behaviorId;
  await notifier.updateTask(existing);
}
