import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/recurrence_command.dart';
import '../../shared/models/series_revision.dart';
import '../../shared/models/task.dart';
import '../../shared/providers/occurrence_store.dart';
import '../../shared/services/occurrence_task_projection.dart';
import 'task_sheet_form.dart';

/// Saves an edited series occurrence:
/// - repeat turned off → the series ends from today;
/// - repeat days, tracked behavior, or "affect future instances" changed →
///   a new revision from this occurrence's date (never the past);
/// - otherwise → "this occurrence" overrides.
Future<void> saveOccurrenceFromSheet(
  WidgetRef ref,
  TaskSheetForm form,
  Task occurrence, {
  required String title,
  required String description,
  required DateTime scheduledAt,
  required int durationMinutes,
}) async {
  final store = ref.read(occurrenceStoreProvider.notifier);
  if (!form.repeats) {
    await store.endSeriesOf(occurrence);
    return;
  }

  // Compared as days, not rules: the form writes "all seven days" as a
  // daily rule, which must not read as a change to a weekly-on-every-day
  // series.
  final rule = occurrence.recurrenceRule;
  if (rule == null) throw StateError('Occurrence ${occurrence.id} has no rule');
  final ruleChanged = !setEquals(
    form.selectedDays,
    daysFromRecurrenceRule(rule),
  );
  final behaviorChanged = form.behaviorId != form.initialBehaviorId;
  if (ruleChanged || behaviorChanged || form.affectFutureInstances) {
    final slot = localSlotOf(scheduledAt);
    return store.reviseFrom(
      occurrence,
      _draftFrom(form, title, description, slot.minutes, durationMinutes),
    );
  }

  occurrence
    ..title = title
    ..description = description.isEmpty ? null : description
    ..scheduledAt = scheduledAt
    ..durationMinutes = durationMinutes
    ..categoryId = form.categoryId
    ..notificationsEnabled = form.notificationsEnabled
    ..isImportant = form.isImportant;
  await store.applyTaskEdit(occurrence);
}

SeriesRevisionDraft _draftFrom(
  TaskSheetForm form,
  String title,
  String description,
  int startMinutes,
  int durationMinutes,
) => SeriesRevisionDraft(
  rule: form.recurrenceRule,
  startMinutes: startMinutes,
  durationMinutes: durationMinutes,
  defaults: SeriesDefaults(
    title: title,
    description: description.isEmpty ? null : description,
    categoryId: form.categoryId,
    behaviorId: form.behaviorId,
    notificationsEnabled: form.notificationsEnabled,
    isImportant: form.isImportant,
  ),
);
