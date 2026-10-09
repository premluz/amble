import 'package:flutter/material.dart';

import '../../shared/models/task.dart';
import '../timeline/pending_task_draft_provider.dart';
import 'task_sheet_form.dart';

/// The task editor's starting form for editing [task], duplicating
/// [duplicateFrom], or creating — with the defaults every entry point
/// shares: an explicitly supplied start wins, a scheduled seed keeps its
/// own, and only a new or unscheduled item starts at [now]; durations
/// default to Timeline quick add's 15 minutes.
TaskSheetForm taskEditorForm({
  required DateTime now,
  Task? task,
  Task? duplicateFrom,
  String? templateId,
  DateTime? initialScheduledAt,
  TimeOfDay? initialTimeOfDay,
}) {
  final seed = task ?? duplicateFrom;
  return TaskSheetForm(
    task: task,
    duplicateFrom: duplicateFrom,
    templateId: templateId,
    date: initialScheduledAt,
    time:
        initialTimeOfDay ??
        (seed?.scheduledAt == null
            ? TimeOfDay.fromDateTime(initialScheduledAt ?? now)
            : null),
    durationMinutes: seed?.durationMinutes ?? quickAddDefaultMinutes,
  );
}
