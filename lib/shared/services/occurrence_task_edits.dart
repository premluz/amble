import '../models/field_override.dart';
import '../models/local_date.dart';
import '../models/occurrence_key.dart';
import '../models/occurrence_plan_overrides.dart';
import '../models/occurrence_record.dart';
import '../models/recurrence_command.dart';
import '../models/record_aspect.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import 'occurrence_task_projection.dart';

/// Builds one command once its id and the record version it expects are
/// known — the store fills those in just before each command runs, so a
/// multi-command edit always states the version it actually saw.
typedef OccurrenceCommandBuilder = OccurrenceCommand Function(
  String commandId,
  int? expectedVersion,
);

/// The commands that turn [current] (an occurrence shown as a task) into
/// [edited]: one "this occurrence" plan override for every changed plan
/// field, plus separate outcome, note and value commands. Each field a user
/// did not change stays inherited (D1).
List<OccurrenceCommandBuilder> commandsForTaskEdit({
  required Task current,
  required Task edited,
  required LocalDate today,
}) {
  final key = occurrenceKeyOfTask(current);
  final (plan, fields) = _planChanges(current, edited);
  return [
    if (fields.isNotEmpty)
      (id, version) => OverridePlan(
        id,
        key: key,
        expectedVersion: version,
        plan: plan,
        fields: fields,
      ),
    if (_outcomeOf(edited.status) != _outcomeOf(current.status))
      _outcomeCommand(key, edited.status, today),
    if (edited.notes != current.notes)
      (id, version) =>
          SetNote(id, key: key, expectedVersion: version, note: edited.notes),
    if (edited.actualAmount != current.actualAmount)
      (id, version) => SetMeasuredValue(
        id,
        key: key,
        expectedVersion: version,
        value: edited.actualAmount,
      ),
  ];
}

/// A move marks a task `rescheduled`; for an occurrence that is a plan
/// change, not an outcome (contract §5).
OccurrenceOutcome _outcomeOf(TaskStatus status) => switch (status) {
  TaskStatus.completed => OccurrenceOutcome.done,
  TaskStatus.skipped => OccurrenceOutcome.skipped,
  TaskStatus.pending || TaskStatus.rescheduled => OccurrenceOutcome.none,
};

OccurrenceCommandBuilder _outcomeCommand(
  OccurrenceKey key,
  TaskStatus status,
  LocalDate today,
) {
  final outcome = _outcomeOf(status);
  return (id, version) => SetOutcome(
    id,
    key: key,
    expectedVersion: version,
    outcome: outcome,
    completionDate: outcome == OccurrenceOutcome.done ? today : null,
  );
}

(OccurrencePlanOverrides, Set<RecordAspect>) _planChanges(
  Task current,
  Task edited,
) {
  final fields = <RecordAspect>{};
  FieldOverride<T> field<T>(RecordAspect aspect, bool differs, T after) {
    if (!differs) return Inherit<T>();
    fields.add(aspect);
    return SetTo<T>(after);
  }

  ClearableOverride<String> clearable(
    RecordAspect aspect,
    String? before,
    String? after,
  ) {
    final normalized = (after == null || after.trim().isEmpty) ? null : after;
    if (before == normalized) return const Inherit<String>();
    fields.add(aspect);
    return normalized == null ? const Clear<String>() : SetTo(normalized);
  }

  final start = edited.scheduledAt;
  final duration = edited.durationMinutes;
  final plan = OccurrencePlanOverrides(
    start: start == null
        ? const Inherit()
        : field(
            RecordAspect.start,
            start != current.scheduledAt,
            _startOf(start),
          ),
    durationMinutes: duration == null
        ? const Inherit()
        : field(
            RecordAspect.durationMinutes,
            duration != current.durationMinutes,
            duration,
          ),
    title: field(
      RecordAspect.title,
      edited.title != current.title,
      edited.title,
    ),
    description: clearable(
      RecordAspect.description,
      current.description,
      edited.description,
    ),
    categoryId: clearable(
      RecordAspect.categoryId,
      current.categoryId,
      edited.categoryId,
    ),
    zoneId: clearable(RecordAspect.zoneId, current.zoneId, edited.zoneId),
    notificationsEnabled: field(
      RecordAspect.notificationsEnabled,
      edited.notificationsEnabled != current.notificationsEnabled,
      edited.notificationsEnabled,
    ),
    isImportant: field(
      RecordAspect.isImportant,
      edited.isImportant != current.isImportant,
      edited.isImportant,
    ),
  );
  return (plan, fields);
}

OccurrenceStart _startOf(DateTime at) {
  final slot = localSlotOf(at);
  return OccurrenceStart(date: slot.date, minutes: slot.minutes);
}
